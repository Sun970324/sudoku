# Sudoku League — 정책 문서

이 저장소는 앱의 **공개 정책 문서만** 담고 있습니다. GitHub Pages로 게시되며,
Google Play와 App Store의 스토어 등록 정보가 아래 주소를 가리킵니다.

- 개인정보처리방침 — <https://sun970324.github.io/sudoku/privacy.html>
- 이용약관 — <https://sun970324.github.io/sudoku/terms.html>
- 계정 및 데이터 삭제 안내 — <https://sun970324.github.io/sudoku/data-deletion.html>

앱 소스 코드는 비공개 저장소에 있습니다.

## `docs/`를 직접 고치지 마세요

이 HTML은 손으로 쓴 문서가 아니라 **렌더링 결과물**입니다. 원본은 앱 저장소의
`lib/content/policy_texts.dart`이고, `tool/generate_policy_pages.dart`가 그것을
`docs/*.html`로 옮깁니다.

여기서 직접 고치면 두 가지가 어긋납니다. 다음 렌더링 때 덮어써져 수정이
사라지고, 그 전까지는 **앱 안에 표시되는 문구와 게시된 문구가 서로 다른 말을
하게 됩니다.** 앱이 하는 일과 정책이 다르다는 것은 스토어 심사에서 그대로
문제가 됩니다.

정책을 바꾸는 절차는 앱 저장소 쪽에 있습니다: `policy_texts.dart`를 고치고,
생성기를 돌리고, 나온 `docs/`를 이 저장소의 `main`에 밀어야 게시본이 갱신됩니다.
미는 것을 잊으면 앱만 바뀌고 공개 정책은 옛날 말을 계속합니다.

## Pages 설정

`main` 브랜치의 `/docs` 폴더에서 게시됩니다. 이 설정과 저장소 이름(`sudoku`)이
곧 URL이므로, 둘 중 무엇을 바꿔도 스토어에 등록된 주소가 죽습니다.
