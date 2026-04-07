# RSpec Strategy for suksuk_praise

## 목적
이 문서는 `suksuk_praise`에서 테스트를 어떤 철학과 우선순위로 추가할지 정리한다.

---

## 기본 철학

이 프로젝트의 테스트 목적은 다음과 같다.

- 핵심 기능 변경 시 자신감을 주는 안전망 제공
- 리팩토링 비용 절감
- 권한/정책/상태 전이 규칙 고정
- 수동 클릭 테스트 의존도 감소

Coverage 수치 자체를 목표로 삼지 않는다.

---

## 스타일 원칙

- 읽기 쉬운 테스트를 우선한다.
- 테스트 이름은 동작을 설명하는 문장으로 작성한다.
- guest / authenticated / owner / non-owner 같은 context를 분명히 나눈다.
- 테스트 데이터는 가능한 사용 위치 가까이에 둔다.
- DRY보다 DAMP(설명적이고 의미가 드러나는 테스트)를 우선한다.
- `before`, `let`, `shared_context`, `support`는 필요할 때만 사용한다.

---

## 우선순위

### 1순위
- coupon 발급 규칙
- coupon 사용 규칙
- period duplicate 방지
- weight normalization / invariants
- teacher/admin/student 권한 분기
- 중복 요청/연타 방지
- 핵심 request 흐름

### 2순위
- 서비스 객체 세부 분기
- console helper에 대응되는 도메인 규칙
- Turbo/HTML 이중 응답의 핵심 흐름

### 후순위
- 세세한 뷰 구조
- 자주 바뀌는 마크업
- 스타일/문구 중심 테스트

---

## 권장 테스트 레벨

### model / service spec
- 불변식
- 상태 전이
- 경계값
- 멱등성
- weight 계산/정규화

### request spec
- 인증/인가
- 성공/실패 응답
- 404 / 401 / 409 같은 상태 코드
- create/update/destroy 핵심 흐름
- Turbo / HTML 응답 분기

### system spec
- 로그인 같은 핵심 happy path
- 쿠폰 발급/사용의 대표 브라우저 흐름
- JavaScript/Turbo 통합 문제가 실제로 있었던 부분만 선택적으로

---

## 피해야 할 것

- 구현 세부사항에 과하게 결합된 테스트
- value가 낮은 단순 마크업 고정 테스트
- 중복이 심한 request/system 테스트
- helper/shared_context 남용으로 읽기 어려워진 테스트

---

## 현재 프로젝트에서 먼저 볼 후보

- `CouponDraw::Issue`
- `UserCoupon.issue!`
- `UserCoupon.use!`
- duplicate guard
- period duplicate 판정
- weight balancer
- 권한 정책과 주요 controller request 흐름
