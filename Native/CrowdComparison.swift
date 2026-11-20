import SwiftUI

struct CrowdTimePoint:Identifiable {
    let slot:Int
    let percent:Double?
    var id:Int{slot}
    var time:String{String(format:"%02d:%02d",slot/2,slot%2*30)}
}
struct CrowdComparison:Identifiable {
    let id:Int
    let title:String
    let selected:Int
    let points:[CrowdTimePoint]
    var best:CrowdTimePoint? {
        let known=points.filter{$0.percent != nil}
        guard known.count>=2 else{return nil}
        return known.sorted { a,b in
            if a.percent! != b.percent! { return a.percent! < b.percent! }
            if abs(a.slot-selected) != abs(b.slot-selected) {return abs(a.slot-selected)<abs(b.slot-selected)}
            return a.slot<b.slot
        }.first
    }
    static func points(headers:[String],row:[String],selected:Int)->[CrowdTimePoint] {
        guard (0..<48).contains(selected) else{return []}
        return (max(0,selected-2)...min(47,selected+2)).map{slot in
            let name="\(slot/2)시\(slot%2==0 ? "00":"30")분"
            let alternate="00시\(slot%2==0 ? "00":"30")분"
            let column=headers.firstIndex(of:name) ?? (slot<2 ? headers.firstIndex(of:alternate):nil)
            var value:Double?
            if let column,column>=5,column<row.count,let number=Double(row[column].trimmingCharacters(in:.whitespaces)),number.isFinite,(0...500).contains(number){value=number}
            return CrowdTimePoint(slot:slot,percent:value)
        }
    }
    static func profiles(_ data:Data,station:String,at date:Date,dayOverride:String?)throws->[CrowdComparison] {
        guard data.count<=1_048_576,let root=try JSONSerialization.jsonObject(with:data) as? [String:Any],let headers=root["headers"] as? [String],let rows=root["rows"] as? [[String]],rows.count<=5000 else{throw PublicTransitError.invalidResponse}
        var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(identifier:"Asia/Seoul")!
        let slot=calendar.component(.hour,from:date)*2+calendar.component(.minute,from:date)/30
        let weekday=calendar.component(.weekday,from:date)
        let day=dayOverride ?? (weekday==1 ? "일요일":weekday==7 ? "토요일":"평일")
        return rows.enumerated().compactMap{index,row in
            guard row.count>=5,row[0]==day,TransitLookup.canonical(row[3])==TransitLookup.canonical(station) else{return nil}
            return CrowdComparison(id:index,title:row[1]+" · "+row[4],selected:slot,points:points(headers:headers,row:row,selected:slot))
        }.prefix(20).map{$0}
    }
}
struct CrowdComparisonView:View {
    let profile:CrowdComparison
    var body:some View{VStack(alignment:.leading,spacing:10){
        Text(profile.title).font(.headline)
        HStack(alignment:.bottom,spacing:8){ForEach(profile.points){point in
            VStack(spacing:5){
                Text(point.percent.map{String(format:"%.1f%%",$0)} ?? "자료 없음").font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                ZStack(alignment:.bottom){RoundedRectangle(cornerRadius:5).fill(Color.secondary.opacity(0.1));if let number=point.percent {RoundedRectangle(cornerRadius:5).fill(point.slot==profile.selected ? Color.accentColor:Color.teal.opacity(0.65)).frame(height:max(2,CGFloat(min(number,200)/200*64)))}}.frame(height:64)
                Text(point.time).font(.caption2).fontWeight(point.slot==profile.selected ? .bold:.regular)
            }.frame(maxWidth:.infinity).accessibilityElement(children:.ignore).accessibilityLabel(point.time+" · "+(point.percent.map{String(format:"평균 %.1f퍼센트",$0)} ?? "자료 없음")+(point.slot==profile.selected ? " · 선택 시각":""))
        }}
        if let best=profile.best,let percent=best.percent {Text("비교 가능한 시간 중 가장 낮음 · \(best.time) · \(percent,specifier:"%.1f")%").font(.caption).foregroundStyle(.secondary)}else{Text("비교할 수 있는 통계가 2개 미만입니다.").font(.caption).foregroundStyle(.secondary)}
    }.padding(.vertical,8)}
}
