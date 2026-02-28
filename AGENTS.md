# AGENTS.md — suksuk_praise (쑥쑥칭찬통장) Codex 작업 규칙

---

## 1. 작업 원칙 (Engineering Principles)

- Rails way를 최우선으로 따른다.
  비표준 접근이 필요하면 반드시:
  (1) 왜 필요한지
  (2) Rails way 대안
  (3) 트레이드오프
  를 함께 제시한다.

- "기존 동작 동일"이 최우선이다.
  리팩토링은 동작/테스트 유지가 목표다.
  Public interface(라우트, 파라미터, 응답 구조)를 변경하지 않는다.

- 변경은 항상 작고 안전한 단위로 나눈다.
  대규모 일괄 변경 금지.

- 기본 브랜치는 `main`이다.
  가능하면 작업 단위별 브랜치를 생성해 작업하고,
  검증/커밋 후 `main`에 머지한다.

- 새로운 패치가 기존 동작을 대체하는 경우,
  이전 구현은 반드시 제거한다.
  Do not introduce parallel implementations.
  조건부 공존(if flag 등)으로 병렬 유지하지 않는다.

- Service 객체는 비즈니스 로직 전용이다.
  컨트롤러는 orchestration(흐름 제어)만 담당한다.

- Turbo Stream 응답은 항상 `layout: "application"`을 유지한다.
  기존 Turbo frame id 명명 규칙을 깨지 않는다.
  Turbo effects/하이라이트는 누적되지 않도록 self-cleanup을 보장한다.

- N+1 쿼리를 방지한다.
  목록/최근 발급 등은 includes/preload를 고려한다.

- 먼저 읽고(탐색) → 설계/변경 제안 → 승인 후 수정한다.
  바로 수정하지 말고 diff로 제시한다.

- 테스트/시드/마이그레이션이 얽히는 경우,
  영향 범위와 적용 순서를 먼저 제안한다.

---

## 2. 권한/정책 (Pundit Rules)

- authorize / policy_scope 호출은 컨트롤러에서만 수행한다.
- 뷰에서 policy(...) 직접 호출을 피한다.

  - 전역 체크는 helper 사용 (예: can_view_coupon_events?)
  - 리스트의 per-item 권한은
    컨트롤러에서 ID 목록(@destroyable_ids 등)을 계산하여
    locals로 내려받아 렌더링한다.

- policy_scope는 항상 명시적으로 호출한다.
  암묵적 접근 금지.

---

## 3. 도메인 핵심 규칙 (Domain Invariants)

### CouponTemplate

- personal(bucket=personal)의 active/weight는 인바리언트로 동기화한다.
  `weight = 0 ⇄ active = false` 를 항상 유지한다.

- library(bucket=library):
  - admin만 생성/수정/비활성화/weight 편집 가능
  - teacher는 adopt만 가능

- 병렬 정책(legacy 규칙 + 신규 규칙 동시 유지)을 만들지 않는다.
  도메인 규칙 변경 시 기존 규칙을 제거한다.

---

## 4. 커뮤니케이션 규칙 (Codex Output Style)

- 긴 사전 선언문은 쓰지 않는다.
- 필요한 확인/결정 포인트만 간단히 제시한다.

코드 변경이 필요한 경우 반드시 다음을 포함한다:

1. 바꿀 파일 목록
2. 위험 포인트
3. 최소 diff
4. 검증 방법 (rails test/spec/console)

불필요한 설명은 생략한다.

---

## 5. spec 기반 작업 규칙 (codex_review workflow)

- `spec.md`는 프로젝트 루트의 SSOT다. 작업 시작 전에 반드시 읽고, 구현은 spec에 맞춰 진행한다.
- 기본 순서는 `pull_spec → 분석 → diff 제시/승인 → 수정 → commit → send_review`를 따른다.
- spec 변경이 필요하면 먼저 제안하고 승인 후 반영한다. (임의로 spec 밖의 기능을 추가하지 않는다.)
- 별도 지시가 없으면 `spec.md`는 커밋에 포함한다.
- 작업 결과는 git 커밋으로 남긴다. 커밋 메시지는 반드시 상세히 작성한다.

### 커밋 메시지 규칙
- 최소 포함 항목:
  - What: 무엇을 변경했는가
  - Why: 왜 변경했는가
  - Risk: 영향/부작용(있다면)
  - Verify: 검증 방법(실행한 테스트/절차)
- 짧은 한 줄 메시지 금지.
- commit message는 한국어 우선.

---
