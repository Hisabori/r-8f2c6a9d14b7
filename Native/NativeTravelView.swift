import SwiftUI
import MapKit
import CoreLocation
import UserNotifications

enum NativeTravelPlanning {
    static func leaveBy(arrival: Date, travelSeconds: Double, preparationMinutes: Int, marginMinutes: Int) -> Date? {
        guard travelSeconds.isFinite, travelSeconds >= 0, travelSeconds <= 86400,
              (0...120).contains(preparationMinutes), (0...30).contains(marginMinutes) else { return nil }
        return arrival.addingTimeInterval(-travelSeconds - Double(preparationMinutes + marginMinutes) * 60)
    }
}

@MainActor final class NativeTravelStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var query = ""
    @Published var arrival = Date().addingTimeInterval(3600)
    @Published var preparation = 10
    @Published var margin = 5
    @Published var useManualTime = false
    @Published var manualMinutes = 40
    @Published var selected: MKMapItem?
    private var locationRequested = false
    private var locationAt: Date?
    private var estimateAt: Date?
    private var routeGeneration = UUID()
    @Published private(set) var places: [MKMapItem] = []
    @Published private(set) var searching = false
    @Published private(set) var location: CLLocationCoordinate2D?
    @Published var notice: String?
    @Published private(set) var walkingSeconds: Double?
    private let manager = CLLocationManager()
    private var search: MKLocalSearch?
    private var directions: MKDirections?
    private var generation = UUID()
    override init() {
        super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        if let saved = UserDefaults.standard.dictionary(forKey:"suite.travel.settings"),
           let text = saved["query"] as? String, text.count <= 200,
           let ready = saved["preparation"] as? Int, (0...120).contains(ready),
           let buffer = saved["margin"] as? Int, (0...30).contains(buffer) {
            query = text; preparation = ready; margin = buffer
            if let minutes = saved["manualMinutes"] as? Int,(1...1440).contains(minutes) { manualMinutes = minutes }
            useManualTime = saved["useManualTime"] as? Bool ?? false
        }
    }
    func invalidateQuery() {
        selected = nil; walkingSeconds = nil; places = []
        routeGeneration = UUID(); generation = UUID()
        directions?.cancel(); search?.cancel(); searching = false
    }
    func saveSettings() {
        let text = query.trimmingCharacters(in:.whitespacesAndNewlines)
        guard text.count <= 200 else { notice = "목적지 입력은 200자 이하로 작성하세요."; return }
        UserDefaults.standard.set(["query":text,"preparation":preparation,"margin":margin,"manualMinutes":manualMinutes,"useManualTime":useManualTime],forKey:"suite.travel.settings")
        notice = "목적지 검색어와 준비·여유 시간을 이 기기에 저장했습니다."
    }
    func scheduleReminder(at date: Date) async {
        guard date.timeIntervalSinceNow > 1 else { notice = "미래의 준비 시각을 계산한 뒤 예약하세요."; return }
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options:[.alert,.sound]) else { notice = "알림 권한을 허용하면 준비 알림을 받을 수 있어요."; return }
            let interval = date.timeIntervalSinceNow
            guard interval > 1 else { notice = "준비 시각이 지났습니다. 다시 계산하세요."; return }
            let content = UNMutableNotificationContent()
            content.title = "나갈 준비를 시작할 시간이에요"
            content.body = "저장한 이동 계획을 확인하세요."
            content.sound = .default
            let request = UNNotificationRequest(identifier:"suite.travel.prepare",content:content,trigger:UNTimeIntervalNotificationTrigger(timeInterval:interval,repeats:false))
            try await center.add(request)
            notice = "준비 알림을 예약했습니다. 집중 모드 등 기기 설정에 따라 표시가 달라질 수 있습니다."
        } catch { notice = "준비 알림을 예약하지 못했습니다." }
    }
    func cancelReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers:["suite.travel.prepare"])
        center.removeDeliveredNotifications(withIdentifiers:["suite.travel.prepare"])
        notice = "준비 알림을 취소했습니다."
    }
    func locate() {
        locationRequested = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: notice = "현재 위치 권한이 없어도 목적지를 찾아 지도 앱에서 경로를 확인할 수 있어요."
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if self.locationRequested, [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus) { manager.requestLocation() }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last, abs(latest.timestamp.timeIntervalSinceNow) < 120, latest.horizontalAccuracy >= 0 else { return }
        Task { @MainActor in
            guard self.locationRequested else { return }
            self.locationRequested = false;self.locationAt = latest.timestamp
            self.location = latest.coordinate;self.walkingSeconds = nil
            self.routeGeneration = UUID();self.directions?.cancel()
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in guard self.locationRequested else { return };self.locationRequested = false;self.notice = "현재 위치를 확인하지 못했습니다. 잠시 후 다시 시도하세요." }
    }
    func find() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 200 else { return }
        search?.cancel(); routeGeneration = UUID(); directions?.cancel(); walkingSeconds = nil; places = []
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
        guard let location, let locationAt, Date().timeIntervalSince(locationAt) < 120 else { notice = "도보 예상 시간을 보려면 현재 위치를 먼저 확인하세요."; return }
        search?.cancel(); searching = false
        directions?.cancel(); walkingSeconds = nil
        let token = UUID(); routeGeneration = token; generation = UUID()
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: location))
        request.destination = destination; request.transportType = .walking
        let value = MKDirections(request: request); directions = value
        do {
            let response = try await value.calculateETA()
            guard routeGeneration == token else { return }
            walkingSeconds = response.expectedTravelTime;estimateAt = Date()
        } catch { if routeGeneration == token { notice = "도보 경로의 예상 시간을 확인하지 못했습니다." } }
    }
    func expireEstimate() { if estimateAt.map({ Date().timeIntervalSince($0) > 120 }) ?? true { walkingSeconds = nil } }
    func stop() { manager.stopUpdatingLocation();locationRequested = false;routeGeneration = UUID();generation = UUID(); search?.cancel(); routeGeneration = UUID(); directions?.cancel(); searching = false }
}

struct NativeTravelView: View {
    @EnvironmentObject private var store: NativeTravelStore
    @ObservedObject private var activity = NativeLiveStatus.shared
    private var arrival: Date { store.arrival }
    private var preparation: Int { store.preparation }
    private var margin: Int { store.margin }
    private var selected: MKMapItem? { store.selected }
    private var plannedSeconds: Double? {
        store.useManualTime ? Double(store.manualMinutes)*60 : store.walkingSeconds
    }
    private func planSummary(start: Date,seconds: Double) -> String {
        let depart = start.addingTimeInterval(Double(preparation)*60)
        let destination = store.useManualTime ? store.query : (selected?.placemark.title ?? selected?.name ?? store.query)
        let mode = store.useManualTime ? "직접 입력 이동시간":"도보 예상"
        return [
            "이동 계획",
            destination,
            "준비 시작 "+start.formatted(date:.abbreviated,time:.shortened),
            "출발 "+depart.formatted(date:.abbreviated,time:.shortened),
            "도착 목표 "+arrival.formatted(date:.abbreviated,time:.shortened),
            mode+" "+String(Int(ceil(seconds/60)))+"분"
        ].joined(separator:"\n")
    }
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
                    Button("목적지·준비 시간 저장") { store.saveSettings() }.frame(minHeight:44)
                    if store.searching { ProgressView("목적지를 찾고 있어요") }
                    ForEach(Array(store.places.enumerated()), id: \.offset) { _, place in
                        Button { store.selected = place; Task { await store.estimate(place) } } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(place.name ?? "목적지").font(.headline)
                                Text(place.placemark.title ?? "").font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                }.careCard()
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker("도착 희망 시각", selection: $store.arrival, displayedComponents: [.date, .hourAndMinute])
                    Stepper("외출 준비 \(preparation)분", value: $store.preparation, in: 0...120, step: 5)
                    Stepper("여유 시간 \(margin)분", value: $store.margin, in: 0...30)
                    Toggle("이동 시간 직접 입력",isOn:$store.useManualTime)
                    if store.useManualTime {
                        Stepper("이동 \(store.manualMinutes)분",value:$store.manualMinutes,in:1...1440)
                    }
                    if let seconds = plannedSeconds, let start = NativeTravelPlanning.leaveBy(arrival: arrival, travelSeconds: seconds, preparationMinutes: preparation, marginMinutes: margin) {
                        Text((store.useManualTime ? "직접 입력 ":"도보 예상 ")+String(Int(ceil(seconds/60)))+"분").font(.headline)
                        ShareLink(item:planSummary(start:start,seconds:seconds)) {
                            Label("이동 계획 공유",systemImage:"square.and.arrow.up")
                        }.frame(minHeight:44)
                        Button("준비 시작 알림 예약") { Task { await store.scheduleReminder(at:start) } }.frame(minHeight:44)
                        Button("준비 시각을 잠금 화면에 표시") { NativeLiveStatus.shared.showTravel(prepareAt:start,arrival:arrival,walkingSeconds:seconds,departureAt:start.addingTimeInterval(Double(preparation)*60),manual:store.useManualTime) }.frame(minHeight:44)
                        Button("이동 표시 종료") { NativeLiveStatus.shared.endTravel() }.font(.subheadline)
                        Text(activity.travelMessage).font(.caption).foregroundStyle(.secondary)
                        Text("준비 시작 \(start.formatted(date: .abbreviated, time: .shortened))").font(.title3.bold())
                        if start < Date() { Text("지금 기준으로 준비 시간이 부족해요.").foregroundStyle(.orange) }
                    }
                    Button("준비 알림 취소") { store.cancelReminder() }.frame(minHeight:44)
                    if let selected {
                        Button("Apple 지도에서 대중교통 경로 보기") {
                            selected.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit])
                        }.frame(minHeight: 44)
                    }
                    Text("직접 입력한 시간 또는 마지막 도보 예상으로 계산합니다. 지하철 실시간 도착·혼잡도는 이 화면에 아직 연결되지 않았어요.").font(.caption).foregroundStyle(.secondary)
                }.careCard()
            }.padding(20)
        }.background(CareAppearance.background).navigationTitle("이동 준비").navigationBarTitleDisplayMode(.inline)
        .onChange(of:store.query) { _ in store.invalidateQuery(); NativeLiveStatus.shared.endTravel() }
        .onChange(of:store.useManualTime) { _ in NativeLiveStatus.shared.endTravel() }
        .onChange(of:store.manualMinutes) { _ in NativeLiveStatus.shared.endTravel() }
        .onChange(of:arrival) { _ in NativeLiveStatus.shared.endTravel() }
        .onChange(of:preparation) { _ in NativeLiveStatus.shared.endTravel() }
        .onChange(of:margin) { _ in NativeLiveStatus.shared.endTravel() }
        .onChange(of:store.selected.map { ObjectIdentifier($0) }) { _ in NativeLiveStatus.shared.endTravel() }
        .onAppear { store.expireEstimate() }
        .onDisappear { store.stop() }
        .alert("이동 안내", isPresented: Binding(get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })) { Button("확인") { store.notice = nil } } message: { Text(store.notice ?? "") }
    }
}
