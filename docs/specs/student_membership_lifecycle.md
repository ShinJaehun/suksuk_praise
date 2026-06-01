# Student Membership Lifecycle

## 목적

학생의 교실 활동 상태는 `User`가 아니라 `ClassroomMembership`으로 관리한다.
학생 계정 삭제 요청이 들어와도 기록 보존 여부와 다른 교실 소속 여부를 먼저 확인한다.

## Membership 상태

`ClassroomMembership`에 `status`를 둔다.

- 허용값: `active`, `inactive`
- 기본값: `active`
- 현재 단계에서는 `transferred`, `graduated`, `archived` 같은 상태를 추가하지 않는다.

`Classroom#students`는 일반 교실 운영에서 사용하는 active 학생 목록을 의미한다.
inactive 학생은 교사 일반 운영 화면, 칭찬 대상, 쿠폰 추첨 대상, 학생 PIN 로그인 선택 목록,
새 메시지 대상에서 제외한다.

admin 구성원 관리 화면에서는 inactive 학생도 확인할 수 있어야 한다.
inactive 학생은 회색 badge와 흐린 스타일 등으로 active 학생과 구분한다.

## 삭제 요청 정책

학생 삭제 요청은 현재 교실 membership 처리와 `User` hard delete 가능 여부를 분리해서 판단한다.

### 현재 교실 기록

현재 교실 기록은 현재 `classroom_id`에 연결된 다음 데이터를 기준으로 판단한다.

- 학생이 주거나 받은 칭찬
- 학생에게 발급된 쿠폰
- 학생 기준 쿠폰 사용 요청
- 학생이 주거나 받은 메시지

현재 교실 기록이 하나라도 있으면 현재 `ClassroomMembership`은 삭제하지 않고
`inactive`로 변경한다.

### User 전역 기록

`User` hard delete 가능 여부는 모든 교실 범위의 다음 활동 기록을 기준으로 판단한다.

- `given_compliments`
- `received_compliments`
- `user_coupons`
- 학생 기준 `coupon_use_requests`
- `sent_messages`
- `received_messages`

`User` hard delete는 전역 활동 기록이 없고 다른 교실 소속도 없을 때만 허용한다.

### 처리 규칙

| 조건 | 처리 |
|---|---|
| 현재 교실 기록 있음 | 현재 membership을 `inactive` 처리 |
| 현재 교실 기록 없음 + 다른 교실 소속 있음 | 현재 membership만 삭제 |
| 현재 교실 기록 없음 + 다른 교실 소속 없음 + 전역 기록 없음 | `User` hard delete |
| 현재 교실 기록 없음 + 다른 교실 소속 없음 + 전역 기록 있음 | `User` hard delete 금지. 기본 안전 처리로 현재 membership을 `inactive` 처리 |

마지막 경우는 데이터 추적 가능성을 유지하기 위해 `inactive`를 기본안으로 삼는다.
구현 중 실제 발생 가능한 데이터 관계를 확인한 뒤 membership 제거가 더 적절한 예외가 있는지
별도로 검토한다.

## 사용자 안내

- 기록 때문에 inactive 처리한 경우:
  `기록이 있어 학생 자료는 삭제하지 않고 비활성 처리했습니다.` 취지로 안내한다.
- 실제 hard delete한 경우:
  잘못 생성된 학생 계정을 삭제했다는 취지로 안내한다.
- 다른 교실 소속이 있어 현재 membership만 삭제한 경우:
  현재 교실에서만 학생을 제거했다는 취지로 안내한다.

문구를 구현할 때는 locale에 추가한다.

## 이미 로그인한 inactive 학생

inactive 학생은 PIN 로그인 목록과 로그인 검증에서 제외한다.

학생이 로그인한 뒤 membership이 inactive로 바뀐 경우에는 다음 요청에서 active membership을
확인한다. 유효한 active membership이 없으면 학생 세션을 종료하고 학생 로그인 화면으로
redirect한다.

## 구현 원칙

- controller에서는 `authorize`, `policy_scope`와 흐름 제어를 담당한다.
- view에서 `policy(...)`를 직접 호출하지 않는다.
- per-item 권한이나 상태 판단은 controller에서 계산해서 view에 전달한다.
- 일반 운영 화면은 active 학생만 조회한다.
- admin 구성원 관리 화면은 inactive membership도 별도로 조회할 수 있다.
- `current_system.md`와 backlog 문서는 구현 및 targeted spec 완료 후 갱신한다.
