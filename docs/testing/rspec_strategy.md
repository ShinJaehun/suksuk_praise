# RSpec Strategy for suksuk_praise

## 목적

이 문서는 `suksuk_praise`에서 RSpec 테스트를 어떤 철학과 우선순위로 추가할지 정리한다.
Codex가 이후 테스트 코드를 작성하거나 테스트 공백을 제안할 때도 이 문서를 기준으로 삼는다.

테스트의 목적은 coverage 수치가 아니라 핵심 기능 변경 시 confidence를 주는 안전망이다.
권한, 상태 전이, 멱등성, 정책, 주요 request 흐름을 고정하고,
수동 브라우저 테스트 의존도를 줄이는 데 집중한다.

---

## 스타일 원칙

- readable > clever.
- DRY보다 DAMP를 우선한다. 테스트는 조금 반복되더라도 의도가 드러나야 한다.
- 테스트 이름은 사용자의 행동이나 도메인 규칙을 문장으로 설명한다.
- context는 역할별로 명확히 나눈다: guest / admin / teacher / student.
- 테스트 데이터는 가능한 사용 위치 가까이에 둔다.
- 과도한 `shared_context`, helper, abstraction 남용을 피한다.
- brittle한 HTML 구조, Tailwind class, 세부 DOM 배치 고정 테스트를 지양한다.
- request spec은 핵심 텍스트, redirect, status, 데이터 변화, 권한 차단을 중심으로 검증한다.
- system spec은 정말 필요한 happy path에만 제한적으로 사용한다.

---

## 우선순위 1

현재 구현된 핵심 기능과 정책 기준으로 먼저 고정할 테스트 영역이다.

### 인증/로그인 흐름

- teacher/admin Devise 로그인.
- student PIN 로그인.
- student canonical path: `classrooms/:classroom_id/students/:id`.
- student가 `/users/:id`에 접근할 때 가능한 경우 classroom-scoped path로 redirect.
- 공유 태블릿 환경에서 학생 세션과 로그아웃 흐름.

### 역할/권한

- admin / teacher / student 권한 분기.
- Pundit policy와 policy_scope 핵심 분기.
- 교실 membership 기준 접근 제한.
- 학생이 다른 학생 데이터에 접근하지 못하는 경계.

### classroom/student 관리

- 교실 생성/수정.
- 학생 생성/수정/삭제.
- 학생 gender/avatar_key 관리.
- 교실 내 avatar_key 중복 회피 규칙.
- 학생 self-edit 차단.
- 학생이 직접 변경할 수 있는 것은 PIN뿐이라는 정책.

### compliment

- compliment 생성.
- 중복/연타 guard.
- classroom scope와 timeline 노출.
- giver/receiver 권한 경계.

### coupon

- coupon template library/personal 정책.
- weight normalization.
- coupon issue/draw/use.
- period duplicate guard.
- recent issued coupon / owned coupon 흐름.
- teacher/admin/student 권한 경계.

### message

- `student_initiated_messages_enabled` 기본값 false.
- 설정 true일 때만 student root message 생성 가능.
- 설정 false일 때 student root message 생성 차단.
- 기존 root thread reply는 설정값과 무관하게 권한 기준으로 허용.
- root thread마다 reply form을 제공하는 정책.
- 답글의 답글 금지.
- teacher/admin managed reply.
- message card order와 student canonical page 흐름.

### Turbo/HTML 응답

- 핵심 create/update/destroy의 Turbo 성공/실패 흐름.
- HTML fallback의 redirect/status/alert 흐름.
- validation failure 시 부분 갱신이 깨지지 않는지 확인.

---

## 우선순위 2

1순위보다 변화 가능성이 있거나, 주요 정책이 안정된 뒤 보강할 영역이다.

- seeds/demo data 안전성.
- locale이 개입되는 핵심 사용자 메시지.
- dashboard/navbar notification 후보.
- classroom settings 조합.
- admin reporting 기반 데이터.
- 여러 classroom membership 조합.
- Turbo Stream 세부 실패 케이스 중 실제 회귀 위험이 있는 것.

---

## 후순위

아래 항목은 테스트로 강하게 고정하기 전에 정책 안정성을 먼저 확인한다.

- 세세한 view 구조.
- Tailwind class.
- 자주 바뀌는 문구.
- 너무 세밀한 DOM 순서.
- 아직 정책이 확정되지 않은 notification 세부 구조.
- avatar 직접 업로드 커스터마이징.
- visual polish만을 위한 UI 차이.

---

## 테스트 레벨

### model / service spec

도메인 불변식과 상태 전이를 고정할 때 우선 사용한다.

- 도메인 불변식.
- 상태 전이.
- 중복 방지.
- 경계값.
- weight normalization.
- `UserMessage` validation.
- `UserCoupon` issue/use.
- coupon duplicate/period guard.

### policy spec

역할과 scope의 경계를 고정할 때 우선 사용한다.

- role별 허용/금지.
- policy_scope.
- student/teacher/admin 경계.
- classroom membership 기반 접근 제한.
- 학생 self-service 제한.

### request spec

사용자 흐름과 controller 권한을 고정할 때 우선 사용한다.

- 인증/인가.
- redirect.
- status code.
- create/update/destroy.
- Turbo/HTML 분기.
- canonical landing path.
- 권한 없는 요청의 차단.
- 핵심 데이터 변화.

### system spec

정말 필요한 happy path만 후보로 둔다.

- PIN 로그인 후 학생 포털 확인.
- 교사 coupon issue/use 대표 흐름.
- 메시지 대표 흐름.
- JavaScript/Turbo 통합 문제가 실제로 있었던 흐름.

---

## 현재 단계 테스트 보강 순서

### Step 1

- student PIN login.
- canonical redirect.
- student self-edit 차단.
- classroom student management.
- student avatar/gender.

### Step 2

- `UserMessage` 정책.
- `student_initiated_messages_enabled`.
- root/reply thread 권한.
- classroom student show 카드 흐름.

### Step 3

- coupon issue/use/duplicate/period guard.
- coupon template weight normalization.
- library/personal template 정책.

### Step 4

- compliment create/throttle/scope.
- compliment timeline.

### Step 5

- policy/scope 누락분.
- Turbo response 핵심 분기.
- admin/teacher/student 경계 회귀 위험이 큰 request.

---

## Codex 테스트 작업 원칙

- 먼저 현재 테스트 파일을 읽고 중복을 피한다.
- 전체 테스트를 무작정 생성하지 않는다.
- 가치 높은 공백을 우선순위로 제안한다.
- 한 세션에서는 한 도메인 또는 한 feature slice만 테스트한다.
- 기존 spec 문서와 architecture 문서를 함께 확인한다.
- brittle한 HTML 구조 테스트를 늘리지 않는다.
- request/model/policy spec 중 가장 confidence가 높은 레벨을 선택한다.
- 전체 diff 출력은 피한다.
- 전체 테스트는 사용자가 실행할 수 있게 명령만 제시한다.
- 자동 commit하지 않는다.

---

## 피해야 할 테스트

- 구현 세부사항에 과하게 결합된 테스트.
- 낮은 가치의 단순 마크업 고정 테스트.
- request/system 테스트의 과도한 중복.
- helper/shared_context 남용으로 읽기 어려워진 테스트.
- 아직 확정되지 않은 spec을 성급히 고정하는 테스트.
- 수동으로 자주 바꾸는 UI 문구나 Tailwind class만 검증하는 테스트.

---

## 문서와 테스트의 관계

- 테스트는 `docs/specs/*.md`와 `docs/architecture/*.md`에 합의된 요구사항을 기준으로 작성한다.
- spec이 부족한 기능은 먼저 현재 구현과 정책을 읽고, 필요한 경우 spec 문서를 보강한 뒤 테스트를 설계한다.
- archive/legacy 문서는 사용자가 요청하거나 현재 문서만으로 맥락을 알 수 없을 때만 참고한다.
- 테스트는 과거 구현을 복제하기 위한 장치가 아니라, 현재 `suksuk_praise`의 도메인 규칙과 사용자 흐름을 안전하게 고정하는 장치다.

---

## 한 줄 기준

테스트는 coverage를 채우기 위한 작업이 아니라,
`suksuk_praise`의 role, classroom, coupon, compliment, PIN, avatar, message 정책을 안전하게 바꿀 수 있게 만드는 안전망이다.
