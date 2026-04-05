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

---

## 5. 안전장치

- `DUP_WINDOW` 기반 중복 요청 방지
- 트랜잭션으로 칭찬 생성 + points 증가를 묶음 처리
- teacher/admin 권한 정책으로 접근 제어

---

## 6. 테스트 우선순위

칭찬 기능에서 우선 테스트할 항목:

- 권한 있는 teacher만 create 가능한지
- 권한 없는 사용자 접근 차단
- 중복 요청 방지 동작
- 칭찬 생성 시 points가 정확히 1 증가하는지
- 실패 시 칭찬 생성과 points 증가가 함께 롤백되는지

---

## 7. 관련 코드 위치

- `app/models/compliment.rb`
- `app/controllers/compliments_controller.rb`
- 관련 policy / request spec / service 객체(있다면)

---

## 8. Open Questions

- admin의 칭찬 생성 권한을 어디까지 허용할 것인가?
- 칭찬 취소/삭제 시 points 보정 규칙이 필요한가?
- 기간별 칭찬왕 집계 규칙은 별도 문서로 분리할 것인가?
