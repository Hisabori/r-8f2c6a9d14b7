import SwiftUI
import Foundation

struct PublicTrainArrival: Identifiable {
    let id: Int
    let line: String
    let direction: String
    let message: String
    let generatedAt: Date
    func isFresh(at now: Date) -> Bool { (-30...120).contains(now.timeIntervalSince(generatedAt)) }
}
enum PublicTransitError: Error { case invalidInput, invalidResponse, tooLarge }
enum PublicTransitData {
    static func station(_ value: String) -> String {
        let value = value.trimmingCharacters(in:.whitespacesAndNewlines)
        return value.hasSuffix("역") ? String(value.dropLast()) : value
    }
    static func endpoint(station input: String,key: String) throws -> URL {
        let name = input.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty,name.count <= 40,!name.contains(where: { $0.isNewline || $0 == "/" || $0 == "?" || $0 == "#" }),
              (1...128).contains(key.utf8.count),key.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }) else { throw PublicTransitError.invalidInput }
        var url = URL(string:"https://swopenapi.seoul.go.kr")!
        for component in ["api","subway",key,"json","realtimeStationArrival","0","100",name] { url.appendPathComponent(component) }
        return url
    }
    static func parse(_ data: Data,station name: String,now: Date) throws -> [PublicTrainArrival] {
        guard data.count <= 2_097_152 else { throw PublicTransitError.tooLarge }
        guard let root = try JSONSerialization.jsonObject(with:data) as? [String:Any],
              let rows = root["realtimeArrivalList"] as? [[String:Any]],rows.count <= 100 else { throw PublicTransitError.invalidResponse }
        let formatter = DateFormatter();formatter.locale = Locale(identifier:"en_US_POSIX")
        formatter.timeZone = TimeZone(identifier:"Asia/Seoul");formatter.dateFormat = "yyyy-MM-dd HH:mm:ss";formatter.isLenient = false
        return rows.enumerated().compactMap { index,row -> PublicTrainArrival? in
            guard let stationName = row["statnNm"] as? String,station(stationName) == station(name),
                  let raw = row["recptnDt"] as? String,raw.count == 19,let date = formatter.date(from:raw),
                  let line = row["trainLineNm"] as? String,line.count <= 200,
                  let direction = row["updnLine"] as? String,direction.count <= 40,
                  let message = row["arvlMsg2"] as? String,message.count <= 300 else { return nil }
            let value = PublicTrainArrival(id:index,line:line,direction:direction,message:message,generatedAt:date)
            return value.isFresh(at:now) ? value:nil
        }.prefix(30).map { $0 }
    }
    static func crowd(_ data: Data,station name: String,at date: Date) throws -> [String] {
        guard data.count <= 1_048_576,let root = try JSONSerialization.jsonObject(with:data) as? [String:Any],
              let headers = root["headers"] as? [String],let rows = root["rows"] as? [[String]],rows.count <= 5000 else { throw PublicTransitError.invalidResponse }
        var calendar = Calendar(identifier:.gregorian);calendar.timeZone = TimeZone(identifier:"Asia/Seoul")!
        let hour = calendar.component(.hour,from:date),minute = calendar.component(.minute,from:date) < 30 ? "00":"30"
        let weekday = calendar.component(.weekday,from:date)
        let day = weekday == 1 ? "일요일":weekday == 7 ? "토요일":"평일"
        guard let column = headers.firstIndex(of:"\(hour)시\(minute)분") ?? (hour == 0 ? headers.firstIndex(of:"00시\(minute)분") : nil), column >= 5 else { return [] }
        return rows.compactMap { row -> String? in
            guard row.count > column,row.count >= 5,row[0] == day,station(row[3]) == station(name),
                  let value = Double(row[column].trimmingCharacters(in:.whitespaces)),value.isFinite,value >= 0,value <= 500 else { return nil }
            return "\(row[1]) · \(row[4]) · \(value.formatted(.number.precision(.fractionLength(1))))%"
        }.prefix(20).map { $0 }
    }
}
private final class TransitHTTPSDelegate: NSObject,URLSessionTaskDelegate {
    func urlSession(_ session: URLSession,task: URLSessionTask,willPerformHTTPRedirection response: HTTPURLResponse,newRequest request: URLRequest,completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
@MainActor final class PublicTransitStore: ObservableObject {
    @Published private(set) var arrivals: [PublicTrainArrival] = []
    @Published private(set) var status = "역 이름과 서울시 인증키를 입력한 뒤 조회하세요."
    @Published private(set) var busy = false
    @Published private(set) var receivedAt: Date?
    private var task: Task<Void,Never>?
    private var generation = UUID()
    private var lastRequest = Date.distantPast
    private let session: URLSession
    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15;configuration.timeoutIntervalForResource = 20
        session = URLSession(configuration:configuration,delegate:TransitHTTPSDelegate(),delegateQueue:nil)
    }
    func cancel() { generation = UUID();task?.cancel();task = nil;busy = false;arrivals = [];receivedAt = nil }
    func load(station: String,key: String) {
        guard !busy else { return }
        guard let url = try? PublicTransitData.endpoint(station:station,key:key) else { cancel();status = "역 이름과 영문·숫자 인증키를 확인하세요.";return }
        guard Date().timeIntervalSince(lastRequest) >= 15 else { status = "요청 간격 보호: 15초 뒤 다시 조회하세요.";return }
        cancel();lastRequest = Date();let token = generation;busy = true;status = "서울시 도착정보 조회 중"
        task = Task {
            do {
                let (stream,response) = try await session.bytes(from:url)
                guard let http = response as? HTTPURLResponse,http.statusCode == 200 else { throw PublicTransitError.invalidResponse }
                var data = Data()
                for try await byte in stream { if Task.isCancelled { throw CancellationError() };guard data.count < 2_097_152 else { throw PublicTransitError.tooLarge };data.append(byte) }
                let received = Date();let rows = try PublicTransitData.parse(data,station:station,now:received)
                guard !Task.isCancelled,generation == token else { return }
                arrivals = rows;receivedAt = received;busy = false;task = nil
                status = rows.isEmpty ? "최근 120초 이내 도착정보가 없습니다.":"서울시 제공 · 생성 시각을 확인하세요. 실시간 값은 지연될 수 있습니다."
            } catch {
                guard !Task.isCancelled,generation == token else { return }
                busy = false;task = nil;arrivals = [];receivedAt = nil
                status = "조회 실패: 인증키 권한·HTTPS 제공 상태·네트워크를 확인하세요. 평문 HTTP로 재시도하지 않습니다."
            }
        }
    }
}
struct NativePublicTransitView: View {
    @StateObject private var store = PublicTransitStore()
    @State private var station = ""
    @State private var key = ""
    @State private var crowd: [String] = []
    @State private var crowdStatus = "키 없이 조회할 수 있는 2026-06-30 기준 평균 통계입니다."
    @State private var crowdAt: Date?
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                Text("외출 전, 공공교통 확인").font(.title2.bold())
                VStack(alignment:.leading,spacing:12) {
                    TextField("서울 지하철 역 이름",text:$station).textFieldStyle(.roundedBorder).accessibilityIdentifier("public-transit-station")
                    SecureField("서울 열린데이터 인증키",text:$key).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                    Text("인증키와 역 이름은 조회 시 서울시 API에 HTTPS로 전송합니다. 키는 저장하지 않으며 화면을 나가면 지웁니다.").font(.caption).foregroundStyle(.secondary)
                    Link("서울시 API 안내·키 발급",destination:URL(string:"https://data.seoul.go.kr/dataList/OA-12764/A/1/datasetView.do")!)
                    Button("지하철 도착정보 조회") { store.load(station:station,key:key) }.disabled(store.busy).frame(minHeight:44)
                    if store.busy { ProgressView() }
                    Text(store.status).font(.subheadline).accessibilityIdentifier("public-transit-status")
                    if let received = store.receivedAt { Text("앱 수신 "+received.formatted(date:.abbreviated,time:.standard)).font(.caption) }
                    TimelineView(.periodic(from:.now,by:15)) { context in
                        VStack(alignment:.leading,spacing:12) {
                            ForEach(store.arrivals) { row in
                                VStack(alignment:.leading,spacing:4) {
                                    Text(row.line+" · "+row.direction).font(.headline)
                                    Text(row.isFresh(at:context.date) ? row.message:"오래된 정보 · 다시 조회하세요")
                                    Text("생성 "+row.generatedAt.formatted(date:.abbreviated,time:.standard)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }.careCard()
                VStack(alignment:.leading,spacing:12) {
                    Text("시간대별 평균 혼잡도").font(.headline)
                    Text("실시간 열차·객차 혼잡도가 아닙니다. 한국시간의 요일·30분 구간 기준이며 공휴일은 자동 반영하지 않습니다.").font(.caption).foregroundStyle(.secondary)
                    Button("현재 시간대 평균 혼잡도") { loadCrowd() }.frame(minHeight:44)
                    Text(crowdStatus)
                    if let date = crowdAt { Text("선택 시각 "+date.formatted(date:.abbreviated,time:.shortened)).font(.caption) }
                    ForEach(Array(crowd.enumerated()),id:\.offset) { _,text in Text(text) }
                    Link("출처: 서울교통공사 · 공공데이터포털",destination:URL(string:"https://www.data.go.kr/data/15071311/fileData.do")!)
                }.careCard()
            }.padding(20)
        }.background(CareAppearance.background).navigationTitle("공공교통 정보")
        .onChange(of:station) { _ in store.cancel();crowd = [];crowdAt = nil }
        .onChange(of:key) { _ in store.cancel() }
        .onDisappear { store.cancel();key = "" }
    }
    private func loadCrowd() {
        crowd = [];crowdAt = nil
        let name = station.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty else { crowdStatus = "역 이름을 입력하세요.";return }
        do {
            guard let url = Bundle.main.url(forResource:"transit-crowd-20260630",withExtension:"json") else { throw PublicTransitError.invalidResponse }
            let now = Date();crowd = try PublicTransitData.crowd(Data(contentsOf:url),station:name,at:now);crowdAt = now
            crowdStatus = crowd.isEmpty ? "해당 역·시간대 통계가 없습니다.":"자료 기준 2026-06-30 · 정원 대비 평균 승차인원(%)"
        } catch { crowdStatus = "통계 자료를 읽지 못했습니다. 기존 이동 계획은 계속 사용할 수 있습니다." }
    }
}
