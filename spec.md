# SPEC 3 — Recent Issued Row DOM ID 분리 + Dual Highlight 안전화 (with Effects Cleanup)

## 1. Background

현재 상태:
- `users/show` 화면에서 **보유 쿠폰 리스트**와 **최근 발급 쿠폰 리스트**가 동시에 렌더링된다.
- 두 리스트 모두 row에 `id="<%= dom_id(coupon) %>"`를 사용한다.
  - `app/views/user_coupons/_list.html.erb` → `id="<%= dom_id(c) %>"`
  - `app/views/user_coupons/_issued_coupons.html.erb` → `id="<%= dom_id(coupon) %>"`
- `CouponsHelper#coupon_animation_payload`는 `id: dom_id(coupon)`를 payload로 내려준다.
- `coupon_animation_controller.js`는 `document.getElementById(id)`로 타겟을 찾는다.
- highlight 효과는 `turbo_stream.append "effects"`로 트리거 div를 추가하고, `highlight_controller.js`가 id 기반으로 타겟을 찾는다.

문제:
- 동일한 `UserCoupon`이 **보유 목록(issued)** 과 **최근 발급 목록(issued/used)** 에 동시에 존재할 수 있어,
  한 페이지에 동일 `id`가 **중복**될 수 있다.
- 중복 id가 생기면 하이라이트/애니메이션 타겟이 **다른 목록으로 잘못 매칭**될 위험이 있다.
- `effects` 컨테이너에 append되는 트리거 div가 누적되면(정리/제거 누락 시) DOM이 불필요하게 커질 수 있다.

왜 이 작업이 필요한가:
- DOM id 충돌을 제거하여 하이라이트/애니메이션 타겟 매칭을 **결정적(deterministic)** 으로 만들기 위해.
- (선택 기능) “직접 발급 시 보유/최근발급 양쪽 동시 하이라이트”를 **안전하게** 가능하게 만들기 위해.
- `effects` 트리거가 누적되지 않도록 **자동 정리(cleanup)** 를 보장하기 위해.

---

## 2. Scope (이번 작업 범위)

### 포함

#### A) 최근 발급 리스트 row DOM id 분리
- `app/views/user_coupons/_issued_coupons.html.erb`의 row id를 네임스페이스로 분리한다.
  - 기존: `id="<%= dom_id(coupon) %>"`
  - 변경: `id="<%= dom_id(coupon, :recent) %>"`
- 목적: 보유 쿠폰 row(`dom_id(coupon)`)와 **동일 레코드라도 id가 충돌하지 않도록** 한다.

#### B) (선택) 직접 발급 시 “양쪽 동시 하이라이트” 안전화
- draw_coupon Turbo Stream에서 다음을 만족하면 “양쪽 동시 하이라이트”가 가능해야 한다.
  1) 보유 쿠폰 리스트 하이라이트: 기존처럼 `coupon-animation` payload `id: dom_id(coupon)`를 사용(기존 동작 동일)
  2) 최근 발급 로그 하이라이트: highlight 트리거는 `dom_id(coupon, :recent)`를 사용

> 주: 본 spec에서는 “동시 하이라이트 기능을 반드시 켠다”가 아니라,
> **켜더라도 id 충돌/오작동이 없도록 기반을 만든다**가 목적이다.

#### C) Effects cleanup (append 누적 방지)
- `turbo_stream.append "effects"`로 추가되는 “트리거 엘리먼트”는 **반드시 스스로 제거되도록** 한다.
  - coupon-animation 트리거: 기존처럼 애니메이션 종료/close 후 controller가 element 제거를 보장
  - highlight 트리거: highlight_controller가 타겟 하이라이트를 적용한 뒤 **자기 자신(트리거 div)을 제거**하도록 보장

- cleanup 방식(둘 중 하나로 통일):
  1) **Stimulus가 self-remove**: highlight_controller가 `connect()`에서 하이라이트 적용 후 `this.element.remove()` 수행
  2) **Turbo가 replace/remove**: 트리거에 고정 id를 부여하고 Turbo Stream에서 `remove` 수행

- 본 spec의 기본 권장: (1) Stimulus self-remove (파일/의존성 최소, 기존 패턴과 일관)

### 제외 (이번 작업에서 하지 않을 것)
- UI 레이아웃 변경
- Turbo frame id 변경
- 도메인 로직 변경(status/발급/사용 규칙 등)
- coupon-animation 전체 리팩토링
- Stimulus 남용 정리(대규모) — 별도 후속 작업으로 분리

---

## 3. Constraints (제약 조건)

- 기존 동작 동일 유지 (표시/버튼/갱신 흐름)
- Public interface 변경 금지
- Turbo frame id 유지
  - `dom_id(@user, :coupons)`, `dom_id(@user, :recent_issued_coupons)` 등
- Pundit 정책 구조 유지
- 기존 테스트 깨지지 않아야 함
- ID 분리 규칙은 **최근 발급 리스트에만 국소 적용** (파급 최소화)
- `effects` 트리거는 **누적되지 않도록** cleanup을 보장

---

## 4. Acceptance Criteria (완료 조건)

### DOM id 충돌 제거
- [ ] `users/show` 화면에서 동일 쿠폰이 보유/최근발급 양쪽에 동시에 존재해도 **id 중복이 발생하지 않는다**.
  - 보유 쿠폰 row: `id="user_coupon_123"`
  - 최근 발급 row: `id="recent_user_coupon_123"` (Rails dom_id 규칙에 따른 형태)

### 기존 애니메이션 동작 유지
- [ ] `coupon_animation_payload`는 계속 `id: dom_id(coupon)`를 사용한다(보유 쿠폰 타겟, 기존 동작 동일).
- [ ] `coupon_animation_controller`의 타겟 탐색/하이라이트가 보유 쿠폰 영역에서 기존처럼 정상 동작한다.

### (선택) 동시 하이라이트 안전성
- [ ] (기능을 켰다면) 직접 발급 시 보유 쿠폰과 최근 발급 로그가 각각 **정확한 대상**으로 하이라이트된다.
  - 보유: `dom_id(coupon)`
  - 최근: `dom_id(coupon, :recent)`

### Effects cleanup
- [ ] highlight 트리거 div는 하이라이트 적용 후 **DOM에서 제거되어 누적되지 않는다**.
- [ ] coupon-animation 트리거 div도 애니메이션 종료/close 후 **DOM에서 제거되어 누적되지 않는다**.
- [ ] 반복 사용(여러 번 발급/사용) 후에도 `#effects` 컨테이너 하위에 트리거 div가 지속적으로 쌓이지 않는다.

모든 항목이 충족되면 작업 완료로 간주한다.

---

## 5. Risks / Open Questions

- `dom_id(record, :recent)`의 실제 문자열 형식(접두/접미)은 Rails helper 동작에 따른다. (테스트/브라우저에서 실제 id 확인 필요)
- highlight 트리거가 cleanup을 하지 않으면 effects가 누적된다. 본 spec에서 cleanup을 강제하여 방지한다.
- 기존 코드/테스트가 `#user_coupon_123` selector에 의존하는 경우(희박), 최근 발급 리스트 쪽 selector는 `:recent`로 변경되어야 한다.
