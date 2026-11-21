import SwiftUI
import UIKit
enum TrainInteriorDensity {
    static func counts(_ value:Double)->(Int,Int)? {
        guard value.isFinite,(0...500).contains(value) else{return nil}
        let seated=value==0 ? 0:max(1,Int((min(value,34)/34*12).rounded()))
        let standing=Int(((min(max(value,34),200)-34)/166*42).rounded())
        return (seated,standing)
    }
}
struct TrainInteriorView:View {
    private static let backdrop=UIImage(named:"train-cabin-warm-v1")
    let percent:Double
    var illustrative=false
    var body:some View {
        VStack(alignment:.leading,spacing:8){
            Text("객실 내부 · 평균 밀도 시뮬레이션").font(.headline)
            Canvas{context,size in
                context.scaleBy(x:size.width/720,y:size.height/450)
                func polygon(_ points:[CGPoint],_ color:Color){var p=Path();p.addLines(points);p.closeSubpath();context.fill(p,with:.color(color))}
                func box(_ rect:CGRect,_ color:Color,_ radius:CGFloat=8){context.fill(Path(roundedRect:rect,cornerRadius:radius),with:.color(color))}
                func point(_ u:Double,_ z:Double,_ height:Double=0)->CGPoint{CGPoint(x:360+u*(120+240*z),y:250+190*z-height*(0.48+0.75*z))}
                if let backdrop=Self.backdrop{context.draw(Image(uiImage:backdrop),in:CGRect(x:0,y:0,width:720,height:450))}else{
                polygon([.init(x:0,y:0),.init(x:720,y:0),.init(x:480,y:70),.init(x:240,y:70)],Color(red:0.95,green:0.96,blue:0.97))
                polygon([.init(x:0,y:0),.init(x:240,y:70),.init(x:240,y:250),.init(x:0,y:450)],Color(red:0.89,green:0.92,blue:0.94))
                polygon([.init(x:720,y:0),.init(x:480,y:70),.init(x:480,y:250),.init(x:720,y:450)],Color(red:0.89,green:0.92,blue:0.94))
                polygon([.init(x:240,y:250),.init(x:480,y:250),.init(x:720,y:450),.init(x:0,y:450)],Color(red:0.82,green:0.87,blue:0.9))
                box(CGRect(x:240,y:70,width:240,height:180),Color(red:0.85,green:0.89,blue:0.92),0)
                box(CGRect(x:285,y:95,width:150,height:155),.white,8);box(CGRect(x:298,y:112,width:55,height:74),.cyan.opacity(0.2));box(CGRect(x:366,y:112,width:55,height:74),.cyan.opacity(0.2))
                for side in [-1.0,1.0]{polygon([point(side,0.08,235),point(side,0.95,235),point(side,0.95,115),point(side,0.08,115)],.cyan.opacity(0.17));polygon([point(side*0.65,0.05,30),point(side,0.05,30),point(side,0.95,30),point(side*0.65,0.95,30)],.blue.opacity(0.5));var rail=Path();rail.move(to:point(side*0.52,0.03,225));rail.addLine(to:point(side*0.52,0.98,225));context.stroke(rail,with:.color(.gray),lineWidth:4)}
                }
                if let (seated,standing)=TrainInteriorDensity.counts(percent){
                    var people:[(Double,Double,Bool,Int)]=[]
                    for i in 0..<seated{people.append((i%2==0 ? -0.78:0.78,0.12+Double(i/2)*0.145,true,i))}
                    for i in 0..<standing{let cell=i*17%42;people.append((Double(cell%7-3)*0.135,0.08+Double(cell/7)*0.17,false,i+5))}
                    let clothes:[Color]=[.teal,.blue,.indigo,.brown,.gray]
                    for (u,z,sitting,index) in people.sorted(by:{$0.1<$1.1}){let foot=point(u,z,sitting ? 16:0);let unit=8+z*15;let head=CGPoint(x:foot.x,y:foot.y-unit*(sitting ? 3.15:4.2));box(CGRect(x:foot.x-unit*0.62,y:foot.y-unit*(sitting ? 2.85:3.8),width:unit*1.25,height:unit*1.8),clothes[index%clothes.count],unit*0.3);context.fill(Path(ellipseIn:CGRect(x:head.x-unit*0.46,y:head.y-unit*0.46,width:unit*0.92,height:unit*0.92)),with:.color(Color(red:0.85,green:0.71,blue:0.6)));for s in [-1.0,1.0]{var leg=Path();leg.move(to:CGPoint(x:foot.x+s*unit*0.3,y:foot.y-unit*(sitting ? 1.1:2)));leg.addLine(to:CGPoint(x:foot.x+s*unit*0.4,y:foot.y));context.stroke(leg,with:.color(.gray),style:StrokeStyle(lineWidth:unit*0.3,lineCap:.round))}}
                }
            }.aspectRatio(720.0/450.0,contentMode:.fit).clipShape(RoundedRectangle(cornerRadius:18))
            .accessibilityLabel("평균 혼잡도 \(percent,specifier:"%.1f")퍼센트의 객실 밀도 예시")
            Text("\(illustrative ? "시각화 가정값":"통계값") \(percent,specifier:"%.1f")% · 그림은 0~200% 범위에 맞춘 예시입니다. 사람 수·좌석·객차별 실시간 상태를 재현하지 않습니다.").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
struct TrainLocationView:View {
    let phase:String
    var body:some View{VStack(alignment:.leading,spacing:8){
        if let index=TrainPhaseStrip.index(phase){
            GeometryReader{geometry in let spacing=geometry.size.width/4
                ZStack(alignment:.topLeading){Capsule().fill(Color.secondary.opacity(0.2)).frame(height:4).offset(y:39);ForEach(0..<4){i in VStack(spacing:10){Image(systemName:i==index ? "tram.fill":"circle.fill").font(i==index ? .title2:.caption).foregroundStyle(i==index ? Color.accentColor:.secondary);Text(["전역","접근","선택역","출발"][i]).font(.caption)}.frame(width:spacing).offset(x:CGFloat(i)*spacing,y:8)}}
            }.frame(height:84)
            Text("도착상태 기반 위치 개요 · 지도 좌표/차량 GPS가 아닙니다.").font(.caption2).foregroundStyle(.secondary)
        }else{Text("열차 위치 상태 확인 필요").font(.caption)}
    }}
}
