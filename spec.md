# SPEC — Coupon Recent Issued Highlight & Turbo Consistency

## 1. Background

현재 상태:
- 쿠폰 발급(draw_coupon) 시 Turbo Stream으로 최근 발급 쿠폰 프레임이 갱신된다.
- 쿠폰 사용(use) 시 보유 쿠폰과 KPI는 갱신되지만, 최근 발급 쿠폰 프레임은 갱신되지 않는다.
- 최근 발급 쿠폰 리스트의 각 row는 `<li id="<%= dom_id(coupon) %>">` 구조를 가진다.
- `highlight_controller`가 이미 존재하며, 특정 DOM id를 받아 시각적 강조를 수행한다.
- 효과 트리거는 `turbo_stream.append "effects"` 패턴을 사용한다.

문제:
- 쿠폰 사용 시 최근 발급 쿠폰 리스트에 "사용함" 배지가 즉시 반영되지 않는다.
- 발급/사용 이벤트가 로그 리스트에서 시각적으로 구분되지 않는다.

왜 이 작업이 필요한가:
- UI 상태 일관성 유지 (발급/사용 후 즉시 반영)
- 사용자 피드백 강화 (로그 강조 효과)
- 기존 Turbo + Stimulus 패턴을 유지하면서 기능 확장

---

## 2. Scope (이번 작업 범위)

### 포함
- `user_coupons/use.turbo_stream.erb`에 최근 발급 쿠폰 프레임 update 추가
- 쿠폰 사용 후 "사용함" 배지가 즉시 반영되도록 partial 재렌더링
- 발급(draw_coupon) 및 사용(use) 시 최근 발급 리스트 row에 highlight 효과 추가
- 기존 `highlight_controller` 재사용
- highlight 트리거는 `turbo_stream.append "effects"` 방식 사용

### 제외 (이번 작업에서 하지 않을 것)
- UI 레이아웃 변경
- CSS 구조 리팩토링
- Stimulus 전면 재구성
- 도메인 로직 변경 (status, weight 등)

---

## 3. Constraints (제약 조건)

- 기존 동작 동일 유지
- Public interface 변경 금지
- Turbo frame id 유지 (`dom_id(@user, :recent_issued_coupons)`)
- Pundit 정책 구조 유지
- 기존 테스트 깨지지 않아야 함
- 하이라이트는 상태 로직을 JS에 위임하지 않는다 (UI 효과만 수행)

---

## 4. Acceptance Criteria (완료 조건)

- [ ] 쿠폰 사용 후 최근 발급 쿠폰 프레임이 Turbo로 갱신된다.
- [ ] 쿠폰 사용 시 "사용함" 배지가 즉시 표시된다.
- [ ] 쿠폰 발급 시 해당 row가 1초간 highlight 된다.
- [ ] 쿠폰 사용 시 해당 row가 1초간 highlight 된다.
- [ ] highlight는 기존 `highlight_controller`를 통해 수행된다.
- [ ] Turbo Stream 순서로 인해 highlight 대상 element가 존재하지 않는 레이스 컨디션이 발생하지 않는다.

모든 항목이 충족되면 작업 완료로 간주한다.

---

## 5. Risks / Open Questions

- Turbo Stream 실행 순서에 따라 highlight 트리거가 DOM 업데이트보다 먼저 실행될 가능성은 없는가?
- 최근 발급 리스트 데이터가 컨트롤러에서 항상 최신 상태로 재계산되는가?
- 모바일/데스크탑 공통 partial 구조에서 DOM id 충돌 가능성은 없는가?
