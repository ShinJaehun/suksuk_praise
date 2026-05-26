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

### Notification

상태: Candidate  
확정 여부: Needs design  
우선순위: 높음

학생/교사 간 상호작용을 알림으로 연결한다.

현재 구현된 범위:

- 학생 쿠폰 사용 요청 badge는 교실 학생 카드에 표시된다.
- 학생 발신 새 메시지 badge는 교실 학생 카드에 표시된다.
- 두 badge는 학생 상세의 쿠폰 영역 또는 메시지 영역으로 이동한다.
- navbar notification/count/list는 아직 만들지 않는다.

후속 후보:

- 교사 navbar unread badge
- 알림 클릭 시 해당 학생 페이지 또는 요청 위치로 이동

검토할 내용:

- 직접 구현할지, gem을 사용할지
- 읽음/안 읽음 상태를 어떻게 관리할지
- 알림 대상자를 message recipient와 분리할지
- 한 교실에 여러 teacher가 있을 때 누구에게 알릴지
- 학생에게도 알림을 보여줄지

초기 정책 후보:

- message recipient는 대표 teacher 1명으로 둔다.
- notification 대상은 같은 교실 teacher 전체로 확장할 수 있다.
- 담임/부담임 정책은 notification 설계 시 함께 검토한다.

spec 승격 후보:

- `docs/specs/notifications.md`

---

## Completed / Archived

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

### 학생 로그인 화면 썸네일 preview

상태: Candidate  
확정 여부: Likely  
우선순위: 중간

학생 PIN 로그인 화면에서 학생을 선택하면 해당 학생의 썸네일을 보여준다.

목적:

- 공용 태블릿 환경에서 학생 선택 실수 감소
- 학생이 자기 계정을 더 쉽게 확인
- 이름이 비슷한 학생이 있을 때 혼동 감소

검토할 내용:

- select 변경 시 썸네일 preview 표시
- JavaScript 없이 기본 렌더링으로 가능한지
- Stimulus controller가 필요한지
- 선택 전 기본 안내 표시
- 접근성/모바일 화면 크기

구현 전 확인:

- `StudentSessionsController`
- `app/views/student_sessions/new.html.erb`
- avatar helper
- 학생 PIN 로그인 request spec

---

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

### 칭찬/쿠폰 화면 UX 개선

상태: Candidate  
확정 여부: Needs design  
우선순위: 중간

칭찬 버튼, 쿠폰 발급, 보유 쿠폰, 최근 발급 쿠폰, 메시지 카드가 한 화면에 모이면서 정보량이 많아졌다.  
교사/학생 시점별로 화면 구조를 더 정리할 필요가 있다.

검토할 내용:

- 교사 로그인 시 학생 상세 카드 순서
- 학생 로그인 시 학생 상세 카드 순서
- 보유 쿠폰 / 최근 발급 쿠폰 구분
- 메시지 카드 위치
- 칭찬 타임라인 위치
- 버튼 문구와 크기
- 모바일 화면에서의 카드 밀도

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
