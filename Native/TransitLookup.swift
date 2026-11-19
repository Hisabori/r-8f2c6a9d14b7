import Foundation

enum TransitLookup {
    // Seoul TOPIS OA-12764 published station-query aliases.
    static let aliases = ["응암":"응암순환(상선)","공릉":"공릉(서울산업대입구)","남한산성입구":"남한산성입구(성남법원, 검찰청)","대모산입구":"대모산","천호":"천호(풍납토성)","몽촌토성":"몽촌토성(평화의문)"]
    static func canonical(_ input:String)->String {
        var name=input.trimmingCharacters(in:.whitespacesAndNewlines)
        if name.hasSuffix("역") { name.removeLast() }
        name=name.replacingOccurrences(of:"\\([^)]*\\)",with:"",options:.regularExpression).replacingOccurrences(of:" ",with:"")
        return name == "응암순환" ? "응암" : name == "대모산" ? "대모산입구" : name
    }
    static func query(_ input:String)throws->String {
        guard input.count<=80,!input.unicodeScalars.contains(where:{CharacterSet.controlCharacters.contains($0)}),!input.contains(where:{"/?#\\".contains($0)}) else{throw PublicTransitError.invalidInput}
        let name=canonical(input)
        guard !name.isEmpty,name.count<=40 else{throw PublicTransitError.invalidInput}
        return aliases[name] ?? name
    }
    static func httpMessage(_ status:Int)->String {
        switch status {
        case 401,403:return "서울시 인증을 거부했습니다. 키의 지하철 API 권한을 확인하세요."
        case 429:return "서울시 요청 한도에 도달했습니다. 잠시 후 직접 다시 조회하세요."
        case 500...599:return "서울시 제공 서버가 응답하지 않습니다. 잠시 후 직접 다시 조회하세요."
        default:return "서울시 응답을 확인할 수 없습니다. 지원 역 이름과 API 권한을 확인하세요."
        }
    }
}
