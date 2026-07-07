# Student Membership Lifecycle

## 목적

학생의 교실 활동 상태는 `User`가 아니라 `ClassroomMembership`으로 관리한다.
운영 화면에서는 학생 계정을 기본적으로 삭제하지 않고, 교실 membership을 비활성화하거나 복구한다.

## Membership 상태

`ClassroomMembership`에 `status`를 둔다.

- 허용값: `active`, `inactive`
- 기본값: `active`
- 현재 단계에서는 `transferred`, `graduated`, `archived` 같은 상태를 추가하지 않는다.

`Classroom#students`는 일반 교실 운영에서 사용하는 active 학생 목록을 의미한다.
inactive 학생은 교사 일반 운영 화면, 칭찬 대상, 쿠폰 추첨 대상, 학생 PIN 로그인 선택 목록,
새 메시지 대상에서 제외한다.

teacher/admin 구성원 관리 화면에서는 active/inactive 학생을 한 목록에서 확인한다.
inactive 학생은 흐린 스타일과 복구 action으로 active 학생과 구분한다.

## 비활성화/복구 정책

teacher/admin이 학생을 더 이상 운영 대상으로 쓰지 않으려면 현재 교실의
`ClassroomMembership`을 `inactive`로 변경한다.

- `User`는 삭제하지 않는다.
- 칭찬, 쿠폰, 메시지, 쿠폰 사용 요청 등 과거 기록은 삭제하지 않는다.
- inactive 학생도 teacher/admin은 과거 기록 확인을 위해 상세, 한눈에 보기, 활동 기록,
  메시지 기록 페이지에 접근할 수 있다.
- inactive 학생 상세에서는 칭찬하기, 쿠폰 지급, 새 메시지 작성/답글 작성 같은 운영 action을 숨긴다.
- inactive 학생은 구성원 관리 화면에서 `active`로 복구할 수 있다.

### 직접 삭제 요청

`DELETE /classrooms/:classroom_id/students/:id` 요청이 직접 들어와도 `User` hard delete를 수행하지 않는다.
현재 교실의 student membership을 `inactive`로 변경하는 안전한 동작으로 처리한다.

## 권한

- 비활성화/복구는 `ClassroomPolicy#manage_members?`를 기준으로 한다.
- admin은 가능하다.
- teacher는 해당 classroom의 teacher membership이 있을 때만 가능하다.
- student는 불가하다.

## 사용자 안내

- 비활성화한 경우: 학생을 운영 대상에서 제외했고 과거 기록은 보존된다는 취지로 안내한다.
- 복구한 경우: 학생을 다시 운영 대상으로 복구했다는 취지로 안내한다.
- active 학생 PIN을 일괄 재설정하는 경우: 현재 교실의 활성 학생 PIN만 변경하며 inactive 학생은 변경하지 않는다는 취지로 안내한다.

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
- 구성원 관리 화면은 active/inactive 학생 membership을 한 목록으로 조회한다.
- 구성원 관리 화면의 PIN 일괄 재설정은 현재 교실 active student membership만 대상으로 한다.
- hard delete 허용 여부, 일괄 비활성화, inactive reason/memo는 후속 작업으로 다룬다.
- `current_system.md`와 backlog 문서는 구현 및 targeted spec 완료 후 갱신한다.
