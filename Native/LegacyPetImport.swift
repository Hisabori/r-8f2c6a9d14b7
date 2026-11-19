import SwiftUI
import CryptoKit
import UniformTypeIdentifiers

struct LegacyPetRecord:Codable,Identifiable {
    let id:String,name:String,breed:String,date:String,note:String,original:Data
}
enum LegacyPetImport {
    static func parse(_ data:Data)throws->[LegacyPetRecord] {
        guard data.count<=1_048_576,let rows=try JSONSerialization.jsonObject(with:data) as? [[String:Any]],rows.count<=500 else{throw PetSoundError.invalidAudio}
        var seen=Set<String>()
        return try rows.compactMap{row -> LegacyPetRecord? in
            guard let date=row["date"] as? String,!date.isEmpty,date.count<=100 else{throw PetSoundError.invalidAudio}
            let original=try JSONSerialization.data(withJSONObject:row,options:[.sortedKeys]);let id=SHA256.hash(data:original).map{String(format:"%02x",$0)}.joined()
            guard seen.insert(id).inserted else{return nil}
            return LegacyPetRecord(id:id,name:String((row["dog"] as? String ?? row["name"] as? String ?? "이전 소리 기록").prefix(100)),breed:String((row["breed"] as? String ?? "unknown").prefix(100)),date:date,note:String((row["note"] as? String ?? "").prefix(2000)),original:original)
        }
    }
    static func merge(_ existing:[LegacyPetRecord],_ incoming:[LegacyPetRecord])throws->[LegacyPetRecord] {
        var ids=Set(existing.map(\.id));var result=existing
        for row in incoming where ids.insert(row.id).inserted{result.append(row)}
        guard result.count<=1000 else{throw PetSoundError.invalidAudio};return result
    }
}
struct LegacyPetImportView:View {
    @State private var records:[LegacyPetRecord]=[]
    @State private var preview:[LegacyPetRecord]=[]
    @State private var message="기존 Flutter history.json의 메타데이터를 미리 보고 가져옵니다. 원음과 기존 폴더를 자동 이동·삭제하지 않습니다."
    @State private var importing=false
    @State private var busy=false
    @State private var healthy=true
    @State private var exporting=false
    @State private var document=PetJournalDocument(data:Data())
    private var file:URL{FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("native-pet/legacy-history.json")}
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:16){
        Text("이전 반려생활 기록 가져오기").font(.title2.bold())
        Text(message).font(.subheadline)
        Text("최대1MB·500건씩 가져오기, 총1000건. 동일 원본 내용은 중복 제외합니다. 이전 점수·감정·품종은 가져온 기록의 원문이며 새 모델 추론이나 검증된 감정/품종 판정이 아닙니다.").font(.caption).foregroundStyle(.secondary)
        Button("기존 history.json 선택"){importing=true}.disabled(busy || !healthy)
        if busy{ProgressView()}
        if !preview.isEmpty{Text("미리보기 \(preview.count)건").font(.headline);ForEach(Array(preview.prefix(5))){row in Text(row.name+" · "+row.breed+"\n"+row.date).font(.caption)};Button("중복을 제외하고 가져오기"){save()}.disabled(!healthy);Button("미리보기 취소"){preview=[]}}
        Button("이전 기록 원문 JSON 내보내기"){do{let objects=try records.map{try JSONSerialization.jsonObject(with:$0.original)};document=PetJournalDocument(data:try JSONSerialization.data(withJSONObject:objects,options:[.prettyPrinted,.sortedKeys]));exporting=true}catch{message="내보내기 자료 오류"}}.disabled(records.isEmpty)
        Text("가져온 이전 기록 \(records.count)개").font(.headline)
        ForEach(Array(records.suffix(100).reversed())){row in VStack(alignment:.leading,spacing:6){Text(row.name).font(.headline);Text(row.date+" · "+row.breed).font(.caption);Text(row.note);Text("이전 앱 메타데이터 · 원음은 파일 가져오기로 따로 분석하세요.").font(.caption2).foregroundStyle(.secondary)}.careCard()}
    }.padding(20)}.navigationTitle("이전 기록 이관")
        .task{do{if FileManager.default.fileExists(atPath:file.path){guard (try file.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)<=2_097_152 else{throw PetSoundError.invalidAudio};records=try JSONDecoder().decode([LegacyPetRecord].self,from:Data(contentsOf:file))}}catch{healthy=false;message="기존 이관 기록을 읽지 못했습니다. 원본 보존을 위해 저장을 중지합니다."}}
        .fileImporter(isPresented:$importing,allowedContentTypes:[.json]){result in switch result{case .success(let url):busy=true;Task{do{let rows=try await Task.detached{let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}};let handle=try FileHandle(forReadingFrom:url);defer{try? handle.close()};return try LegacyPetImport.parse(handle.read(upToCount:1_048_577) ?? Data())}.value;preview=rows;message="미리보기만 읽었습니다. 가져오기 버튼을 눌러 저장하세요."}catch{preview=[];message="형식·크기·날짜 필드를 확인하세요. 기존 기록은 유지합니다."};busy=false};case .failure:message="파일 선택을 완료하지 못했습니다."}}
        .fileExporter(isPresented:$exporting,document:document,contentType:.json,defaultFilename:"oncare-legacy-pet-history"){_ in}
    }
    private func save(){guard healthy,!busy else{return};do{let merged=try LegacyPetImport.merge(records,preview);try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true);let data=try JSONEncoder().encode(merged);guard data.count<=2_097_152 else{throw PetSoundError.invalidAudio};try data.write(to:file,options:[.atomic,.completeFileProtection]);message="\(merged.count-records.count)개를 추가했습니다. 원본 파일·원음은 변경하지 않았습니다.";records=merged;preview=[]}catch{message="가져오기를 저장하지 못했습니다. 기존 파일은 보존합니다."}}
}
