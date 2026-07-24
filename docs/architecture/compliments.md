# Compliments Architecture

이 문서는 **쑥쑥칭찬통장(SukSuk Praise)** 앱의 칭찬(Compliment) 기능 구조를 개발자 관점에서 정리한 문서다.

---

## 1. 주요 개념

### Compliment

```rb
class Compliment < ApplicationRecord
  belongs_to :giver, class_name: "User"
  belongs_to :receiver, class_name: "User"
  belongs_to :classroom

  validates :classroom, :given_at, presence: true
end
```

칭찬은 교사가 특정 교실의 학생에게 부여하는 이벤트이며,
학생의 점수(points) 누적과 연결된다.

맞춤 칭찬은 별도의 행동 기록이 아니라 `reason` snapshot이 붙은 일반 `Compliment`다.
일반 칭찬은 `compliment_preset_id`와 `reason`이 비어 있을 수 있고, 맞춤 칭찬은 선택한
사용자 소유 `ComplimentPreset` 참조와 생성 당시 preset 문구를 `reason`에 복사해 저장한다.

---

## 2. 관련 역할

### teacher
- 자신의 교실 학생에게 칭찬 생성 가능

### admin
- 전체 조회/관리 가능(정책에 따라)

### student
- 직접 칭찬 생성 불가
- 본인 관련 칭찬 결과는 조회 가능 범위 내에서만 접근

---

## 3. 데이터 흐름

기본 흐름은 다음과 같다.

1. 교사가 `ComplimentsController#create` 호출
2. `authorize @classroom, :create_compliment?`
3. 중복 요청 방지 로직 적용
4. 트랜잭션으로 `Compliment` 생성
5. `receiver.increment!(:points)` 로 학생 점수 증가

---

## 4. 핵심 규칙

- 칭찬은 교실(context)을 가진다.
- giver / receiver / classroom 관계가 일관되어야 한다.
- 권한 없는 사용자는 칭찬 생성 불가
- 동일 요청의 짧은 시간 내 중복 생성은 방지
- 칭찬 생성과 points 증가는 함께 처리되어야 한다.
- 맞춤 칭찬도 같은 생성 transaction 안에서 `Compliment` 생성과 points 증가를 처리한다.
- 맞춤 칭찬 preset은 teacher/admin 사용자 개인 소유이며 사용자별 active 5개까지 허용한다.
- 같은 사용자는 담당하는 모든 교실에서 같은 preset을 사용하고, 같은 교실의 다른 교사는 각자 자신의 preset만 사용한다.
- preset을 수정하거나 비활성화해도 과거 칭찬 로그는 `Compliment#reason` snapshot을 표시한다.
- 맞춤 칭찬도 총 칭찬 수, 일간·주간·월간 칭찬왕, 쿠폰 발급/추첨 정책에 일반 칭찬과 동일하게 포함된다.
- `/compliment_events` 전역 칭찬 로그는 접근 가능한 교실의 일반 칭찬과 맞춤 칭찬을 같은 목록에서 최신순으로 보여준다.
- 칭찬 로그의 맞춤 칭찬 구분은 `compliment_preset_id`가 아니라 `reason` snapshot 존재 여부를 기준으로 한다.
- 칭찬 로그는 일반 단일 교실 teacher에게 유일한 담당 교실을 자동 적용하고, admin·복수 교실 teacher·school manager는 교실 선택 UI를 사용한다.
- school manager는 manager 권한만으로 학교 전체 칭찬 로그를 볼 수 없고, active teacher membership이 있는 교실만 기존 teacher 범위로 조회한다.
- 칭찬 로그는 교실 필터, 교실 선택 또는 자동 선택 후 사용할 수 있는 학생 필터, 기간 필터, 일반/맞춤 칭찬 종류 필터, 칭찬 시각 정렬, pagination을 제공한다.
- 칭찬 로그의 기본 기간은 최근 7일이며 기간 계산은 `Compliment#given_at`을 기준으로 한다.
- 칭찬 로그 정렬은 기본 최신순 `given_at DESC, id DESC`이고 오래된순은 `given_at ASC, id ASC`으로 tie-breaker를 유지한다.
- pagination은 유효한 filter parameter를 `/compliment_events` 경로에서 보존한다.
- `/compliment_templates` 전역 관리 화면은 로그인한 teacher/admin 자신의 자주 쓰는 칭찬 preset만 관리하며 교실 필터는 없다. 내부 모델과 테이블은 `ComplimentPreset`, `compliment_presets`를 유지한다.
- 칭찬 로그와 자주 쓰는 칭찬 관리는 현재 교실 문맥 없이 navbar 전역 링크로 접근하고, 교실 show 화면은 학생 칭찬 운영에 집중한다.
- 실제 `Compliment`는 계속 칭찬이 발생한 `classroom_id`에 소속된다.

---

## 5. 안전장치

- `DUP_WINDOW` 기반 중복 요청 방지
- 트랜잭션으로 칭찬 생성 + points 증가를 묶음 처리
- teacher/admin 권한 정책으로 접근 제어

---

## 6. 칭찬왕 집계

- 일간·주간·월간 집계는 `ComplimentKings::Pick`이 담당한다.
- 일간은 해당 날짜, 주간은 월요일 시작 주, 월간은 달력 월을 Rails `Time.zone` 기준으로 계산한다.
- 활성 학생만 집계하며, 최고 횟수가 같은 학생은 모두 결과에 포함한다.
- 결과를 별도 선정 record로 저장하지 않고 조회할 때마다 다시 계산한다.
- 교실별 기간 활성 설정은 화면과 서버측 쿠폰 발급에 모두 적용한다.

상세 정책과 향후 학교 운영일 연동 계획은
[`weekly_monthly_compliment_king.md`](../specs/weekly_monthly_compliment_king.md)를 참고한다.

---

## 7. 테스트 우선순위

칭찬 기능에서 우선 테스트할 항목:

- 권한 있는 teacher만 create 가능한지
- 권한 없는 사용자 접근 차단
- 중복 요청 방지 동작
- 칭찬 생성 시 points가 정확히 1 증가하는지
- 실패 시 칭찬 생성과 points 증가가 함께 롤백되는지

---

## 8. 관련 코드 위치

- `app/models/compliment.rb`
- `app/models/compliment_preset.rb`
- `app/services/compliment_kings/pick.rb`
- `app/controllers/compliments_controller.rb`
- `app/controllers/compliment_events_controller.rb`
- `app/controllers/compliment_templates_controller.rb`
- 관련 policy / request spec / service 객체(있다면)

---

## 9. Open Questions

- admin의 칭찬 생성 권한 범위 문구는 현재 코드 기준 확인 필요.
- 칭찬 취소/삭제 시 points 보정 규칙이 필요한가?

## 10. 문서 유지 원칙

- 현재 시스템 전체 요약은 `docs/architecture/current_system.md`에 둔다.
- 이 문서는 칭찬 생성, 중복 요청 방지, points 증가 등 상세 규칙을 유지한다.
