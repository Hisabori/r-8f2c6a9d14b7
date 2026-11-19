import SwiftUI
import UniformTypeIdentifiers

struct PetJournalDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data:Data) {self.data=data}
    init(configuration:ReadConfiguration)throws {data=configuration.file.regularFileContents ?? Data()}
    func fileWrapper(configuration:WriteConfiguration)throws->FileWrapper {FileWrapper(regularFileWithContents:data)}
}
enum PetJournalData {
    static func report(_ records:[NativePetRecord])throws->Data {
        let encoder=JSONEncoder();encoder.dateEncodingStrategy = .iso8601;encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        struct Report:Encodable {let schema_version=1;let kind="NATIVE_PET_RESEARCH_RECORDS";let notes="짖음 후보와 모델 점수이며 감정·진단·정확도가 아닙니다. 원음은 포함하지 않습니다.";let records:[NativePetRecord]}
        return try encoder.encode(Report(records:records))
    }
    static func days(_ records:[NativePetRecord],calendar:Calendar = .current)->[(Date,Int,Int,Double)] {
        Dictionary(grouping:records,by:{calendar.startOfDay(for:$0.date)}).map { day,rows in
            (day,rows.count,rows.reduce(0){$0+($1.summary?.eventCount ?? 0)},rows.reduce(0){$0+($1.summary?.activeSeconds ?? 0)})
        }.sorted{$0.0>$1.0}
    }
}
struct PetJournalView:View {
    @EnvironmentObject private var store:NativePetStore
    @State private var query=""
    @State private var document=PetJournalDocument(data:Data())
    @State private var exporting=false
    @State private var deleting:NativePetRecord?
    private var filtered:[NativePetRecord] {store.records.prefix(1000).filter{query.isEmpty||($0.name+" "+$0.note).localizedCaseInsensitiveContains(query)}}
    var body:some View {ScrollView{VStack(alignment:.leading,spacing:16){
        NavigationLink("이전 Flutter 기록 가져오기"){LegacyPetImportView()}
        TextField("이름·메모로 기록 검색",text:$query).textFieldStyle(.roundedBorder)
        Text("검색 결과 \(filtered.count)개 · 최근 최대1000건 내 검색").font(.headline)
        Text("일별 합계는 기록별 후보 구간을 더한 값입니다. 중복 녹음·가져오기가 포함될 수 있으며 실제 짖은 횟수나 감정이 아닙니다.").font(.caption).foregroundStyle(.secondary)
        ForEach(Array(PetJournalData.days(filtered).prefix(30).enumerated()),id:\.offset){item in
            let day=item.element
            HStack{Text(day.0.formatted(date:.abbreviated,time:.omitted));Spacer();Text("\(day.1)기록 · 후보 \(day.2)구간 · \(day.3,specifier:"%.1f")초").font(.caption)}.careCard()
        }
        Text("품종 라벨별 기록수 · 직접 선택한 값").font(.headline)
        ForEach(Dictionary(grouping:filtered,by:{$0.breed ?? "품종 모름"}).keys.sorted(),id:\.self){breed in Text("\(breed): \(filtered.filter{($0.breed ?? "품종 모름")==breed}.count)기록").font(.caption)}
        Button("검색된 기록 JSON 내보내기"){do{document=PetJournalDocument(data:try PetJournalData.report(filtered));exporting=true}catch{store.notice="내보내기 자료를 만들지 못했습니다."}}.disabled(filtered.isEmpty)
        ForEach(filtered){record in VStack(alignment:.leading,spacing:10){Text(record.name.isEmpty ? "소리 기록":record.name).font(.headline);Text(record.date.formatted()).font(.caption);Text(record.note);if let url=store.audioURL(record){ShareLink("이 기록 원음 내보내기",item:url)};Button("이 기록 JSON 내보내기"){do{document=PetJournalDocument(data:try PetJournalData.report([record]));exporting=true}catch{store.notice="내보내기 실패"}};Button("기록과 원음 삭제",role:.destructive){deleting=record}.disabled(store.busy||store.recording)}.careCard()}
    }.padding(20)}.background(CareAppearance.background).navigationTitle("반려생활 기록·통계")
        .fileExporter(isPresented:$exporting,document:document,contentType:.json,defaultFilename:"oncare-pet-records"){result in if case .failure = result {store.notice="파일 저장을 완료하지 못했습니다."}}
        .confirmationDialog("선택한 기록과 해당 원음을 삭제할까요?",isPresented:Binding(get:{deleting != nil},set:{if !$0{deleting=nil}}),titleVisibility:.visible){Button("삭제",role:.destructive){if let record=deleting{store.delete(record)};deleting=nil};Button("취소",role:.cancel){deleting=nil}}
    }
}
