1. 유료(프리미엄 계정), 일단 목업으로 설정에서 토글 조절해서 디버그할 수 있게. 그리고 apple appstore, google play 결제 모듈 연동 준비.
지금까지 생각한 유료계정 주요 기능은 힌트-자동메모 무광고 무제한, 복기 기능, 스도쿠 저장(즐겨찾기 기능)이 있어. 유료계정 혜택으로 어떤 기능이 들어가면 좋을지 추천해줘.
2. 복기기능 - 기록에서 최근 10개 스도쿠를 복기할 수 있는 기능(유료계정 전용)
사용자가 메모하거나 숫자를 입력한 순서 복기 가능,'<'  '>' 버튼으로 조작, 복기 중 중간부터 다시 풀기 기능 등
3. race_lobby_screen에서 대결기록은 최근 10개만 보여줌(유료계정은 복기 가능)
4. 스도쿠 저장하기(즐겨찾기) -> 유료계정
5. 앱스토어, 플레이스토어 심사 대비 -로그아웃기능 -계정 삭제기능 -> 과거 경기 기록 익명화, 닉네임은 탈퇴한 사용자, 개인 식별 정보 삭제 -이용약관 -> 서비스 이용 조건, 계정 관리, 부정행위, 랭크 조작, 승부 조작, 비정상적인 매크로 사용, 서비스 이용 제한, 계정 정지, 시즌 랭크 초기화, 시즌 보상, 서비스 종료 등 -스토어 개인정보 입력과 실제 앱 일치 -심사용 테스트 계정

6. 로그인
7. 대전 메뉴 진입
8. 랭크 게임 진입
9. Daily Sudoku 확인

같은 설명을 심사 제출 정보에 작성합니다.

랭크 게임 시작

↓

매칭 상대 없음

↓

테스트 불가능
따라서 심사용 테스트 계정 + 테스트 매칭 환경을 준비하는 것이 좋습니다.

-심사 전 체크리스트
[ ] Google 로그인 정상 작동
[ ] Apple 로그인 정상 작동
[ ] Apple Private Relay 이메일 처리
[ ] 계정 삭제 가능
[ ] 로그아웃 가능
[ ] 개인정보처리방침
[ ] 이용약관
[ ] 문의 방법
[ ] 신고/차단 정책
[ ] 실시간 대전 정상 작동
[ ] 친구 대전 정상 작동
[ ] 랭크 게임 정상 작동
[ ] 시즌 정보 표시
[ ] 시즌 종료 처리
[ ] 리더보드 정상 작동
[ ] 시즌 보상 정상 작동
[ ] 중복 보상 방지
[ ] 앱 크래시 없음
[ ] 오프라인 상태 처리
[ ] 네트워크 끊김 처리
[ ] 서버 오류 처리
[ ] 테스트 계정 준비
[ ] 심사자가 대전 기능 테스트 가능
[ ] 개인정보 수집 정보 일치
[ ] Google Play Data Safety 작성
[ ] App Store Privacy 작성
[ ] 앱 아이콘
[ ] 스플래시
[ ] 스크린샷
[ ] 앱 설명
[ ] 연령 등급

전체 계획 (items 1–4 + 선택 혜택)
Phase 1 — 프리미엄 인프라 (목업 + 게이팅)
목표: PremiumController.isPremium 하나가 모든 게이팅을 좌우하고, 디버그 토글로 on/off.

신규 premium_controller.dart — ChangeNotifier, isPremium, setMockPremium(). auth처럼 main()에서 생성해 내려줌.
신규 purchase_service.dart — IAP 대비 추상 인터페이스 + MockPurchaseService(저장 플래그 반환). 실제 패키지는 미도입.
storage_service.dart에 premium_mock 저장/로드.
settings_sheet.dart에 kDebugMode에서만 보이는 "프리미엄(디버그)" 스위치.
게이팅: game_screen.dart의 리워드 광고 3곳(힌트/자동메모/부활) → isPremium이면 광고 스킵하고 즉시 실행.
검증: 토글 ON→광고 없이 힌트 동작 / OFF→기존 광고 흐름 유지 (+컨트롤러 단위 테스트).
Phase 2 — 복기 기반: 이벤트 레코더 + 로컬 저장 (싱글)
목표: 완료된 싱글 게임의 입력·메모 순서를 이벤트 로그로 저장(유형별 최근 30개), 임의 시점 복원 가능.

신규 models/game_replay.dart — GameEvent{order,type,row,col,value,elapsed} + GameReplay{puzzle, events, 결과메타, finishedAt}.
game_controller.dart: _history.add가 일어나는 지점마다 이벤트 1개 기록(되돌리기 시 함께 pop → 1:1 정합성). eventLog 노출.
storage_service.dart: saveReplay(30개 초과 시 오래된 것 제거)/loadReplays.
훅: game_screen.dart _onWin/게임오버에서 저장.
검증: 스크립트 수순 → 저장 → 로드 후 순서 일치, N단계 보드 복원 == 기대값 (단위 테스트).
Phase 3 — 복기 UI + 기록 목록 (싱글)
목표: 최근 30개 목록 + < > 재생 + "여기서부터 풀기".

신규 screens/replay/replay_list_screen.dart (프리미엄 게이트/업셀), replay_player_screen.dart(이벤트 0~i 적용→읽기전용 보드, 단계 이동, "여기서부터 풀기"→GameSnapshot 복원 후 GameScreen.resume).
진입점: stats_screen.dart("기록")에 복기 섹션.
검증: 완료→목록→재생→중간부터 이어풀기 정상.
Phase 4 — 대전 기록 30개 제한 + 대전 복기
race_service.dart fetchHistory에 .limit(30).
대전도 동일 레코더로 raceId 키 로컬 저장, race_lobby_screen.dart 기록에 프리미엄 복기 버튼(로컬 기록 있는 경기만).
검증: 대전 완료→복기 가능, 목록 30개 제한.
Phase 5 — 즐겨찾기 저장
퍼즐 저장(로컬) + screens/favorites/favorites_screen.dart + result_screen.dart의 "저장" 버튼(프리미엄). 저장한 퍼즐은 새 게임으로 다시 풀기.
검증: 저장→목록→새로 풀기.
Phase 6 — 선택 혜택 (프리미엄 테마/보드 스킨 + 심화 통계) (별도 설계 후 확정)
유료 테마·보드 스킨, HumanSolver 기반 심화 통계. 구체 스킨/지표는 착수 전 다시 상의.
각 Phase의 사용자 노출 문구는 ko/en ARB 추가 후 재생성이 필요합니다.


Phase 6A — 프리미엄 테마 팩
아키텍처 (회귀 위험 최소화)

ThemePack 정의: 팩마다 핵심 색만 라이트/다크로 보유 — 앱(강조색·배경 그라데이션·버튼 그라데이션·ColorScheme seed) + 보드 구조색(셀 배경·선택/이웃·테두리·숫자색·패드/컨트롤). 힌트 의미색(빨강·초록·청록·주황)은 팩 무관 고정.
현재 하드코딩 값을 그대로 Classic 팩으로 추출 → BoardColors/AppPalette/app_theme가 "활성 팩"을 읽도록 위임. 클래식 = 지금과 픽셀 동일(안전).
SettingsController에 활성 팩 상태 추가(로컬 저장). 변경 시 앱 리빌드로 반영(테마모드와 동일 패턴). 라이트/다크 토글과 직교(팩은 각 모드용 색을 가짐).
팩 라인업 (제안)

Classic (무료) — 현재 바이올렛+시안.
Midnight Neon (프리미엄) — 딥 네이비 배경 + 네온 청록/자홍 강조.
Sepia Paper (프리미엄) — 따뜻한 크림/브라운, 종이 느낌.
선택 UI / 게이팅

설정 시트 "테마" 섹션에 팩 선택(각 팩 미니 미리보기 칩). 비프리미엄은 프리미엄 팩에 잠금 표시 → 탭 시 PremiumLockScreen(description=테마 설명).
비프리미엄은 Classic만 적용 가능.
작업 범위: models/theme_pack.dart(신규) · board_colors.dart/app_palette.dart/app_theme.dart 위임 리팩터 · settings_controller+storage 활성팩 · settings_sheet 선택 UI · l10n(팩 이름·설명). 회귀 검증 위해 클래식 픽셀 동일 확인.
