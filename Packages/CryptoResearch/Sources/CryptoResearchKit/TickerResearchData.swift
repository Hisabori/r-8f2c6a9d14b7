import Foundation
import Security

enum TickerResearchKey {
    private static let service = "app.caresuite.super.research.alpha-vantage"
    static func read() -> String {
        let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"market-data",kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary,&result) == errSecSuccess,let data = result as? Data else { return "" }
        return String(data:data,encoding:.utf8) ?? ""
    }
    static func save(_ raw: String) throws {
        let value = raw.trimmingCharacters(in:.whitespacesAndNewlines)
        guard value.isEmpty || (value.lowercased() != "demo" && value.range(of:"^[A-Za-z0-9]{8,128}$",options:.regularExpression) != nil) else { throw ResearchFailure.invalidData }
        let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"market-data"]
        if value.isEmpty { let status = SecItemDelete(query as CFDictionary); guard status == errSecSuccess || status == errSecItemNotFound else { throw ResearchFailure.unavailable }; return }
        let attributes: [String:Any] = [kSecValueData as String:Data(value.utf8),kSecAttrAccessible as String:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary,attributes as CFDictionary)
        if status == errSecItemNotFound { var insert = query; for (key,value) in attributes { insert[key] = value }; guard SecItemAdd(insert as CFDictionary,nil) == errSecSuccess else { throw ResearchFailure.unavailable } }
        else if status != errSecSuccess { throw ResearchFailure.unavailable }
    }
}

enum TickerResearchParsing {
    static func object(_ data: Data) throws -> [String:Any] {
        guard data.count <= 2*1024*1024 else { throw ResearchFailure.oversized }
        guard let value = try JSONSerialization.jsonObject(with:data) as? [String:Any] else { throw ResearchFailure.invalidData }
        if value["Note"] != nil { throw ResearchFailure.rateLimit }
        if value["Information"] != nil || value["Error Message"] != nil { throw ResearchFailure.unavailable }
        return value
    }
    static func binance(_ data: Data, now: Date) throws -> [ResearchBar] {
        guard data.count <= 2*1024*1024,let rows = try JSONSerialization.jsonObject(with:data) as? [[Any]],rows.count <= 1000 else { throw ResearchFailure.invalidData }
        var bars: [ResearchBar] = []
        for row in rows {
            guard row.count >= 7,let closeMS = (row[6] as? NSNumber)?.doubleValue,closeMS.isFinite else { throw ResearchFailure.invalidData }
            let time = Date(timeIntervalSince1970:closeMS/1000)
            guard time <= now else { continue } // Never use the currently forming daily candle.
            func value(_ i: Int) throws -> Double { guard let s = row[i] as? String,let v = Double(s),v.isFinite else { throw ResearchFailure.invalidData }; return v }
            bars.append(try ResearchBar(time:time,open:value(1),high:value(2),low:value(3),close:value(4),volume:value(5)))
        }
        return bars.sorted { $0.time < $1.time }
    }
    static func equities(_ data: Data, ticker: ResearchTicker, now: Date) throws -> [ResearchBar] {
        let input = try object(data)
        guard let meta = input["Meta Data"] as? [String:Any],let symbol = meta["2. Symbol"] as? String,symbol.uppercased() == ticker.symbol,
              let zone = meta["5. Time Zone"] as? String,["US/Eastern","America/New_York"].contains(zone),
              let raw = input["Time Series (Daily)"] as? [String:[String:String]],raw.count <= 1000 else { throw ResearchFailure.invalidData }
        let date = DateFormatter(); date.locale = Locale(identifier:"en_US_POSIX");date.timeZone = TimeZone(identifier:"America/New_York");date.dateFormat = "yyyy-MM-dd HH:mm:ss";date.isLenient = false
        var bars: [ResearchBar] = []
        for (day,fields) in raw {
            guard let time = date.date(from:day+" 16:00:00") else { throw ResearchFailure.invalidData }
            guard time <= now else { continue }
            func value(_ key: String) throws -> Double { guard let s = fields[key],let v = Double(s),v.isFinite else { throw ResearchFailure.invalidData };return v }
            bars.append(try ResearchBar(time:time,open:value("1. open"),high:value("2. high"),low:value("3. low"),close:value("4. close"),volume:value("5. volume")))
        }
        return bars.sorted { $0.time < $1.time }
    }
    static func news(_ data: Data, ticker: ResearchTicker) throws -> [ResearchHeadline] {
        let input = try object(data)
        guard let feed = input["feed"] as? [[String:Any]],feed.count <= 1000 else { throw ResearchFailure.invalidData }
        let date = DateFormatter();date.locale = Locale(identifier:"en_US_POSIX");date.timeZone = TimeZone(secondsFromGMT:0);date.dateFormat = "yyyyMMdd'T'HHmmss";date.isLenient = false
        return feed.compactMap { item in
            guard let sentiments = item["ticker_sentiment"] as? [[String:Any]],sentiments.contains(where: {
                guard let symbol = $0["ticker"] as? String,let s = $0["relevance_score"] as? String,let relevance = Double(s),relevance.isFinite,relevance >= 0.2 else { return false }
                return [ticker.base,"CRYPTO:"+ticker.base].contains(symbol.uppercased())
            }),let title = item["title"] as? String,let url = item["url"] as? String,let source = item["source"] as? String,let rawTime = item["time_published"] as? String,let time = date.date(from:rawTime) else { return nil }
            return ResearchHeadline(source:source,title:title,url:url,time:time)
        }
    }
    static func imported(_ data: Data, ticker: ResearchTicker, now: Date) throws -> ResearchReport {
        guard data.count <= 2*1024*1024 else { throw ResearchFailure.oversized }
        struct Input: Decodable {
            struct Bar: Decodable { let time: Date,open: Double,high: Double,low: Double,close: Double,volume: Double,closed: Bool }
            let research_schema_version: Int,asset: ResearchAsset,symbol: String,synthetic: Bool
            let bars: [Bar],news: [ResearchHeadline],community: [ResearchHeadline]
        }
        let decoder = JSONDecoder();decoder.dateDecodingStrategy = .iso8601
        let input = try decoder.decode(Input.self,from:data)
        guard input.research_schema_version == 1,input.asset == ticker.asset,input.symbol == ticker.symbol,input.bars.count <= 1000,input.news.count <= 1000,input.community.count <= 1000,input.bars.allSatisfy(\.closed) else { throw ResearchFailure.invalidData }
        let bars = input.bars.map { ResearchBar(time:$0.time,open:$0.open,high:$0.high,low:$0.low,close:$0.close,volume:$0.volume) }
        return try TickerResearchMath.report(ticker:ticker,bars:bars,news:input.news,community:input.community,now:now,source:"가져온 종목 연구 파일 · 일봉",synthetic:input.synthetic,imported:true)
    }
}

struct TickerResearchService {
    // Injectable transport is also used by deterministic tests; order APIs are absent.
    var fetch: (URL) async throws -> Data = TickerResearchService.network
    static func network(_ url: URL) async throws -> Data {
        guard url.scheme == "https",["data-api.binance.vision","www.alphavantage.co","gall.dcinside.com"].contains(url.host),url.user == nil,url.password == nil else { throw ResearchFailure.unavailable }
        let config = URLSessionConfiguration.ephemeral;config.urlCache = nil;config.httpCookieStorage = nil;config.httpShouldSetCookies = false;config.timeoutIntervalForRequest = 20;config.timeoutIntervalForResource = 25
        let session = URLSession(configuration:config,delegate:CommunityRedirectGuard(),delegateQueue:nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url:url);request.setValue("OnCareTickerResearch/0.3 (public-market-data)",forHTTPHeaderField:"User-Agent")
        let bytes: URLSession.AsyncBytes,response: URLResponse
        do { (bytes,response) = try await session.bytes(for:request) } catch is CancellationError { throw CancellationError() } catch { throw ResearchFailure.unavailable }
        guard let http = response as? HTTPURLResponse else { throw ResearchFailure.unavailable }
        if http.statusCode == 429 { throw ResearchFailure.rateLimit }
        guard http.statusCode == 200 else { throw ResearchFailure.unavailable }
        var data = Data()
        for try await byte in bytes { try Task.checkCancellation();guard data.count < 2*1024*1024 else { throw ResearchFailure.oversized };data.append(byte) }
        return data
    }
    static func url(_ host: String,path: String,query: [String:String]) -> URL {
        var parts = URLComponents();parts.scheme = "https";parts.host = host;parts.path = path;parts.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name:$0.key,value:$0.value) };return parts.url!
    }
    func analyze(_ ticker: ResearchTicker, key: String, now: Date = Date()) async throws -> ResearchReport {
        var bars: [ResearchBar] = [],news: [ResearchHeadline] = [],community: [ResearchHeadline] = [],notices: [String] = []
        let source = ticker.asset == .crypto ? "Binance 공개 시세 · USDT · UTC 일봉":"Alpha Vantage · USD · 미국 정규장 확정 일봉"
        do {
            if ticker.asset == .crypto {
                bars = try TickerResearchParsing.binance(await fetch(Self.url("data-api.binance.vision",path:"/api/v3/klines",query:["symbol":ticker.symbol,"interval":"1d","limit":"120"])),now:now)
            } else {
                guard !key.isEmpty else { throw ResearchFailure.missingKey }
                bars = try TickerResearchParsing.equities(await fetch(Self.url("www.alphavantage.co",path:"/query",query:["function":"TIME_SERIES_DAILY","symbol":ticker.symbol,"outputsize":"compact","apikey":key])),ticker:ticker,now:now)
            }
            guard !bars.isEmpty,bars.allSatisfy(\.valid),zip(bars,bars.dropFirst()).allSatisfy({$0.0.time < $0.1.time}) else { bars = [];throw ResearchFailure.invalidData }
        } catch is CancellationError { throw CancellationError() } catch { notices.append("가격·거래량: \((error as? ResearchFailure)?.localizedDescription ?? "조회 실패")") }
        try Task.checkCancellation()
        if key.isEmpty { notices.append("뉴스: 분석 데이터 키 미설정 · 제외") }
        else {
            do { news = try TickerResearchParsing.news(await fetch(Self.url("www.alphavantage.co",path:"/query",query:["function":"NEWS_SENTIMENT","tickers":ticker.asset == .crypto ? "CRYPTO:"+ticker.base:ticker.symbol,"sort":"LATEST","limit":"50","apikey":key])),ticker:ticker) }
            catch is CancellationError { throw CancellationError() } catch { notices.append("뉴스: \((error as? ResearchFailure)?.localizedDescription ?? "조회 실패")") }
        }
        try Task.checkCancellation()
        if ticker.asset == .crypto,CommunityCore.symbols.contains(ticker.base) {
            do {
                let data = try await fetch(URL(string:CommunityCore.dcList)!)
                guard let html = String(data:data,encoding:.utf8) else { throw ResearchFailure.invalidData }
                let dataset = try CommunityCore.dcHTML(html,Int64(now.timeIntervalSince1970*1000))
                let analysis = CommunityCore.analyze(dataset,ticker.base,168,Int64(now.timeIntervalSince1970*1000))
                community = analysis.posts.map { ResearchHeadline(source:$0.source,title:$0.title,url:$0.url,time:Date(timeIntervalSince1970:Double($0.published_ms)/1000)) }
                notices.append("커뮤니티: 디시 최신 1페이지 일부 표본 · 전체 여론이 아님")
            } catch is CancellationError { throw CancellationError() } catch { notices.append("커뮤니티: 공개 목록 접근·파싱 실패 · 제외") }
        } else { notices.append("이 티커의 커뮤니티는 연구 JSON으로 가져오세요. 자동 수집 표본은 없습니다.") }
        try Task.checkCancellation()
        return try TickerResearchMath.report(ticker:ticker,bars:bars,news:news,community:community,now:now,source:source,notices:notices)
    }
}
