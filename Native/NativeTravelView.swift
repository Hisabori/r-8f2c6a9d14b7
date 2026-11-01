import SwiftUI
import MapKit
import CoreLocation

enum NativeTravelPlanning {
    static func leaveBy(arrival: Date, travelSeconds: Double, preparationMinutes: Int, marginMinutes: Int) -> Date? {
        guard travelSeconds.isFinite, travelSeconds >= 0, travelSeconds <= 86400,
              (0...120).contains(preparationMinutes), (0...30).contains(marginMinutes) else { return nil }
        return arrival.addingTimeInterval(-travelSeconds - Double(preparationMinutes + marginMinutes) * 60)
    }
}

@MainActor final class NativeTravelStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var query = ""
    @Published private(set) var places: [MKMapItem] = []
    @Published private(set) var searching = false
    @Published private(set) var location: CLLocationCoordinate2D?
    @Published var notice: String?
    @Published private(set) var walkingSeconds: Double?
    private let manager = CLLocationManager()
    private var search: MKLocalSearch?
    private var directions: MKDirections?
    private var generation = UUID()
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyHundredMeters }
    func locate() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: notice = "현재 위치 권한이 없어도 목적지를 찾아 지도 앱에서 경로를 확인할 수 있어요."
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus) { manager.requestLocation() }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last, abs(latest.timestamp.timeIntervalSinceNow) < 120, latest.horizontalAccuracy >= 0 else { return }
        Task { @MainActor in self.location = latest.coordinate; self.walkingSeconds = nil }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.notice = "현재 위치를 확인하지 못했습니다. 잠시 후 다시 시도하세요." }
    }
    func find() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 200 else { return }
        search?.cancel(); directions?.cancel(); walkingSeconds = nil
        let token = UUID(); generation = token; searching = true
        let request = MKLocalSearch.Request(); request.naturalLanguageQuery = text
        if let location { request.region = MKCoordinateRegion(center: location, latitudinalMeters: 10000, longitudinalMeters: 10000) }
        let value = MKLocalSearch(request: request); search = value
        do {
            let response = try await value.start()
            guard generation == token else { return }
            places = Array(response.mapItems.prefix(20))
            if places.isEmpty { notice = "검색 결과가 없습니다. 장소나 지역 이름을 더해보세요." }
        } catch { if generation == token { notice = "목적지를 찾지 못했습니다. 연결 상태를 확인하세요." } }
        if generation == token { searching = false }
    }
    func estimate(_ destination: MKMapItem) async {
        guard let location else { notice = "도보 예상 시간을 보려면 현재 위치를 먼저 확인하세요."; return }
        directions?.cancel(); walkingSeconds = nil
        let token = UUID(); generation = token
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: location))
        request.destination = destination; request.transportType = .walking
        let value = MKDirections(request: request); directions = value
        do {
            let response = try await value.calculateETA()
            guard generation == token else { return }
            walkingSeconds = response.expectedTravelTime
        } catch { if generation == token { notice = "도보 경로의 예상 시간을 확인하지 못했습니다." } }
    }
    func stop() { generation = UUID(); search?.cancel(); directions?.cancel(); searching = false }
}

struct NativeTravelView: View {
    @StateObject private var store = NativeTravelStore()
    @State private var arrival = Date().addingTimeInterval(3600)
    @State private var preparation = 10
    @State private var margin = 5
    @State private var selected: MKMapItem?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("외출은 여유 있게").font(.title.bold())
                Text("목적지를 찾고 준비 시간까지 함께 챙겨요.").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 14) {
                    TextField("장소 또는 주소", text: $store.query).textFieldStyle(.roundedBorder).submitLabel(.search).onSubmit { Task { await store.find() } }
                    HStack {
                        Button("목적지 검색") { Task { await store.find() } }.buttonStyle(.borderedProminent)
                        Button("현재 위치 확인") { store.locate() }.buttonStyle(.bordered)
                    }.frame(minHeight: 44)
                    if store.searching { ProgressView("목적지를 찾고 있어요") }
                    ForEach(Array(store.places.enumerated()), id: \.offset) { _, place in
                        Button { selected = place; Task { await store.estimate(place) } } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(place.name ?? "목적지").font(.headline)
                                Text(place.placemark.title ?? "").font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                }.careCard()
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker("도착 희망 시각", selection: $arrival, displayedComponents: [.date, .hourAndMinute])
                    Stepper("외출 준비 \(preparation)분", value: $preparation, in: 0...120, step: 5)
                    Stepper("여유 시간 \(margin)분", value: $margin, in: 0...30)
                    if let seconds = store.walkingSeconds, let start = NativeTravelPlanning.leaveBy(arrival: arrival, travelSeconds: seconds, preparationMinutes: preparation, marginMinutes: margin) {
                        Text("도보 예상 \(Int(ceil(seconds/60)))분").font(.headline)
                        Text("준비 시작 \(start.formatted(date: .abbreviated, time: .shortened))").font(.title3.bold())
                        if start < Date() { Text("지금 기준으로 준비 시간이 부족해요.").foregroundStyle(.orange) }
                    }
                    if let selected {
                        Button("Apple 지도에서 대중교통 경로 보기") {
                            selected.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit])
                        }.frame(minHeight: 44)
                    }
                    Text("앱 안의 예상 시간은 도보 기준입니다. 지하철 실시간 도착·혼잡도는 이번 네이티브 버전에 아직 이식되지 않았어요.").font(.caption).foregroundStyle(.secondary)
                }.careCard()
            }.padding(20)
        }.background(CareAppearance.background).navigationTitle("이동 준비").navigationBarTitleDisplayMode(.inline)
        .onDisappear { store.stop() }
        .alert("이동 안내", isPresented: Binding(get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })) { Button("확인") { store.notice = nil } } message: { Text(store.notice ?? "") }
    }
}
