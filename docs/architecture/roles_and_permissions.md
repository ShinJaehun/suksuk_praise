# Roles And Permissions

## 권한 구조 요약

- 서버측 권한 판단의 중심은 Pundit policy와 `policy_scope`이다.
- 모든 비-`index` 액션은 `ApplicationController`의 `verify_authorized`, `index` 액션은 `verify_policy_scoped` 대상으로 관리된다.
- 실제 권한 경계는 전역 `User#role`(`admin`, `teacher`, `student`)과 교실 단위 `ClassroomMembership#role`(`teacher`, `student`)의 조합으로 형성된다.
- `teacher` 권한은 전역 role만으로 충분하지 않고, 대부분의 교실 관련 쓰기 권한은 "해당 classroom의 teacher membership"이 있어야 허용된다.
- 일부 리소스는 policy 외에 controller/service guard가 추가로 있다.
  - `UsersController#show`의 classroom membership 확인
  - `CouponDraw::Issue`의 대상 학생 소속 및 daily king 확인
  - `UserCoupon#user_belongs_to_classroom`

## 역할 설명

- `admin`
  - 전역 관리 권한을 가진다.
  - 대부분의 scope 전체 조회와 관리 액션이 허용된다.
- `teacher`
  - 전역 role은 `teacher`지만, 교실 관련 권한은 해당 교실의 teacher membership 여부로 다시 제한된다.
  - 쿠폰 템플릿은 개인 세트(personal) 소유권 기준으로 관리한다.
- `student`
  - 본인 리소스와 자신이 속한 교실 조회 중심이다.
  - 교실 관리, 칭찬 생성, 쿠폰 발급, 쿠폰 이벤트 조회는 허용되지 않는다.
- `guest`
  - 주요 컨트롤러가 `authenticate_user!`를 사용하므로 사실상 본 문서 대상 액션 대부분에 접근하지 못한다.

## 기본 원칙

- `Classroom`, `Compliment`, 교실 내 학생 관리는 classroom membership이 핵심 기준이다.
- `CouponTemplate` personal 영역은 소유권(`created_by_id`)이 핵심 기준이다.
- `UserCoupon` 조회는 scope, 사용은 `use?` policy로 나뉜다.
- admin 전용 UI라도 controller/policy가 별도 서버측 가드를 갖는지 함께 확인한다.

## 표 읽는 법

- `리소스/액션` 열은 실제 서버 엔드포인트 기준으로 `Controller#action` 형식을 사용한다.
- `정책 기준` 열에는 해당 엔드포인트가 실제로 호출하는 policy 메서드나 scope를 적는다.
- service/model guard는 `비고`에만 적는다.
- 현재 운영 중인 엔드포인트만 권한 매트릭스에 포함한다.

## 권한 매트릭스

### Classroom / ClassroomStudent

| 리소스/액션 | 정책 기준 | admin | teacher | student | 비고 |
|---|---|---|---|---|---|
| `ClassroomsController#index` | `policy_scope(Classroom)` | 가능 | 가능 | 가능 | role별 classroom scope 적용 |
| `ClassroomsController#show` | `ClassroomPolicy#show?` | 가능 | 본인 teacher/student membership 교실만 가능 | 본인 membership 교실만 가능 |  |
| `ClassroomsController#new` | `ClassroomPolicy#create?` | 가능 | 가능 | 불가 |  |
| `ClassroomsController#create` | `ClassroomPolicy#create?` | 가능 | 가능 | 불가 | 생성 성공 시 생성자를 teacher membership으로 추가 |
| `ClassroomsController#edit` | `ClassroomPolicy#update?` | 가능 | 해당 교실 teacher membership일 때만 가능 | 불가 |  |
| `ClassroomsController#update` | `ClassroomPolicy#update?` | 가능 | 해당 교실 teacher membership일 때만 가능 | 불가 |  |
| `ClassroomsController#destroy` | `ClassroomPolicy#destroy?` | 가능 | 해당 교실 teacher membership일 때만 가능 | 불가 | `destroy?`는 `update?` 위임 |
| `ClassroomsController#refresh_compliment_king` | `ClassroomPolicy#show?` | 가능 | membership 교실이면 가능 | membership 교실이면 가능 | 읽기 액션으로 동작 |
| `ClassroomsController#draw_coupon` | `ClassroomPolicy#draw_coupon?` | 가능 | 해당 교실 teacher membership일 때만 가능 | 불가 | `CouponDraw::Issue`가 대상 학생 소속, daily king, 중복 발급을 추가 검증 |
| `ClassroomStudentsController#new` | `ClassroomPolicy#manage_members?` | 가능 | 해당 교실 teacher membership일 때만 가능 | 불가 |  |
| `ClassroomStudentsController#create` | `ClassroomPolicy#manage_members?` | 가능 | 해당 교실 teacher membership일 때만 가능 | 불가 | 새 user는 항상 `role: student` |
| `ClassroomStudentsController#bulk_new` | `ClassroomPolicy#manage_members?` | 가능 | 해당 교실 teacher membership일 때만 가능 | 불가 |  |
| `ClassroomStudentsController#bulk_create` | `ClassroomPolicy#manage_members?` | 가능 | 해당 교실 teacher membership일 때만 가능 | 불가 | 벌크 생성도 동일한 membership 기준 |

### User

| 리소스/액션 | 정책 기준 | admin | teacher | student | 비고 |
|---|---|---|---|---|---|
| `UsersController#show` | `UserPolicy#show?` | 가능 | 자신이 teacher인 교실에 속한 학생만 가능 | 본인만 가능 | `classroom_id`가 있으면 classroom `show?`와 대상 user membership을 추가 확인 |
| `Admin::TeachersController#index` | `policy_scope(User)` | 가능 | 불가 | 불가 | `Admin::BaseController#require_admin!`도 필요 |
| `Admin::TeachersController#new` | `UserPolicy#create?` | 가능 | 불가 | 불가 |  |
| `Admin::TeachersController#create` | `UserPolicy#create?` | 가능 | 불가 | 불가 | 새 계정은 항상 `role: teacher` |
| `Admin::TeachersController#edit` | `UserPolicy#update?` | 가능 | 불가 | 불가 | 대상 teacher의 homeroom membership 관리 |
| `Admin::TeachersController#update` | `UserPolicy#update?` | 가능 | 불가 | 불가 | teacher classroom membership만 수정 |

### Compliment

| 리소스/액션 | 정책 기준 | admin | teacher | student | 비고 |
|---|---|---|---|---|---|
| `UsersController#show`의 칭찬 목록 로드 | `policy_scope(Compliment)` | 가능 | 자신이 teacher인 교실의 칭찬만 | 본인이 받은 칭찬만 | `UserShowDataLoader`에서 로드 |
| `ComplimentsController#create` | `ClassroomPolicy#create_compliment?` | 가능 | 해당 교실 teacher membership일 때만 가능 | 불가 | `ClassroomPolicy#show?`도 함께 통과해야 하며 receiver는 classroom membership에서만 선택 가능 |

### CouponTemplate

| 리소스/액션 | 정책 기준 | admin | teacher | student | 비고 |
|---|---|---|---|---|---|
| `CouponTemplatesController#index` | `CouponTemplatePolicy#index?` | 가능 | 가능 | 불가 | personal은 `policy_scope`, library는 `library_scope` 사용 |
| `CouponTemplatesController#new` | `CouponTemplatePolicy#create?` | 가능 | 가능 | 불가 | teacher는 personal만 가능 |
| `CouponTemplatesController#create` | `CouponTemplatePolicy#create?` | 가능 | 가능 | 불가 | controller가 teacher의 bucket을 personal로 강제 |
| `CouponTemplatesController#edit` | `CouponTemplatePolicy#update?` | 가능 | 본인 personal만 가능 | 불가 |  |
| `CouponTemplatesController#update` | `CouponTemplatePolicy#update?` | 가능 | 본인 personal만 가능 | 불가 | teacher는 실제 반영 속성이 `title`로 제한됨 |
| `CouponTemplatesController#toggle_active` | `CouponTemplatePolicy#toggle_active?` | 가능 | 본인 personal만 가능 | 불가 |  |
| `CouponTemplatesController#destroy` | `CouponTemplatePolicy#destroy?` | 가능 | 본인 personal만 가능 | 불가 | 발급 이력 있으면 삭제 대신 비활성화 |
| `CouponTemplatesController#bump_weight` | `CouponTemplatePolicy#bump_weight?` | 가능 | 본인 personal만 가능 | 불가 | admin은 library도 조정 가능 |
| `CouponTemplatesController#adopt` | `CouponTemplatePolicy#adopt?` | 가능 | 가능 | 불가 | source는 `library_scope`에서만 선택 가능 |
| `CouponTemplatesController#adopt_all_from_library` | `CouponTemplatePolicy#adopt?` | 가능 | 가능 | 불가 | active library를 personal로 반영 |
| `CouponTemplatesController#rebalance_personal` | `CouponTemplatePolicy#rebalance_equal?` | 가능 | 가능 | 불가 | current_user personal 세트 기준 |
| `CouponTemplatesController#rebalance_library` | `CouponTemplatePolicy#rebalance_equal?` | 가능 | 불가 | 불가 | controller가 `current_user.admin?`를 추가 확인 |

### UserCoupon / CouponEvent

| 리소스/액션 | 정책 기준 | admin | teacher | student | 비고 |
|---|---|---|---|---|---|
| `UserCouponsController#index` | `UserPolicy#show?` + `policy_scope(UserCoupon)` | 가능 | 가능 | 본인만 가능 | teacher scope가 classroom으로 제한되지 않음 |
| `UserCouponsController#use` | `UserCouponPolicy#use?` | 가능 | 해당 coupon classroom의 teacher membership이면 가능 | 본인 coupon만 가능 | `UserCoupons::Use`가 상태 전이와 이벤트 생성을 처리 |
| `CouponEventsController#index` | `CouponEventPolicy#index?` + `policy_scope(CouponEvent)` | 가능 | 가능 | 불가 | teacher는 담당 교실 이벤트와 본인이 actor인 이벤트 조회 |

## 현재 미사용 정책 항목

- `UserPolicy#index?`
- `UserPolicy::Scope`
- `ComplimentPolicy#show?`
- `ComplimentPolicy#create?`
- `ComplimentPolicy#update?`
- `ComplimentPolicy#destroy?`
- `ClassroomStudentPolicy#create?`
- `ClassroomStudentPolicy#destroy?`

현재 코드베이스에는 대응하는 일반 운영 엔드포인트가 없거나, 다른 policy 경로로 대체되어 있다. 테스트 작성 시에는 운영 엔드포인트 기준 우선순위를 먼저 둔다.

## 리소스별 설명

### Classroom

- 교실 조회 범위는 `policy_scope(Classroom)`로 role별로 나뉜다.
- teacher의 수정 권한은 전역 role만으로 충분하지 않고, 해당 교실의 teacher membership이 필요하다.
- `refresh_compliment_king`은 읽기 액션으로 취급되어 `show?`만 요구한다.

### User

- 일반 사용자 상세 조회는 `UserPolicy#show?`와 optional classroom context guard를 함께 본다.
- teacher는 "내가 teacher인 교실에 속한 학생"만 볼 수 있다.
- admin teacher 관리 화면은 별도 namespace guard(`Admin::BaseController`)와 `UserPolicy`를 함께 사용한다.

### Compliment

- 실제 생성 엔드포인트는 `ComplimentsController#create` 하나다.
- 생성 가능 여부는 `ComplimentPolicy#create?`가 아니라 `ClassroomPolicy#create_compliment?`로 결정된다.
- receiver는 controller에서 반드시 해당 classroom membership에서 찾아온다.

### CouponTemplate

- personal 템플릿은 owner 중심, library 템플릿은 admin 소유 + `bucket=library` 전제다.
- teacher는 library를 읽고 adopt할 수 있지만 직접 library를 수정할 수는 없다.
- teacher의 personal `update`는 policy상 owner이면 가능하지만, controller가 실제 반영 속성을 `title`로 제한한다.

### UserCoupon

- 사용 권한은 비교적 명확하다.
  - admin
  - coupon 소유 student 본인
  - 해당 coupon classroom의 teacher
- 조회 권한은 `UserPolicy#show?`와 `UserCoupon::Scope`가 결합되어 동작하므로, 실제 노출 범위는 endpoint마다 다시 확인해야 한다.

### CouponEvent

- 조회 전용 리소스다.
- teacher는 자신이 담당하는 교실의 이벤트를 보며, 예외적으로 본인이 actor인 이벤트는 classroom 범위 밖이어도 scope에 포함된다.

## 확인 필요 항목

### 권한 버그 가능성

- teacher의 `UserCoupon::Scope`가 classroom 제한 없이 전체를 반환한다. 현재 구현상 teacher가 조회 가능한 학생 상세에서 다른 교실의 coupon history까지 볼 수 있을 가능성이 있다.
  - 추천 spec 타입: request
  - 위험도: 높음
- `UsersController#show`에서 `classroom_id` 없이 teacher가 학생 상세에 접근할 수 있다. 이 경우 KPI와 coupon 목록이 teacher 담당 교실로 한정되지 않을 가능성이 있다.
  - 추천 spec 타입: request
  - 위험도: 높음

### 정책 의도 확인 필요

- `admin`의 `UserPolicy#update?`는 teacher 계정에만 허용된다. student/admin 계정 관리가 의도적으로 제외된 것인지 문서 기준이 필요하다.
  - 추천 spec 타입: policy 또는 request
  - 위험도: 중간
- `CouponTemplatePolicy::Scope.library_scope`는 teacher에게 active library만 노출하지만, admin은 inactive library도 본다. 이 차이가 운영 정책으로 확정됐는지 명시가 필요하다.
  - 추천 spec 타입: policy 또는 request
  - 위험도: 중간

### 구조 정리 필요

- `ClassroomStudentPolicy`는 정의되어 있지만 `ClassroomStudentsController`는 `ClassroomPolicy#manage_members?`만 사용한다. policy 책임을 단일화하거나 미사용 policy를 정리하는 편이 낫다.
  - 추천 spec 타입: 없음
  - 위험도: 낮음
- `CouponTemplatePolicy`와 `UserPolicy` 일부 메서드는 `user.nil?` 방어가 약하다. 현재는 `authenticate_user!` 전제라 동작하지만 정책 기본값 관점에서는 보완 여지가 있다.
  - 추천 spec 타입: policy
  - 위험도: 낮음

## 문서 유지 원칙

- 권한 문서는 policy, controller, service guard 순으로 확인한 뒤 갱신한다.
- "보이는 버튼"이 아니라 서버측 `authorize`, `policy_scope`, membership 조건을 기준으로 쓴다.
- 새 액션이 추가되면 최소한 해당 엔드포인트의 matrix와 `확인 필요 항목`을 함께 검토한다.
- 문서와 코드가 충돌하면 문서를 먼저 의심하고, 근거가 확인된 후 갱신한다.
