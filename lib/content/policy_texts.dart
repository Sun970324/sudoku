/// Static legal texts shown by PolicyScreen. Kept as Dart constants rather
/// than ARB entries: these are long multi-paragraph documents that would
/// bloat the l10n files and churn generated code on every wording tweak.
///
/// NOTE: these are working drafts written to match what the app actually
/// does (AdMob ads, Supabase auth/profiles/race/daily records, local
/// SharedPreferences saves). They are not legal advice — review before
/// store submission.
library;

const privacyPolicyKo = '''
개인정보처리방침

시행일: 2026년 7월 18일

본 앱(이하 "앱")은 이용자의 개인정보를 중요하게 생각하며, 관련 법령을 준수합니다. 본 방침은 앱이 어떤 정보를 수집하고 어떻게 이용하는지 설명합니다.

1. 수집하는 정보

(1) 계정 정보
- Google 또는 Apple 계정으로 로그인하는 경우: 해당 서비스가 제공하는 계정 식별자, 이메일 주소
- 게스트로 시작하는 경우: 익명 계정 식별자
- 앱 내에서 설정한 닉네임

(2) 게임 기록
- 실시간 대결 기록(승패, 레이팅, 상대방, 대결 시각)
- 데일리 스도쿠 완료 기록(완료 시각, 소요 시간, 실수 횟수, 힌트 사용 횟수)

(3) 광고 관련 정보
- 앱은 Google AdMob을 통해 광고를 표시합니다. AdMob은 광고 제공을 위해 광고 식별자(ADID/IDFA) 등 기기 정보를 수집할 수 있습니다. 자세한 내용은 Google 개인정보처리방침(https://policies.google.com/privacy)을 참고하세요.

(4) 기기 내 저장 정보
- 게임 진행 상태, 난이도별 통계, 설정(테마·언어·사운드 등)은 서버로 전송되지 않고 이용자의 기기에만 저장됩니다.

2. 정보의 이용 목적
- 계정 관리 및 로그인 유지
- 실시간 대결 매칭, 레이팅·티어 산정, 대결 기록 제공
- 데일리 스도쿠 순위표 제공
- 광고 표시

3. 정보의 보관 및 파기
- 계정 정보와 게임 기록은 서비스 제공 기간 동안 보관되며, 계정 삭제 요청 시 지체 없이 파기됩니다.
- 기기 내 저장 정보는 앱 삭제 시 함께 삭제됩니다.

4. 제3자 제공
- 앱은 법령에 따른 경우를 제외하고 이용자의 개인정보를 제3자에게 제공하지 않습니다.
- 서비스 운영을 위해 다음 처리위탁이 이루어집니다: Supabase(계정·게임 기록 저장), Google AdMob(광고).

5. 이용자의 권리
- 이용자는 언제든지 계정 삭제 및 개인정보 파기를 요청할 수 있습니다. 아래 문의처로 연락해 주세요.

6. 문의처
- 이메일: ysw5202222@gmail.com

본 방침은 변경될 수 있으며, 변경 시 앱 내에 공지합니다.
''';

const privacyPolicyEn = '''
Privacy Policy

Effective date: July 18, 2026

This app respects your privacy and complies with applicable laws. This policy explains what information the app collects and how it is used.

1. Information We Collect

(1) Account information
- When signing in with Google or Apple: the account identifier and email address provided by that service
- When starting as a guest: an anonymous account identifier
- The nickname you set in the app

(2) Game records
- Real-time race records (results, rating, opponent, time of match)
- Daily sudoku completion records (completion time, elapsed time, mistakes, hints used)

(3) Advertising
- The app shows ads through Google AdMob. AdMob may collect device information such as advertising identifiers (ADID/IDFA) to serve ads. See Google's Privacy Policy (https://policies.google.com/privacy) for details.

(4) On-device data
- Game progress, per-difficulty statistics, and settings (theme, language, sound, etc.) are stored only on your device and are never sent to our servers.

2. How We Use Information
- Account management and sign-in
- Real-time race matchmaking, rating/tier calculation, and race history
- Daily sudoku leaderboards
- Serving ads

3. Retention and Deletion
- Account information and game records are kept while the service is provided and deleted promptly upon an account deletion request.
- On-device data is removed when the app is uninstalled.

4. Third Parties
- We do not share your personal information with third parties except as required by law.
- The following processors are used to operate the service: Supabase (account and game record storage), Google AdMob (advertising).

5. Your Rights
- You may request account deletion and erasure of your personal information at any time via the contact below.

6. Contact
- Email: ysw5202222@gmail.com

This policy may change; changes will be announced in the app.
''';

const termsOfServiceKo = '''
이용약관

시행일: 2026년 7월 18일

제1조 (목적)
본 약관은 본 앱(이하 "앱")이 제공하는 스도쿠 게임 및 관련 서비스의 이용 조건을 정합니다. 앱을 이용함으로써 본 약관에 동의한 것으로 봅니다.

제2조 (서비스 내용)
앱은 다음 서비스를 제공합니다.
- 스도쿠 퍼즐 플레이 및 힌트 기능
- 실시간 대결(랭크전·친선전) 및 레이팅·티어 시스템
- 데일리 스도쿠 및 순위표
- 퍼즐 공유 코드

제3조 (계정)
1. 일부 기능(대결, 데일리 스도쿠)은 로그인이 필요합니다.
2. 이용자는 자신의 계정을 타인에게 양도할 수 없습니다.
3. 게스트 계정은 기기 변경·앱 삭제 시 복구되지 않을 수 있습니다. 기록을 유지하려면 계정 연동을 이용하세요.

제4조 (이용자의 의무)
이용자는 다음 행위를 해서는 안 됩니다.
- 비정상적인 방법으로 레이팅·순위를 조작하는 행위
- 서비스의 정상적인 운영을 방해하는 행위
- 타인에게 불쾌감을 주는 닉네임 사용

제5조 (서비스 변경 및 중단)
운영자는 서비스의 전부 또는 일부를 변경하거나 중단할 수 있습니다. 중요한 변경은 앱 내에 공지합니다.

제6조 (면책)
1. 앱은 "있는 그대로" 제공되며, 운영자는 서비스의 완전성·정확성을 보증하지 않습니다.
2. 천재지변, 통신 장애 등 불가항력으로 인한 손해에 대해 운영자는 책임지지 않습니다.

제7조 (광고)
앱에는 광고가 표시될 수 있으며, 일부 기능(힌트, 이어하기 등)은 광고 시청과 연계될 수 있습니다.

제8조 (문의)
서비스 관련 문의: ysw5202222@gmail.com

본 약관은 변경될 수 있으며, 변경 시 앱 내에 공지합니다.
''';

const termsOfServiceEn = '''
Terms of Service

Effective date: July 18, 2026

Article 1 (Purpose)
These terms govern your use of the sudoku game and related services provided by this app. By using the app you agree to these terms.

Article 2 (Services)
The app provides:
- Sudoku play and hint features
- Real-time races (ranked and friendly) with a rating/tier system
- Daily sudoku and leaderboards
- Puzzle share codes

Article 3 (Accounts)
1. Some features (races, daily sudoku) require signing in.
2. You may not transfer your account to another person.
3. A guest account may not be recoverable after changing devices or uninstalling the app. Link an account to keep your records.

Article 4 (User Obligations)
You must not:
- Manipulate ratings or rankings through abnormal means
- Interfere with the normal operation of the service
- Use nicknames that are offensive to others

Article 5 (Changes to the Service)
The operator may change or discontinue all or part of the service. Significant changes will be announced in the app.

Article 6 (Disclaimer)
1. The app is provided "as is"; the operator does not guarantee its completeness or accuracy.
2. The operator is not liable for damages caused by force majeure such as natural disasters or network failures.

Article 7 (Advertising)
The app may display ads, and some features (hints, continue, etc.) may be tied to watching ads.

Article 8 (Contact)
Service inquiries: ysw5202222@gmail.com

These terms may change; changes will be announced in the app.
''';
