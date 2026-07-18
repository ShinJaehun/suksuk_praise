# Backlog

이 문서는 `suksuk_praise`의 후속 작업 후보를 한곳에 모아두기 위한 문서다.

## 문서 사용 원칙

주의:

- 이 문서는 현재 구현 상태의 근거가 아니다.
- 이 문서만 보고 기능을 구현하지 않는다.
- 작업 시작 전 반드시 현재 코드, 관련 spec 문서, 테스트를 확인한다.
- 이미 구현된 기능을 이 문서만 보고 다시 구현하지 않는다.
- 구현이 완료된 항목은 이 문서에서 제거하거나 `Completed / Archived` 섹션으로 옮긴다.
- 구현 완료된 기능의 현재 동작은 `docs/architecture/current_system.md` 또는 관련 `docs/specs/*.md`에 반영한다.

문서 역할:

- `docs/architecture/current_system.md`
  - 현재 구현되어 있는 사실을 정리한다.
- `docs/specs/*.md`
  - 구현하기로 확정한 기능 정책을 정리한다.
- `docs/planning/backlog.md`
  - 아직 구현하지 않았거나, 구현 여부/정책을 더 검토해야 하는 후보를 정리한다.
- `docs/testing/rspec_strategy.md`
  - 테스트 작성 원칙과 우선순위를 정리한다.

한 줄 기준:

> backlog는 “할 수도 있는 일”, spec은 “하기로 한 일”, current_system은 “이미 된 일”이다.

---

## P0. 다음 기능 후보

### Classroom / 학생 관리 후속 작업

- 학생 membership lifecycle 후속 검토
  - `inactive_reason` 또는 간단 메모 필드 추가
  - `pending` 상태 도입
  - 구성원 관리 화면에서 학생을 선택해 일괄 비활성화하는 기능
    - 한 반 규모에서는 단건 비활성화로 충분하므로 우선순위 낮음
    - 학년말 전체 정리나 교실 archive 기능과 함께 재검토
  - 활동 이력이 전혀 없는 학생에 한해 hard delete를 허용할지 검토
  - 명시적인 학생 학급 이동 workflow
    - 기존 active membership 비활성화와 대상 학급 membership 생성 또는 복구를 한 transaction으로 처리
    - admin, 학교 manager, 담당 teacher 중 실행 권한 정책 결정 필요
    - 현재는 다른 active 학급이 있으면 재활성화를 거부하고 자동 이동하지 않음
- 교실·교사 관리 IA 후속 검토
  - 담당 선생님 배정을 admin 전용 교실·교사 관리 흐름으로 정리
- 교실 archive
  - 학년도 종료 시 교실을 읽기 전용으로 보관
  - archive/active 목록 필터
  - archive 교실의 학생 로그인 차단
  - 신규 칭찬·쿠폰·메시지 차단
  - 과거 기록 조회 유지
  - archive 교실 복구 가능 여부 결정
- 학생 상세 통계
- 복사/붙여넣기 학생 등록
- 학생 dashboard 그래프 point의 hover tooltip
- 학생 dashboard 월간/누적 활동 추이
- 쿠폰 이벤트 로그의 학생별 세부 필터
- 학생 상세 하위 페이지의 모바일 밀도, 버튼 크기 등 추가 UI polish
- teacher dashboard를 교실별 운영 상황판으로 확장
- admin dashboard를 교실별 운영 요약 table로 확장

---

### Notification

상태: Candidate  
확정 여부: Needs design  
우선순위: 높음

학생/교사 간 상호작용을 알림으로 연결한다.

현재 구현된 범위:

- 학생 쿠폰 사용 요청 badge는 교실 학생 카드에 표시된다.
- 학생 발신 새 메시지 badge는 교실 학생 카드에 표시된다.
- 쿠폰 요청 badge는 학생 상세의 쿠폰 영역으로, 새 메시지 badge는 학생 메시지 전용 페이지로 이동한다.
- badge 상태는 교실 단위로 처리되며 해당 학생 카드 alert 영역을 Turbo Streams로 갱신한다.
- navbar notification/count/list는 아직 만들지 않는다.

후속 후보:

- 교사 navbar unread badge
- 특정 쿠폰 요청이나 메시지로 이동하는 deep link
- teacher별 개인 unread 상태가 필요한지 검토
- 학생 대상 알림이 필요한지 검토

현재 방향:

- 현재 필요한 알림은 기존 `CouponUseRequest`, `UserMessage.read_at`, 학생 카드 badge 흐름으로 처리한다.
- 지금은 새 Notification 모델이나 notification gem을 도입하지 않는다.
- 범용 알림 목록, 사용자별 읽음 상태 등 현재 구조로 감당하기 어려운 요구가 구체화될 때 모델 또는 gem 도입을 다시 검토한다.
- teacher별 알림 정책은 담임/부담임 또는 primary teacher 정책과 함께 결정한다.

spec 승격 후보:

- `docs/specs/notifications.md`

---

## Completed / Archived

### 구성원 관리 학생 이름 일괄 수정

상태: Implemented
현재 동작 문서: `docs/architecture/current_system.md`, `docs/architecture/roles_and_permissions.md`

- teacher/admin은 구성원 관리 화면에서 학생 이름을 한 번에 저장할 수 있다.
- 수정 대상은 현재 교실의 student membership id 기준으로 제한한다.
- 하나라도 유효하지 않은 이름이 있거나 현재 교실 학생 membership이 아닌 id가 제출되면 전체 저장을 rollback한다.

### 구성원 관리 전체 학생 목록과 active PIN 일괄 재설정

상태: Implemented
현재 동작 문서: `docs/architecture/current_system.md`, `docs/architecture/roles_and_permissions.md`, `docs/specs/student_membership_lifecycle.md`

- 구성원 관리 화면은 active/inactive 학생을 한 목록으로 보여준다.
- inactive 학생은 흐리게 표시하고 복구 action을 제공한다.
- teacher/admin은 현재 교실의 active 학생 PIN을 한 번에 재설정할 수 있다.
- inactive 학생 PIN은 일괄 재설정 대상에서 제외한다.
- 일괄 비활성화, 계정 hard delete는 구현하지 않았다.

### 학생별 쿠폰 직접 지급

상태: Implemented
현재 동작 문서: `docs/architecture/current_system.md`, `docs/architecture/roles_and_permissions.md`

- 학생 쿠폰 관리 페이지에서 권한이 있는 teacher/admin에게만 `쿠폰 지급` 버튼을 표시한다.
- 버튼은 Turbo Frame으로 쿠폰 지급 카드를 로드하며, 카드에서 가중치 기반 `쿠폰 뽑기`와 template 선택 `쿠폰 지급`을 제공한다.
- 선택 지급은 `issuance_basis: manual`, `basis_tag: selected`로 기록하고 기존 랜덤 학생 발급은 `manual/default` 흐름을 유지한다.
- 담당 teacher는 자기 교실의 active 학생에게만 지급할 수 있다. 외부 teacher, student, inactive 학생, 접근 불가 또는 inactive template은 차단한다.
- 교실 칭찬왕 발급은 선택 지급 없이 기존 랜덤 `쿠폰 뽑기`만 유지한다.

### 학생 상세 하위 페이지 재구성

상태: Implemented
현재 동작 문서: `docs/architecture/current_system.md`

- 기본 학생 상세 페이지를 학생 정보와 쿠폰 관리, pending 쿠폰 사용 요청 승인 중심으로 정리했다.
- 학생 메시지 작성 폼과 thread를 학생별 메시지 전용 페이지로 분리했다.
- 최근 발급 쿠폰과 칭찬 타임라인을 학생별 활동 기록 페이지로 분리했다.
- teacher/admin이 URL의 classroom과 student를 기준으로 특정 학생의 주간 한눈에 보기를 조회할 수 있다.
- 학생 상세의 하위 페이지들은 avatar, 이름, 반 이름, KPI badge, 하위 페이지 이동 nav pills가 있는 공통 학생 정보 카드를 사용한다.
- 학생과 teacher/admin이 사용하는 이동 버튼과 teacher/admin 전용 관리 버튼을 구분했다.
- `message_policy`가 `disabled`이면 학생 메시지 버튼을 숨기고 메시지 전용 페이지 직접 접근을 차단한다.
- 교실 학생 카드의 새 메시지 badge는 학생 메시지 전용 페이지로 연결된다.

### 학생 dashboard 주간 활동 요약

상태: Implemented
현재 동작 문서: `docs/architecture/current_system.md`

- `week_offset`으로 선택한 주의 월요일부터 금요일까지 이동하고 활동을 집계한다.
- 지금까지 받은 칭찬, 선택 주 칭찬, 보유 쿠폰, 선택 주 쿠폰 발급/사용 수를 한 줄 summary panel로 표시한다.
- 날짜별 칭찬 수를 자동 y축 눈금의 곡선형 SVG 그래프로 표시한다.
- 쿠폰 발급일에는 `🎁`, 사용일에는 `✅` marker를 표시한다.
- 활동이 없는 주에는 데이터 선, 점, marker, y축 숫자를 숨긴 빈 그래프를 표시한다.

---

### 학생 로그인 화면 썸네일 preview

상태: Implemented  
현재 동작 문서: `docs/architecture/current_system.md`

- 학생 PIN 로그인 화면에서 학생을 선택하면 해당 학생의 avatar와 이름을 표시한다.
- 선택 전에는 기본 안내 이미지를 표시한다.

---

### 학생 쿠폰 사용 요청

상태: Implemented  
현재 동작 문서: `docs/architecture/current_system.md`, `docs/architecture/coupons.md`, `docs/specs/student_portal_phase1_spec.md`

- 학생은 자기 쿠폰에 대해 사용 요청을 만들 수 있다.
- pending 중복 요청은 막는다.
- teacher/admin은 요청을 승인하거나 쿠폰을 직접 사용 처리할 수 있다.
- 쿠폰 요청 badge와 학생/관리 쿠폰 목록 Turbo Stream 갱신이 구현되어 있다.

---

## P1. 역할/관리 정책 정리

### 담임 / 부담임 / primary teacher 정책

상태: Candidate  
확정 여부: Needs decision  
우선순위: 중간~높음

현재 classroom에는 여러 teacher가 소속될 수 있지만, 담임/부담임 또는 primary teacher 구분은 없다.

검토할 정책:

- 모든 teacher를 동등하게 볼지
- primary teacher 1명을 둘지
- `teacher_role: homeroom / assistant` 구조를 둘지
- `primary_teacher: true` 같은 boolean으로 충분한지
- 메시지 recipient와 notification 대상자를 분리할지
- 쿠폰 요청/메시지 알림을 모든 teacher에게 보낼지

현재 보류 이유:

- notification 정책과 강하게 연결된다.
- 교실 관리 UI에도 영향을 준다.
- 지금 바로 모델링하면 범위가 커질 수 있다.

---

### 관리자 / 교사 관리 화면 통합

상태: Candidate  
확정 여부: Not decided  
우선순위: 중간

현재 관리자/교사 관리 흐름이 nav와 화면에서 분리되어 있거나 중복될 수 있다.  
관리자와 교사 관리 화면을 어떻게 나눌지 정리가 필요하다.

검토할 내용:

- admin 전용 교사 관리 페이지
- teacher 본인 정보 수정 페이지
- 교사 썸네일 수정
- 담임/부담임 또는 primary teacher 설정
- 교실 배정 관리
- 관리자 nav와 교사 nav의 역할 분리

구현 전 확인:

- 현재 admin/teacher 관련 controller
- `UserPolicy`
- navbar partial
- 교실 membership 관리 흐름

---

### 교사/관리자 마이페이지 재정의

상태: Candidate  
확정 여부: Needs design  
우선순위: 중간

현재 `users/:id` 화면은 학생 상세 페이지에 가까운 구조다.  
교사/관리자의 “마이페이지”가 무엇을 보여줘야 하는지 다시 정해야 한다.

검토할 내용:

- 교사/관리자용 dashboard가 필요한지
- `users/:id`를 역할별로 다르게 렌더링할지
- 교사 프로필에는 어떤 정보가 필요한지
- 학생 페이지와 교사 페이지를 분리할지
- 별도 `teachers/:id` route가 필요한지

주의:

- 새 route를 만들기 전에 현재 `users/:id` 사용 위치를 확인한다.
- 학생 canonical page는 이미 classroom-scoped student page 중심으로 정리되어 있다.

---

## P2. 학생 UX 개선

### 하루 점수 / 전체 점수 분리

상태: Candidate  
확정 여부: Not decided  
우선순위: 중간

현재 점수 표시를 “오늘 받은 점수”와 “전체 누적 점수”로 분리하는 방안을 검토한다.

검토할 내용:

- 오늘 받은 칭찬 수 또는 점수
- 전체 누적 점수
- 학생 상세 페이지에서의 표시 위치
- 교사 classroom 화면에서의 표시 방식
- 칭찬 타임라인과의 연결

정책 후보:

- classroom 카드에서는 오늘 점수 중심
- 학생 상세에서는 전체 점수와 최근 기록 모두 표시

---

### 학생 하위 페이지 UI 추가 개선

상태: Candidate  
확정 여부: Needs design  
우선순위: 중간

학생 상세 기능은 쿠폰 관리, 한눈에 보기, 활동 기록, 학생 메시지의 별도 route/page 구조로 분리되었다.
현재 구조를 유지하면서 교사/학생 시점별 사용성과 화면 밀도를 추가로 다듬을 수 있다.

검토할 내용:

- 버튼 문구와 크기
- 모바일 화면에서의 카드 밀도
- 하위 페이지 이동 nav pills의 작은 화면 배치
- 활동 기록 페이지의 기록 탐색 방식

주의:

- 세부 Tailwind class를 먼저 고정하지 않는다.
- 카드 순서와 역할별 노출 정책을 먼저 정한다.

---

## P3. 기록 품질 개선

### 칭찬 메모

상태: Candidate  
확정 여부: Needs design  
우선순위: 중간~낮음

칭찬을 줄 때 짧은 메모를 함께 남길 수 있게 한다.

목적:

- 교사가 학생의 구체적 행동을 기록
- 나중에 상담/생활지도/생활기록부 작성에 활용
- 단순 점수보다 교육적 맥락을 남김

검토할 내용:

- `compliments.memo` 필드를 둘지
- 메모를 학생에게도 보여줄지
- 교사/admin 전용 기록으로 둘지
- 수정/삭제 가능 여부
- 칭찬 타임라인에서 표시할지
- 검색/필터링 대상에 포함할지

---

### Custom 칭찬

상태: Candidate  
확정 여부: Deferred  
우선순위: 낮음

정해진 칭찬 버튼 외에 교사가 직접 칭찬 문장을 작성할 수 있게 한다.

목적:

- 학생별 구체적 행동 기록
- 생활기록부 작성에 도움이 되는 문장 축적
- 긍정 행동 데이터 누적

검토할 내용:

- 자유 입력 칭찬 문장
- category/tag 구조
- 자주 쓰는 칭찬 템플릿
- 학생 공개 여부
- 교사 전용 기록 여부
- export/report 기능과의 연결

주의:

- 너무 빨리 구현하면 입력 부담이 커질 수 있다.
- 먼저 간단한 memo부터 검토하는 것이 안전하다.

---

## Archived / Completed

완료된 항목은 원칙적으로 이 문서에서 제거하고, 현재 동작은 `current_system.md` 또는 관련 spec 문서에 반영한다.

단, 나중에 이력 확인이 꼭 필요한 경우에만 이 섹션으로 옮긴다.

현재는 없음.
