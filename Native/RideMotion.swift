import SwiftUI

struct RideFrame {
    let speed:Double, lateral:Double, longitudinal:Double, roll:Double, pitch:Double
    static let zero=RideFrame(speed:0,lateral:0,longitudinal:0,roll:0,pitch:0)
}
enum RideMotion {
    static let names=["정차","완만 주행","곡선 주행","감속"]
    static func input(_ mode:Int,_ t:Double)->(Double,Double,Double){
        if mode==0{return (0,0,0)}
        let speed=mode==1 ? 60/3.6+0.4*sin(0.3*t):mode==2 ? 40/3.6:max(0,30/3.6-0.4*t)
        let longitudinal=mode==1 ? 0.12*cos(0.3*t):mode==3 && speed>0 ? -0.4:0
        let rough=speed==0 ? 0:min(1,t/1.5)*(0.05*sin(2*Double.pi*speed/12*t)+0.025*sin(2*Double.pi*speed/5*t))
        return (speed, (mode==2 ? speed*speed/500:0)+rough, longitudinal)
    }
    static func sample(_ mode:Int,_ t:Double)throws->RideFrame {
        guard (0...3).contains(mode),t.isFinite,(0...30).contains(t) else{throw PublicTransitError.invalidInput}
        var roll=0.0,rollVelocity=0.0,pitch=0.0,pitchVelocity=0.0
        let count=Int(ceil(t*120)),dt=count==0 ? 0:t/Double(count),w=2*Double.pi*1.1,p=2*Double.pi*1.4
        for i in 0..<count{let (_,ay,ax)=input(mode,(Double(i)+0.5)*dt)
            rollVelocity+=(-2*0.38*w*rollVelocity-w*w*roll-ay/9.80665*w*w)*dt;roll+=rollVelocity*dt
            pitchVelocity+=(-2*0.45*p*pitchVelocity-p*p*pitch+ax/9.80665*p*p)*dt;pitch+=pitchVelocity*dt
        }
        let (v,ay,ax)=input(mode,t)
        return RideFrame(speed:v*3.6,lateral:ay,longitudinal:ax,roll:max(-3,min(3,roll*180/Double.pi)),pitch:max(-3,min(3,pitch*180/Double.pi)))
    }
}
struct RideMotionView:View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scene
    @State private var mode=1
    @State private var running=false
    @State private var frame=RideFrame.zero
    @State private var message="직접 시작하면 최대 30초 재생합니다. 실제 열차 센서·운행 예측이 아닙니다."
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:16){
        Text("전철의 흔들림, 가정값으로 계산").font(.title2.bold())
        Text(message).font(.subheadline).accessibilityIdentifier("ride-motion-status")
        Picker("가상 운행 조건",selection:$mode){ForEach(0..<4){Text(RideMotion.names[$0]).tag($0)}}.pickerStyle(.segmented)
        TrainInteriorView(percent:0,illustrative:true).rotationEffect(.degrees(frame.roll)).rotation3DEffect(.degrees(frame.pitch),axis:(x:1,y:0,z:0),perspective:0.2).offset(x:max(-6,min(6,frame.roll*2)),y:max(-4,min(4,frame.pitch))).padding(8).clipped().accessibilityLabel("가상 열차 객실 · 시각화용 빈 객실")
        Text(String(format:"속도 %.1f km/h\n횡가속도 %.3f m/s² · 종가속도 %.3f m/s²\n표시 롤 %.2f° · 피치 %.2f°",frame.speed,frame.lateral,frame.longitudinal,frame.roll,frame.pitch)).font(.system(.subheadline,design:.monospaced)).accessibilityHidden(running)
        Button("5초 시점 계산만"){running=false;frame=(try? RideMotion.sample(mode,5)) ?? .zero;message="가상 조건의 5초 시점 계산값입니다."}.accessibilityIdentifier("ride-motion-calculate")
        Button(running ? "재생 중지":"흔들림 재생 · 최대 30초"){
            if running{running=false;frame = .zero;message="재생을 중지했습니다."}else if !reduceMotion{running=true;message="가상 모형 재생 중 · 화면을 떠나면 중지합니다."}
        }.disabled(reduceMotion)
        if reduceMotion{Text("동작 줄이기 설정이 켜져 있어 재생하지 않습니다. 계산값만 확인할 수 있습니다.").font(.caption)}
        Text("가정: 주행 약60km/h, 곡선40km/h·반경500m, 감속 초기30km/h·−0.4m/s². 가상 궤도 요철과 감쇠 진동 모형(롤1.1Hz/감쇠비0.38, 피치1.4Hz/0.45)을 사용합니다. 중력9.80665m/s², 곡선 횡가속도 v²/R. 화면 기울기±3°·이동6pt 상한. 승차감·탈선·안전 평가에 사용할 수 없습니다.").font(.caption).foregroundStyle(.secondary)
    }.padding(20)}.navigationTitle("전철 흔들림 실험")
        .task(id:running){guard running else{return};let start=ProcessInfo.processInfo.systemUptime;while !Task.isCancelled,running,!reduceMotion,scene == .active{let elapsed=max(0,min(30,ProcessInfo.processInfo.systemUptime-start));frame=(try? RideMotion.sample(mode,elapsed)) ?? .zero;if elapsed>=30{running=false;message="30초 재생 완료 · 계산값을 유지합니다.";break};try? await Task.sleep(nanoseconds:50_000_000)}}
        .onChange(of:mode){_ in running=false;frame = .zero;message="조건 변경 · 계산·재생은 직접 시작하세요."}
        .onChange(of:reduceMotion){if $0{running=false;frame = .zero}}
        .onChange(of:scene){if $0 != .active{running=false;frame = .zero}}
        .onDisappear{running=false;frame = .zero}
    }
}
