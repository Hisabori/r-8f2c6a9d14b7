import CoreBluetooth
import CryptoKit
import Foundation

/// One bounded, foreground BLE transaction. QR secret is never sent over the radio.
@MainActor final class BluetoothHealthSync: NSObject, @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    static let service = CBUUID(string: "3ef7d480-a27d-4db0-982c-183db690b101")
    static let authID = CBUUID(string: "3ef7d480-a27d-4db0-982c-183db690b102")
    static let dataID = CBUUID(string: "3ef7d480-a27d-4db0-982c-183db690b103")
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var auth: CBCharacteristic?
    private var stream: CBCharacteristic?
    private var challenge = Data()
    private var bytes = Data()
    private var total: Int?
    private var pair: SyncPair?
    private var continuation: CheckedContinuation<Data, Error>?
    private var timeout: Task<Void, Never>?
    private var fetching = false
    func fetch(pair: SyncPair) async throws -> Data {
        guard continuation == nil else { throw CareError.invalid }
        self.pair = pair; bytes = Data(); total = nil; fetching = false; challenge = Data()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { pending in
                continuation = pending
                central = CBCentralManager(delegate: self, queue: .main)
                timeout = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: 140_000_000_000) } catch { return }
                    self?.finish(.failure(CareError.unreadable))
                }
            }
        } onCancel: { Task { @MainActor [weak self] in self?.cancel() } }
    }
    func cancel() { finish(.failure(CancellationError())) }
    private func finish(_ result: Result<Data, Error>) {
        let pending = continuation; continuation = nil
        timeout?.cancel(); timeout = nil; central?.stopScan()
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        peripheral = nil; auth = nil; stream = nil; pair = nil; bytes = Data(); challenge = Data(); fetching = false
        pending?.resume(with: result)
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard continuation != nil else { return }
        if central.state == .poweredOn { guard let pair else { return }; central.scanForPeripherals(withServices: [CBUUID(string: pair.peer)]) }
        else if central.state != .unknown && central.state != .resetting { finish(.failure(CareError.unreadable)) }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard self.peripheral == nil else { return }
        self.peripheral = peripheral; central.stopScan(); peripheral.delegate = self; central.connect(peripheral)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) { if let pair { peripheral.discoverServices([CBUUID(string: pair.peer)]) } }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) { finish(.failure(CareError.unreadable)) }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) { if continuation != nil { finish(.failure(CareError.unreadable)) } }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == CBUUID(string: pair?.peer ?? Self.service.uuidString) }) else { finish(.failure(CareError.invalid)); return }
        peripheral.discoverCharacteristics([Self.authID, Self.dataID], for: service)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        auth = service.characteristics?.first { $0.uuid == Self.authID }; stream = service.characteristics?.first { $0.uuid == Self.dataID }
        guard error == nil, let auth, stream != nil else { finish(.failure(CareError.invalid)); return }
        peripheral.readValue(for: auth)
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let stream else { finish(.failure(CareError.unreadable)); return }
        fetching = true; peripheral.readValue(for: stream)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard continuation != nil, error == nil, let value = characteristic.value, let pair, let auth else { finish(.failure(CareError.unreadable)); return }
        if characteristic.uuid == Self.authID {
            guard !fetching, value.count == 32 else { finish(.failure(CareError.invalid)); return }
            challenge = value
            let proof = HMAC<SHA256>.authenticationCode(for: value, using: SymmetricKey(data: Data(pair.token.utf8)))
            peripheral.writeValue(Data([1]) + Data(proof.prefix(16)), for: auth, type: .withResponse)
        } else if characteristic.uuid == Self.dataID {
            do {
                let frame = try Self.frame(value, expectedOffset: bytes.count, total: total)
                total = frame.total; bytes.append(frame.chunk)
                if bytes.count == frame.total {
                    let key = SymmetricKey(data: Data(HMAC<SHA256>.authenticationCode(for: challenge + Data("oncare-ble-data-v1".utf8), using: SymmetricKey(data: Data(pair.token.utf8)))))
                    let plain = try AES.GCM.open(AES.GCM.SealedBox(combined: bytes), using: key, authenticating: challenge)
                    finish(.success(plain))
                } else {
                    let offset = UInt32(bytes.count)
                    peripheral.writeValue(Data([2, UInt8((offset >> 24) & 255), UInt8((offset >> 16) & 255), UInt8((offset >> 8) & 255), UInt8(offset & 255)]), for: auth, type: .withResponse)
                }
            } catch { finish(.failure(error)) }
        }
    }
    static func frame(_ data: Data, expectedOffset: Int, total: Int?) throws -> (total: Int, chunk: Data) {
        guard data.count > 8 else { throw CareError.invalid }
        let raw = Array(data)
        func number(_ start: Int) -> Int { raw[start..<start+4].reduce(0) { ($0 << 8) | Int($1) } }
        let offset = number(0), length = number(4)
        guard offset == expectedOffset, length >= 28, length <= 1024*1024+28, total == nil || total == length, expectedOffset + data.count - 8 <= length else { throw CareError.invalid }
        return (length, Data(data.dropFirst(8)))
    }
}
