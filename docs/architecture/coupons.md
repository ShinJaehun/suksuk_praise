# Coupons Architecture

이 문서는 **쑥쑥칭찬통장(SukSuk Praise)** 앱의 쿠폰 관련 기능 구조를 개발자 관점에서 정리한 문서다.

---

## 1. 주요 개념

### User

| 역할 | 설명 |
|------|------|
| `student` | 쿠폰 수령 및 사용 |
| `teacher` | 쿠폰 발급 및 관리 |
| `admin` | 전체 관리 (라이브러리 쿠폰 템플릿 포함) |

**연관 관계**
- `has_many :classroom_memberships`
- `has_many :classrooms, through: :classroom_memberships`
- `has_many :user_coupons`

**권한**
- `admin`: 전체 조회 가능
- `teacher`: 자신의 교실 학생 조회 가능
- `student`: 자기 자신만 조회 가능

---

## 2. 교실 (Classroom)

- `has_many :classroom_memberships, dependent: :destroy`
- `has_many :users, through: :classroom_memberships`
- `has_many :user_coupons`

**권한**
- `show?`: 교실 멤버 or admin
- `manage?`: admin 또는 해당 교실 teacher

**기능**
- 교실 학생 목록 및 최근 발급 쿠폰 조회
- 최근 발급 쿠폰 5개 로드

---

## 3. 쿠폰 템플릿 (CouponTemplate)

쿠폰의 “종류”를 정의하는 모델.  
교사별 개인 세트(personal)와 관리자용 라이브러리(library)로 구분.

```rb
class CouponTemplate < ApplicationRecord
  has_many :user_coupons, dependent: :restrict_with_exception
  belongs_to :created_by, class_name: "User"

  validates :title, presence: true
  validates :weight, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :bucket, inclusion: { in: %w[personal library] }

  validates :title, uniqueness: {
    scope: %i[created_by_id bucket],
    case_sensitive: false,
    message: :already_in_bucket
  }

  scope :active, -> { where(active: true) }
  scope :personal_for, ->(user) { where(created_by_id: user.id, bucket: "personal") }
end
```

### Personal 버킷 불변식

| 규칙 | 설명 |
|------|------|
| 1 | active && weight <= 0 → 금지 |
| 2 | inactive → weight는 0으로 고정 |
| 3 | 전체 active weight 합은 100 권장 (WeightBalancer로 정규화 가능) |

### Library 버킷
- admin이 생성, 교사는 읽기만 가능
- 교사는 “가져오기(adopt)”로 자신의 personal로 복제 가능

### Policy 요약
| 액션 | 권한 |
|-------|------|
| index / library / create | teacher, admin |
| update / toggle_active / destroy / bump_weight | admin 또는 owner |
| adopt / rebalance_equal | teacher, admin |

---

## 4. 쿠폰 (UserCoupon) 및 로그 (CouponEvent)

### UserCoupon

```rb
class UserCoupon < ApplicationRecord
  belongs_to :classroom
  belongs_to :user
  belongs_to :coupon_template
  belongs_to :issued_by, class_name: "User", optional: true

  enum status: { issued: 0, used: 1 }
  enum issuance_basis: { daily: "daily", weekly: "weekly", manual: "manual" }

  validates :issued_at, :status, :issuance_basis, :period_start_on, presence: true
end
```

- `issue!` 헬퍼로 basis, period_start_on 자동 설정
- `use!` → `issued` → `used` 전이만 허용

### CouponEvent

```rb
class CouponEvent < ApplicationRecord
  belongs_to :actor, class_name: 'User'
  belongs_to :user_coupon
  belongs_to :classroom
  belongs_to :coupon_template

  validates :action, inclusion: { in: %w[issued used] }
end
```

- `action`: `issued` or `used`
- `metadata`: 발급 기준, 학생 정보 등 포함
- Admin/Teacher 로그 조회 페이지 `/coupon_events#index`

---

## 5. WeightBalancer

`CouponTemplates::WeightBalancer.normalize!(user)`  
→ personal 세트의 active weight 합을 100으로 자동 정규화.

**규칙**
- inactive 템플릿은 weight = 0 고정
- active만 균등 분배 (가중치 합 100)
- 남는 100-합 값은 소수점 기준으로 보정 (largest remainder)

---

## 6. Controller 핵심 동작 요약

### CouponTemplatesController

| 액션 | 설명 |
|------|------|
| index | 내 쿠폰(@personal) + 라이브러리(@library) 프레임 렌더 |
| rebalance_equal | WeightBalancer로 균등 분배 |
| create / update / toggle_active / destroy | personal 관리용, 후처리로 normalize 호출 |
| adopt | library 템플릿을 personal로 복제 |
| bump_weight | 10단위 증감, 합 100 초과 시 no-op, 0 → 비활성화, 양수 → 자동 활성 가능 |

### 안전장치
- `DUP_WINDOW` (1~2초) 중복 요청 방지
- `with_lock` + DB 트랜잭션 기반 병행 제어
- Stimulus `disable_on_submit`로 UI 중복 요청 차단

---

## 7. Rails Console 헬스체크 스니펫

### 7.1 전체 불변식 검사

```rb
ct_health!
```

출력:
- personal active weight <= 0 → NG
- personal inactive weight != 0 → NG
- 각 교사별 weight 합 (100 아니면 WARN)

### 7.2 특정 교사 personal 세트 확인

```rb
u = User.find_by(email: "teacher@example.com")
ct_personal_for(u)
```

- 활성/비활성 목록 및 weight 합 출력

### 7.3 bump_weight 시뮬레이션

```rb
ct_try_bump(user, tpl_id, 10)     # +10
ct_try_bump(user, tpl_id, -10)    # -10
ct_try_bump(user, tpl_id, -100)   # 0으로 떨어질 때 auto 비활성화
```

- 컨트롤러 로직과 동일하게 동작
- before/after, 합계, 자동 비활성화 여부 출력

---

## 8. I18n 구조 요약

| 파일 | 역할 |
|------|------|
| `ko.yml` | 전역 UI, 교실/학생/쿠폰발급, 리포트 등 |
| `ko.coupon_templates.yml` | 쿠폰 템플릿 관리 화면 전용 |
| `en.yml`, `devise.en.yml` | 기본 영문/Devise 번역 |

---

## 9. 현재 단계 요약 (P2.5 완료 상태)

| 단계 | 내용 | 상태 |
|-------|------|------|
| A | 중복요청 가드 + Turbo UX | ✅ |
| B | console 헬스체크 스니펫 | ✅ |
| C | i18n 구조 정리 (`ko.yml` / `ko.coupon_templates.yml`) | ✅ |
| D | 문서화 (본 문서) | ✅ |

---

## 결론

- 모든 쿠폰 관련 불변식/가중치 규칙은 명시적이며,
- Admin/Teacher/Student별 접근 권한이 명확하고,
- 헬스체크/시뮬레이터로 상태 검증 가능하며,
- 다국어 구조(i18n) 분리 완료 상태다.

이 문서만으로 쿠폰 시스템 전체의 데이터 흐름과 관리 규칙을 즉시 파악할 수 있다.
