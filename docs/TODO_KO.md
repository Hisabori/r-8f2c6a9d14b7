# 다음 구현 단계와 검증 기준

1. 네이티브 리포트 뷰어 확장: trades/equity_curve를 별도 목록·차트로 표시. 원본 JSON 불변, null/결측 보존, 최대 크기와 파일 형식 오류 테스트.
2. 모바일 백테스트 엔진 포팅: 기존 crypto_v15 Python을 기준으로 독립 코어를 만들고 동일 고정 fixture의 거래 수·총자산·비용을 대조. next-open 상태 시점, entry-bar 청산, 최종 곡선의 알려진 한계는 수정 전후 엔진 버전을 구분. 기존 v1.1 필드/미지 키 삭제 금지. 현재 모바일에 구현됐다고 보고 금지.
3. v1.7 CVD/호가 불균형 신호: raw/agg trade 중복 제거, aggressor side/base 수량, sequence gap/rebuild, exchange event와 received 시각 구분. received<=decision의 데이터만 사용. book invalid/stale일 때 신호 unavailable. 실제 주문 연결 금지. synthetic fixture는 명시적 테스트 전용.
4. 유동성 증발 시뮬레이션: opt-in 시나리오별 depth 감소, spread 확대, latency/participation/partial-fill/reject/cancel-simulation을 분리. OHLCV로 실제 호가를 추정해 채우지 말 것. 신규 진입 중지와 잔여 포지션 처리 정책 분리. 원본 v1.6 기본 결과 불변 회귀 및 원인별 비용 리포트 필요.
5. 실물 기기 검증: Android8/15+와 iOS16/26, 글자 확대, 회전, 네트워크 단절/복구, 백그라운드 복귀, 공유창 취소, malformed JSON, 환율 휴일/노후화, 알림 재무장/쿨다운 확인. 어떤 단계도 실제 거래 또는 수익성 검증으로 표현하지 말 것.
