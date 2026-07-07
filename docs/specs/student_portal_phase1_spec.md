# specs/student_portal_phase1.md

# 쑥쑥칭찬통장 — 학생 로그인 이후 마이페이지 중심 구조 전환 Spec

## 목적

이 문서는 학생 로그인 이후의 기본 동선을 **교실 맥락이 있는 학생 상세 화면 중심**으로 전환하기 위한 정책과 상세 동작을 정리한다.
현재 전체 구현 상태 요약은 `docs/architecture/current_system.md`를 참고한다.

이번 작업의 1차 목표는 다음이다.

1. 학생 로그인 후 기본 진입 화면을 교실 맥락이 있는 학생 상세 화면으로 고정
2. 학생은 자기 자신과 관련된 정보만 볼 수 있도록 권한 경계 강화
3. 교사/관리자용 학생 상세 관리와 학생 본인용 마이페이지를 역할별로 분리
4. 이후 학생 상호작용 기능을 붙일 수 있는 학생 상세 화면 구조 안정화

---

## 이번 단계에서 구현하려는 핵심 방향

### 큰 원칙

- **admin / teacher**
  - 기존처럼 관리 화면 중심으로 사용
  - 학생 상세 페이지에서 학생 관리 수행

- **student**
  - 로그인 후 교실 맥락이 있는 자기 학생 상세 화면으로 이동
  - 자기 정보 / 자기 쿠폰 / 자기 상태만 확인
  - 다른 학생 목록, 다른 학생 상세, 교실 전체 관리 기능은 접근 불가

즉, 학생은 현재 단계에서 **“교실 구성원 전체를 보는 사용자”가 아니라 “자기 상태만 확인하는 사용자”**로 간주한다.

---

## 이번 단계의 범위

### 포함

1. 학생 로그인 후 landing page 분리
2. 학생 권한 범위 정리
3. 학생 본인 마이페이지 구조 도입
4. 학생 본인 정보 변경 정책 정리
   - 학생이 직접 변경할 수 있는 값은 PIN으로 제한한다.
   - 학생 PIN 변경은 별도 PIN 변경 페이지에서 처리한다.
   - 학생 이름/email/avatar/password 변경은 self-service로 제공하지 않는다.
   - 학생 기본 정보(name/email/avatar)는 교사/admin의 학생 관리 화면에서 수정한다.
   - 학생 avatar 직접 업로드/커스터마이징은 추후 검토한다.
5. 교사/관리자용 학생 상세 페이지에 관리 액션 배치
   - 이름 수정
   - 이메일 수정
   - 비밀번호 재설정
   - 운영 상태 관리(비활성화/복구)
6. 학생 self page / 교사·관리자용 학생 상세의 역할 분리 강화
7. 교사↔학생 메시지 기능을 수용할 수 있는 구조 정리

### 제외

이번 단계에서는 아래 기능은 **구조만 고려하고 본격 구현은 보류**한다.

1. 쿠폰 사용 요청 notification
2. 교사↔학생 개별 메시지 송수신
3. 학생 간 상호작용
4. 학생이 교실 전체 목록/다른 학생 상세를 탐색하는 기능

---

## 가장 중요한 설계 결정

## 1. 학생 로그인 후 기본 진입 경로

학생 PIN 로그인 후에는 `classrooms#index` 나 특정 `classrooms#show`로 보내지 말고,
**항상 교실 맥락이 있는 자기 학생 상세 화면**으로 보내도록 한다.

예시 방향:

- admin / teacher 로그인 후: 기존 기본 흐름 유지
- student PIN 로그인 후: `classroom_student_path(login_classroom, current_user)`

이번 단계에서는 `/me` 같은 별도 경로를 새로 만들지 않고,
기존 `classroom_students#show`를 학생 본인 화면의 canonical 진입점으로 사용한다.
`/users/:id`는 당장 제거하지 않지만, 학생 본인이 접근하면 가능한 경우 classroom scoped path로 유도한다.

즉:

- student canonical page: `GET /classrooms/:classroom_id/students/:id`
- teacher/admin managed page: `GET /classrooms/:classroom_id/students/:id`

학생 상세 화면의 카드 순서는 개인정보/요약, 보유 쿠폰, 메시지, 쿠폰 로그/칭찬 타임라인 순서를 기준으로 한다.

---

## 2. 학생 권한 경계

학생은 다음만 가능해야 한다.

- 자기 정보 조회
- 자기 PIN 변경
- 자기 쿠폰 조회
- 자기와 관련된 이후 기능(향후: 쿠폰 사용 요청, 담임과 메시지)

학생은 다음이 불가능해야 한다.

- 다른 학생 show/edit/update 접근
- 학생 목록 탐색
- 교실 관리 화면 접근
- 다른 학생 쿠폰/정보 보기
- 관리자/교사용 액션 수행
- 자기 계정 삭제
- Devise registration edit/update 기반 name/email/password self-service 수정
- 자기 avatar 직접 업로드/수정
- 교사/관리자용 학생 상세 경로 접근
- 교사/관리자용 학생 계정 관리 경로 접근
- 학생 비밀번호 재설정/비활성화/복구 같은 관리 액션 수행

학생이 `classrooms#index`, `classrooms#show` 같은 기존 교실 중심 화면으로 직접 접근하더라도,
이번 단계에서는 학생 마이페이지 중심 구조를 우선하므로 자기 마이페이지로 유도하는 방향을 우선 검토한다.

admin / teacher 는 기존 관리 권한을 유지하되,
정책은 현재 문서화된 roles_and_permissions 원칙과 충돌하지 않게 정리한다.

구체적으로 이번 단계에서는 학생이 아래 경로에 접근할 수 없어야 한다.

- `GET /classrooms/:classroom_id/students/:id`
- `GET /classrooms/:classroom_id/students/:id/edit`
- `PATCH /classrooms/:classroom_id/students/:id`
- `PATCH /classrooms/:classroom_id/students/:id/reset_password`
- `PATCH /classrooms/:classroom_id/students/:id/deactivate`
- `PATCH /classrooms/:classroom_id/students/:id/reactivate`

---

## 3. 페이지 역할 분리

이번 작업에서는 아래 두 화면의 역할을 분리해서 생각한다.

### A. 교사/관리자용 학생 상세 페이지

목적: 학생 관리

포함 기능 예시:
- 학생 기본 정보 표시
- 학생 계정 관리 페이지로 이동하는 진입점
- 학생이 보낸 쿠폰 사용 요청을 확인하고 처리할 수 있는 구조
- 교사↔학생 메시지 기능을 수용할 수 있는 구조
- 향후:
  - 구체적인 요청 처리 UI
  - 구체적인 메시지 UI

### A-1. 교사/관리자용 학생 계정 관리 페이지

목적: 학생 계정 관리 액션 분리

포함 기능 예시:
- 이름 수정
- 이메일 수정
- 임시 비밀번호 직접 재설정
- 운영 상태 관리(비활성화/복구)
- 향후:
  - 쿠폰 사용 승인/처리
  - 개별 메시지 보내기

### B. 학생 본인용 마이페이지

목적: 자기 정보 확인과 PIN 변경 진입점 제공

포함 기능 예시:
- 내 이름
- 내 썸네일
- 내 소속 교실(읽기 전용)
- 내 쿠폰 요약
- PIN 변경
- 쿠폰 사용 요청 버튼을 수용할 수 있는 구조
- 교사↔학생 메시지 기능을 수용할 수 있는 구조
- 향후:
  - 구체적인 쿠폰 요청 UI
  - 구체적인 메시지 확인/응답 UI

주의:
- 학생 본인용 마이페이지와 자기 정보 수정 화면에는 계정 삭제 기능을 두지 않는다.
- 학생 운영 상태 변경은 교사/관리자용 학생 관리 액션으로만 제공한다.

중요:
- 교사용 학생 상세와 학생 본인용 페이지를 **억지로 완전히 같은 화면으로 만들려고 하지 말 것**
- 같은 `users#show`를 재사용하더라도, 역할별 노출 요소는 명확히 다르게 유지할 것
- non-nested `users#show`는 self page 중심으로, nested `classroom_student_path`는 관리 상세 중심으로 해석할 것
- 현재 단계에서 URL과 controller 책임은 분리하되,
  이후 쿠폰 사용 요청/메시지 기능을 위해 view도 `users/show` 와 `classroom_students/show` 로 분리하는 방향을 기준으로 둔다.

### C. 학생 썸네일 처리 원칙

아바타 표시는 `User#avatar` Active Storage 첨부와
`avatar_key` 기반 기본 아바타 규칙을 따른다.

학생 self-service 계정 수정 화면은 제공하지 않는다.
아바타 업로드/교체 UI도 학생에게 노출하지 않는다.
실제 업로드/교체 기능은 추후 S3 같은 외부 스토리지 운영을 도입하는 시점에 다시 검토한다.

원칙:

- 업로드한 `avatar`가 있으면 이를 우선 표시한다.
- 업로드한 `avatar`가 없으면 `avatar_key` 기반 기본 아바타를 사용한다.
- 저장소 구현은 Active Storage 기준으로 두고,
  개발/테스트에서는 local/test service를 사용하되 이후 production 에서 S3 같은 외부 스토리지로 교체 가능한 구조를 전제로 한다.
- 학생 name/email/avatar는 교사/admin의 학생 관리 화면에서 수정한다.
- 학생 avatar는 학생 self-service가 아니라 교사/admin 학생 관리 화면에서 제공된 학생용 `avatar_key` 목록(boy/girl 기본 아바타) 중 선택한다.
- 이번 단계에서는 이미지 크롭 UI, 직접 업로드 최적화, 실제 S3 운영 설정, 학생 self-service 업로드 변경 UI까지 포함하지 않는다.

### D. 학생 쿠폰 사용 요청

학생 쿠폰 사용 요청은 현재 구현된 학생 포털 흐름이다.

현재 정책:

- 학생은 자기 `issued` 쿠폰에 대해서만 사용 요청을 만들 수 있다.
- 학생은 쿠폰을 직접 사용 처리하지 않는다.
- 같은 쿠폰에 pending 요청은 하나만 유지한다.
- 교사/admin은 교실 맥락의 학생 상세에서 요청을 승인할 수 있다.
- 교사/admin은 요청 승인과 별개로 학생 쿠폰을 직접 사용 처리할 수 있다.
- 쿠폰 요청 badge는 교실 학생 카드에 표시되며, 학생 상세의 쿠폰 영역으로 이동한다.
- 요청 생성/승인/직접 사용 처리 후 학생 화면과 관리 화면의 쿠폰 목록은 Turbo Streams로 갱신된다.

### E. 교사↔학생 메시지 기능 원칙

교사↔학생 메시지는 현재 구현된 학생 포털 흐름이다.

원칙:

- 메시지 기능은 학생 self page와 교사/관리자용 학생 상세가 서로 다른 목적의 UI를 갖는다는 전제를 따른다.
- 교실별 `message_policy`가 현재 메시지 정책 기준이다.
- `disabled`이면 학생 상세 메시지 영역을 표시하지 않고 root/reply 작성과 새 메시지 badge를 모두 비활성화한다.
- `replies_only`이면 교사/admin root message와 학생 reply를 허용하지만 학생 root message는 막는다.
- `student_initiated`이면 학생이 자기 소속 교실 teacher 전원에게 root message를 시작할 수 있다.
- 학생 발신 unread badge는 teacher별 개인 inbox가 아니라 교실 단위 공동 처리 알림이다.
- teacher/admin 중 누군가 학생 상세에 진입하거나 답변하면 학생 발신 unread 메시지가 read 처리되어 badge가 사라진다.

---

## 구현 우선순위

아래 순서로 작업한다.

### 1단계. 로그인 후 진입 흐름 정리

목표:
- 학생 로그인 시 자기 페이지로 이동
- teacher/admin 기존 흐름 유지

검토 포인트:
- Devise 로그인 후 redirect 훅
- 현재 root / after_sign_in_path_for / dashboard 성격의 로직 위치
- role에 따른 분기 추가

---

### 2단계. 접근 정책 정리

목표:
- 학생은 자기 자신에 대해서만 show/edit/update 가능
- 다른 학생 페이지 접근 차단
- students가 classrooms 관련 관리 페이지에 접근하지 못하도록 제한
- 학생이 교사/관리자용 학생 계정 관리 경로에 접근하지 못하도록 제한

검토 포인트:
- Pundit policy / policy_scope
- controller before_action/authorize
- 기존 users, classrooms, user_coupons 관련 접근 경계 점검
- `classroom_students#show/edit/update/reset_password/destroy` 에 대한 학생 접근 차단 검증

이 단계에서 public behavior 가 바뀌므로,
권한이 분산되어 있으면 가능한 한 controller+policy 기준으로 읽기 쉽게 정리한다.

---

### 3단계. 학생 마이페이지 정리

목표:
- 학생이 로그인하면 도착하는 자기 페이지를 정리
- 학생에게 불필요한 관리 UI 제거
- 자기 정보와 자기 쿠폰 중심으로 화면 구성

포함 후보:
- 프로필 카드
- 썸네일
- 이름
- 교실 정보
- 내 쿠폰 요약

---

### 4단계. 학생 본인 정보 수정

목표:
- 학생 self page에서는 Devise self-service 계정 수정 흐름을 제공하지 않는다.
- 학생이 직접 변경할 수 있는 값은 PIN으로 제한한다.

원칙:
- Rails way 우선
- 학생의 name/email/avatar/password 수정은 self-service로 제공하지 않는다.
- 학생 PIN 변경은 별도 PIN 변경 페이지에서 처리한다.
- 학생 기본 정보(name/email/avatar)는 교사/admin 관리 화면에서 수정한다.
- teacher/admin의 Devise 등록정보 수정과 비밀번호 변경 흐름은 유지한다.

---

### 5단계. 교사/관리자용 학생 관리 버튼 정리

목표:
- 학생 상세 페이지에서 교사/관리자가 학생 계정 관리 페이지로 진입할 수 있도록 UI 정리

우선 고려할 액션:
- 이름 수정
- 이메일 수정
- 비밀번호 재설정
- 운영 상태 관리(비활성화/복구)

원칙:
- 관리용 학생 상세(`classroom_student_path`)는 조회 중심으로 유지한다.
- 실제 계정 수정/비밀번호 재설정/운영 상태 변경은 `classrooms/:classroom_id/students/:id/edit` 에서 처리한다.
- 교사/관리자는 학생 비밀번호를 메일 reset 이 아니라 임시 비밀번호를 직접 설정하는 방식으로 관리한다.

### 6단계. 학생 self page / 교사·관리자용 학생 상세 view 분리

목표:
- 학생 self page와 교사/관리자용 학생 상세가 각자의 상호작용을 자연스럽게 수용하도록 view 책임을 분리한다.

원칙:
- 학생 self page는 자기 상태 확인 중심으로 유지한다.
- 교사/관리자용 학생 상세는 교실 맥락의 학생 관리 중심으로 유지한다.
- 쿠폰 사용 요청과 메시지 기능이 붙는 시점에는 역할별 상호작용을 shared template 조건문으로만 누적하지 않는다.

### 7단계. 학생 쿠폰 사용 요청

상태:
- 현재 구현 완료.
- 상세 정책은 `docs/architecture/current_system.md`와 `docs/architecture/coupons.md`를 기준으로 한다.

현재 동작:
- 학생은 자기 쿠폰에 대해 사용 요청을 만들 수 있다.
- pending 중복 요청과 이미 처리된 쿠폰 요청은 막는다.
- 학생용 요청 버튼과 교사/admin 처리 액션은 역할별로 분리한다.
- 요청 badge는 학생 상세의 쿠폰 영역으로 이동한다.

### 8단계. 교사↔학생 메시지

목표:
- 학생 self page와 교사/관리자용 학생 상세에서 교실 메시지 정책에 맞는 메시지 영역을 제공한다.

현재 동작:
- `message_policy`가 메시지 기능의 기준이다.
- `disabled`이면 메시지 영역과 작성/답장, 새 메시지 badge를 모두 비활성화한다.
- `replies_only`이면 teacher/admin root message와 학생 reply를 허용한다.
- `student_initiated`이면 학생 root message를 교실 teacher 전원에게 생성한다.

---

## 모델/도메인 관점에서 미리 염두에 둘 것

쿠폰 요청과 메시지 기능은 현재 구현되어 있으며, 아래 내용은 후속 확장 후보로만 본다.

### 후속 후보 1: 쿠폰 요청 알림 확장

현재는 교실 학생 카드 badge 수준으로 처리한다.
navbar notification/count/list 같은 범용 알림은 `docs/planning/backlog.md`에서 후속 후보로 관리한다.

### 향후 2: 교사↔학생 메시지 확장

현재는 교사/admin ↔ 학생 메시지와 얕은 root/reply thread만 제공한다.
첨부파일, 검색, 보관, 삭제, 학생↔학생 메시지, 범용 inbox는 후속 후보로 둔다.

---

## 라우트 / 컨트롤러 방향 가이드

구체적 구현은 저장소 구조를 먼저 읽고 결정하되, 다음 원칙을 따른다.

1. **불필요한 새 컨트롤러 남발 금지**
2. 기존 `UsersController`, Devise 관련 흐름을 최대한 활용
3. 이번 단계에서는 `UsersController#show`를 유지하되
   `GET /users/:id`는 self page,
   `GET /classrooms/:classroom_id/users/:id`는 teacher/admin managed page 중심으로 정리한다.
4. 역할 분기는 view 헬퍼나 partial 분리로 읽기 쉽게 유지
5. 뷰에서 `policy(...)` 직접 호출 남발하지 말고,
   현재 프로젝트 원칙에 맞게 controller/helper/local 할당 방식 우선 검토

---

## 테스트 원칙

이번 작업은 권한과 진입 경로가 핵심이므로,
기능 구현 후 아래 테스트를 우선 고려한다.

### 우선순위 높은 테스트

1. 학생 로그인 후 자기 페이지로 redirect 되는지
2. 학생이 다른 학생 페이지 접근 시 차단되는지
3. 학생이 자기 정보 수정은 가능한지
4. teacher/admin 이 학생 관리 페이지 접근 가능한지
5. student 가 교실 관리 화면 접근 시 제한되는지

테스트 철학은 기존 `docs/testing/rspec_strategy.md`를 따른다.

- 설명적인 테스트 이름
- role context 분리
- 핵심 권한/상태 전이 우선
- coverage 수치보다 safety net 중시

---

## Codex 작업 방식 지시

다음 원칙으로 작업할 것.

1. 먼저 저장소를 읽고,
   - 현재 로그인 후 redirect 흐름
   - users/classrooms/policies/devise 관련 구조
   - 학생이 현재 어디까지 접근 가능한지
   를 분석한다.

2. 바로 큰 수정에 들어가지 말고,
   **먼저 변경 계획(diff 요약 수준)** 을 제시한다.

3. 변경은 가능한 한 작은 단계로 나눈다.

권장 작업 단위:

- Step A. 로그인 후 redirect 정리
- Step B. 학생 권한 제한 정리
- Step C. 학생 마이페이지 정리
- Step D. 학생 자기정보 수정
- Step E. 교사용 학생 관리 버튼 정리

4. Rails 관례를 최우선으로 따른다.
5. public behavior 변경이 있는 부분은 이유를 설명한다.
6. 과한 추상화/과한 새 객체 도입은 피한다.
7. 기존 문서(AGENTS.md, architecture docs, testing strategy)를 우선 참조한다.

---

## 이번 작업에서 Codex가 먼저 확인해야 할 질문

코드를 읽은 뒤 아래를 먼저 점검하라.

1. 학생 로그인 후 현재 실제 landing path 는 어디인가?
2. `UsersController#show` 가 이미 self page 와 managed page 를 겸하고 있는가?
3. `ClassroomsController#index/show` 는 student 에게 어디까지 열려 있는가?
4. Pundit policy 에서 student 의 자기 자신 접근 제한이 이미 일부 존재하는가?
5. Devise 등록정보 수정 흐름을 학생 self-edit 에 재사용할 수 있는가?
6. teacher/admin/student 역할 분기를 현재 가장 적은 변경으로 반영할 위치는 어디인가?

---

## 산출물 기대

이번 단계 작업의 기대 결과는 다음과 같다.

- 학생 로그인 시 자기 페이지로 이동한다.
- 학생은 자기 자신 관련 정보만 볼 수 있다.
- 학생 마이페이지가 최소 형태로 정리된다.
- 학생이 직접 변경할 수 있는 값은 PIN 중심으로 제한된다.
- 교사/관리자용 학생 관리 액션의 배치 방향이 정리된다.
- 이후 쿠폰 사용 요청/메시지 기능을 붙일 수 있는 구조가 된다.

---

## 주의사항

- 아직 학생 간 상호작용은 넣지 않는다.
- 학생에게 교실 전체 목록/다른 학생 목록을 굳이 노출하지 않는다.
- teacher/admin/student 의 화면 목적을 섞지 않는다.
- “학생 마이페이지 중심 구조”를 먼저 안정화한 뒤 다음 기능으로 넘어간다.

---

## 한 줄 요약

**이번 작업의 핵심은 학생 로그인 기능 자체가 아니라, 학생을 ‘자기 상태만 보는 사용자’로 재정의하고 그에 맞게 진입 경로·권한·마이페이지 구조를 먼저 고정하는 것이다.**
