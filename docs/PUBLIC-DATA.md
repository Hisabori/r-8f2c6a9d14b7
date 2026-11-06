# 공공교통 정보 (iOS 0.4.11)

이동 준비 > 공공교통에서 서울시 지하철 도착정보와 서울교통공사의 30분 평균 혼잡도를 확인합니다. 건강·음성·거래 API와 연결하지 않습니다. 이동시간·출발 알림은 별도 기존 계산을 유지합니다.

## 실시간 도착 API
- 출처/키 발급: https://data.seoul.go.kr/dataList/OA-12764/A/1/datasetView.do (서울시 TOPIS, 공공누리 1유형)
- HTTPS swopenapi.seoul.go.kr/api/subway/{KEY}/json/realtimeStationArrival/0/100/{역명}
- 키는 화면 메모리에만 보관, 나갈 때 삭제. 키·응답·URL을 로그에 남기지 않습니다. 역 이름은 서울시에 전송됩니다.
- 사용자 조회에만 요청, 15초 간격, 20초 자원 timeout, 2MB/100행 상한, 리다이렉트 금지. HTTP로 다운그레이드하지 않습니다.
- 생성시각 recptnDt를 KST로 파싱, -30~120초 이내만 표시. 15초 간격으로 만료 표시. 수신시각과 생성시각을 분리합니다.
- 실제 키와 HTTPS 제공자 연결은 검증하지 않았습니다. API 권한/제공자 HTTPS 문제 시 오류만 표시하고 이동 계획을 유지합니다.

## 평균 혼잡도
- 출처: https://www.data.go.kr/data/15071311/fileData.do
- 기존 앱에 포함된 서울교통공사 2026-06-30 자료를 그대로 복사한 정적 JSON입니다. 원본 출처/hash/asOf 메타데이터를 보존했습니다. 최신 API 값이 아닙니다.
- 한국시간 평일/토요일/일요일과 해당 30분 열을 정확히 선택합니다. 공휴일 자동 판별·실시간 객차 예측을 하지 않습니다. 자료가 없는 구간은 빈 결과입니다.

## 검증
`python3 tool/verify_native.py`와 GitHub native-ios.yml에서 기기 빌드, PublicTransitTests 및 키 없는 탐색 UI 테스트를 실행합니다. API 인증 실패/오래된 값/미래 시각/다른 역/크기 상한/KST 시간대를 fixture로 검증합니다. 실기기, 운영 키, 실제 열차 도착 정확도는 별도 검증입니다.
