# AGENTS.md — suksuk_praise (쑥쑥칭찬통장) Codex 작업 규칙

## 작업 원칙 (중요)
- Rails way를 최우선으로 따른다. 비표준 접근이 필요하면: (1) 왜 필요한지 (2) Rails way 대안 (3) 트레이드오프를 함께 제시한다.
- "기존 동작 동일"이 최우선이다. 리팩토링은 동작/테스트 유지가 목표다.
- 변경은 항상 git diff로 작고 안전하게 쪼갠다. 한 번에 대규모 변경 금지.
- 먼저 읽고(탐색) → 설계/변경 제안 → 승인 후 수정한다. (바로 수정하지 말 것)
- 테스트/시드/마이그레이션이 얽히면, 먼저 영향 범위를 정리하고 순서를 제안한다.

## 권한/정책 (Pundit)
- 컨트롤러만 authorize/policy_scope를 호출한다.
- 뷰에서는 policy(...) 직접 호출을 피한다.
  - 전역 체크는 helper (예: can_view_coupon_events?)로.
  - 리스트의 per-item 권한은 컨트롤러에서 계산한 ID 목록(@destroyable_ids 등)을 locals로 내려받아 렌더한다.

## 도메인 핵심 규칙 (쿠폰 템플릿)
- personal(bucket=personal): title만 직접 편집 가능.
- personal의 active/weight는 인바리언트로 동기화: weight=0 ⇄ active=false 를 항상 유지.
- library(bucket=library): admin만 생성/수정/비활성/weight 편집 가능.
- personal 세트는 adopt/create/update/toggle_active/destroy 이후 active인 항목들의 weight 합이 100이 되도록 자동 정규화(가장 큰 나머지 방식).

## 커뮤니케이션
- 긴 사전 계획/선언은 쓰지 말고, 필요한 확인/결정 포인트만 간단히 나열한다.
- 코드 변경이 필요하면 반드시:
  1) 바꿀 파일 목록
  2) 위험 포인트
  3) 최소 diff
  4) 검증 방법(rails test/spec/console)을 함께 제시한다.
