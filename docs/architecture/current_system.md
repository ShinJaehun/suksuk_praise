# Current System

## 문서 목적

이 문서는 `suksuk_praise`의 현재 구현 상태를 빠르게 파악하기 위한 요약 문서다.

- 후속 작업은 `docs/planning/backlog.md`에 둔다.
- 테스트 작성 원칙과 우선순위는 `docs/testing/rspec_strategy.md`에 둔다.
- 기능별 상세 정책은 `docs/specs/*.md`와 관련 architecture 문서에 둔다.

## 핵심 역할

- `admin`: 전역 관리 권한을 가진다.
- `teacher`: 교실 teacher membership을 기준으로 학생, 칭찬, 쿠폰, 메시지 기능을 사용한다.
- `student`: 본인과 본인이 속한 교실 맥락의 정보만 조회하고 일부 학생용 기능을 사용한다.

## 인증/세션

- root(`/`)는 교사/관리자 로그인 진입으로 사용하며, 비로그인 사용자를 Devise 로그인 화면으로 보낸다.
- admin/teacher는 Devise 로그인을 사용한다.
- student는 root나 `/users/sign_in`에서 로그인하지 않는다.
- student는 일반 Devise 로그인 흐름에서 차단되며, 교실 범위 PIN 로그인으로 접근한다.
- 학생 공개 로그인 URL은 교실별 token URL인 `GET /c/:student_login_token/login`을 사용한다.
- 기존 숫자 id 기반 학생 로그인 route는 호환을 위해 유지되어 있다.
- student PIN 로그인은 교실과 학생 membership, PIN을 확인한다.
- PIN 로그인 성공 시 기존 세션을 reset하고 해당 student로 `sign_in`한다.
- PIN 로그인 성공 후 교실 맥락이 있으면 `classroom_student_path(classroom, student)`로 이동한다.
- student 세션은 `STUDENT_SESSION_TTL`과 `session[:student_last_seen_at]`으로 짧게 관리된다.
- student가 `/users/:id`에 접근할 때 가능한 경우 교실 범위 학생 상세 경로로 redirect한다.
- 잘못되었거나 재발급으로 만료된 학생 로그인 token URL은 학생용 안내 화면을 `404 Not Found`로 보여준다.

## 교실/학생 관리

- 교사와 학생의 관계는 `ClassroomMembership`을 기준으로 한다.
- `School`은 학교 조직의 기준 모델이며, `Classroom`은 전환 기간 동안 optional `school`과 nullable `grade`를 가질 수 있다.
- `Classroom#grade`는 초등학교 기준 1~6 정수만 허용하되, 기존 데이터 이전을 위해 아직 비어 있을 수 있다.
- 전체 admin은 `/classrooms` 관리 허브에서 학교를 추가하고 이름을 수정할 수 있으며, 교실 생성·수정 시 학교와 학년을 지정할 수 있다.
- teacher의 학교 소속은 `SchoolMembership`으로 관리하며, 현재 교사당 한 학교만 허용한다. 학교 미지정 teacher는 허용하고 global admin과 student는 SchoolMembership을 갖지 않는다.
- 담당 학급의 기준은 기존 teacher 역할 `ClassroomMembership`이며, 담당 학년은 연결된 Classroom의 `grade`를 통해 계산하고 별도로 저장하지 않는다.
- teacher 생성 시 기본 개인 쿠폰 준비는 User 생성 transaction 안에서 동기적으로 수행하며, 생성 후 비동기 보정이 아닌 teacher 생성 불변식으로 취급한다. 전체 admin의 교사 생성에서는 User, 기본 개인 쿠폰, 선택적 SchoolMembership을 하나의 transaction으로 처리해 어느 하나라도 실패하면 전체 rollback한다.
- 전체 admin은 교사 생성 modal에서 계정과 학교 소속을 생성하고, 수정 modal에서는 SchoolMembership과 teacher 역할 ClassroomMembership만 관리한다. 수정 endpoint는 이름·이메일·비밀번호·성별·아바타를 변경하지 않는다.
- 교사 수정 시 제출된 담당 교실 ID가 하나라도 존재하지 않거나 admin의 정책 범위 밖이면 학교와 담당 교실 변경 전체를 거부하며, 두 소속 변경은 하나의 transaction으로 처리한다. 학교 소속과 담당 교실의 학교가 달라도 전환 기간에는 저장을 허용하며 별도 경고 badge는 표시하지 않는다.
- SchoolMembership은 담당 교실이나 교실의 학교 변경에 따라 자동 생성·변경·삭제되지 않으며 담당 교사를 자동 해제하지도 않는다.
- teacher가 보낸 교실 `school_id`, `grade` 변경값은 허용하지 않는다. teacher 교실 생성 시 소속 학교 자동 지정은 아직 구현하지 않았다.
- 기존 teacher의 SchoolMembership backfill은 아직 수행하지 않았다.
- 학교 삭제와 school admin 권한은 아직 구현하지 않았다.
- 교실 담당 교사 배정은 admin이 `teacher_ids` 파라미터를 명시적으로 제출했을 때만 변경한다.
- `SchoolClosure`는 학교별 휴무 기간을 이름과 시작일·종료일 범위로 저장한다.
- `PublicHoliday`는 전국 공통 공휴일의 날짜, 이름과 출처를 로컬 DB에 저장한다.
- `SchoolCalendar`는 주말, 전국 공통 공휴일과 해당 학교의 휴무 기간을 기준으로 운영일과 주·월의 마지막 운영일을 계산한다.
- 외부 공식 API 동기화, 휴무일 controller·화면, 칭찬왕 날짜 제한과 학교 중심 관리 화면은 아직 구현되지 않았다.
- 확정된 학교 운영 정책과 단계별 구현 계획은 [`school_operations.md`](school_operations.md)에 정리한다.
- `/classrooms`는 admin의 교실 + 선생님 + 학교 관리 허브 역할을 한다.
- `/classrooms/:id/edit`은 교실 설정, `/classrooms/:id/members`는 구성원 관리 화면이다.
- teacher nav는 담당 교실이 1개이면 해당 교실로 직접 이동하고, 여러 개이면 dropdown으로 담당 교실 목록을 보여준다.
- 교실 이름은 최대 50자로 제한한다.
- teacher/admin은 교실 범위 학생 페이지에서 학생을 조회하고 관리한다.
- 학생 canonical page는 `GET /classrooms/:classroom_id/students/:id`이다.
- 학생의 교실 활동 상태는 `User`가 아니라 `ClassroomMembership.status`로 관리하며, 허용값은 `active`, `inactive`, 기본값은 `active`다.
- `Classroom#students`는 일반 운영 화면에서 사용하는 active 학생 목록이다.
- teacher 교실 화면, 학생 PIN 로그인 목록, 칭찬 대상, 쿠폰 발급 대상, 새 메시지 생성 대상은 active 학생 기준이다.
- 학생은 운영 UI에서 기본적으로 삭제하지 않고 현재 교실 membership을 inactive 처리한다.
- 직접 `DELETE /classrooms/:classroom_id/students/:id` 요청이 들어와도 `User` hard delete 대신 현재 membership을 inactive 처리한다.
- teacher/admin은 구성원 관리 화면에서 학생을 비활성화하거나 inactive 학생을 복구할 수 있다.
- 구성원 관리 화면은 active/inactive 학생 membership을 한 목록에 보여준다.
- inactive 학생은 teacher 기본 교실 화면과 PIN 로그인 목록에서 제외된다.
- 이미 로그인한 학생이 inactive가 되면 다음 요청에서 로그아웃 후 학생 로그인 화면으로 redirect된다.
- inactive 학생은 칭찬, 쿠폰 발급, 새 메시지 발신/수신 대상에서 제외된다.
- inactive 처리 후에도 기존 메시지 thread와 과거 칭찬/쿠폰 기록 조회는 유지된다.
- teacher/admin은 inactive 학생 상세와 활동 기록을 조회할 수 있으며, inactive 학생 상세에서는 `비활성` badge를 표시하고 칭찬하기, 쿠폰 지급, 새 메시지 작성 UI를 숨긴다.
- 구성원 관리 화면에서는 inactive 학생을 흐리게 표시하고 복구 action을 제공한다.
- 학생 self-edit은 차단되어 있으며, 학생이 직접 변경 가능한 값은 PIN 중심이다.
- teacher/admin은 학생의 name, email, gender, avatar_key, PIN 등을 관리한다.
- teacher/admin은 구성원 관리 화면에서 현재 교실의 active 학생 PIN을 한 번에 재설정할 수 있다. inactive 학생 PIN은 일괄 재설정 대상에서 제외하며 기존 PIN 값은 화면에 표시하지 않는다.
- 여러 학생 자동 생성은 한 번에 최대 30명까지 허용한다.
- 여러 학생 자동 생성 제한을 초과하면 Turbo modal content-missing 없이 alert를 표시하고 modal을 닫는다.
- 여러 학생 자동 생성 submit 중에는 modal 입력과 버튼 조작을 잠그고, 응답 실패 시 잠금을 복구한다.
- teacher/admin은 교실 화면에서 학생 로그인 modal을 열어 학생 로그인 URL을 확인할 수 있다.
- 학생 로그인 modal에서는 학생 로그인 URL 복사, QR 코드 보기, QR 코드 다운로드, 학생 로그인 주소 재발급이 가능하다.
- 구성원 관리 화면은 학생 관리 전용으로 사용하며 학생 로그인 URL/QR/재발급 UI와 담당 선생님 배정 form을 표시하지 않는다.
- teacher/admin은 구성원 관리 화면에서 여러 학생 이름을 한 번에 수정할 수 있다.
- 학생 이름 일괄 수정은 현재 교실의 student membership id 기준으로 대상을 제한하며, 하나라도 유효하지 않으면 전체 저장을 rollback한다.
- 학생 로그인 QR은 현재 token URL 기준으로 요청 시 생성하며 서버 파일로 저장하지 않는다.
- 학생 로그인 주소는 재발급할 수 있으며, 재발급 후 기존 URL과 기존 QR은 더 이상 사용할 수 없다.
- 학생 avatar는 `avatar_key` 기반 기본 이미지를 사용한다.
- 학생 PIN 로그인 화면에서 학생을 선택하면 해당 학생의 avatar와 이름을 preview로 표시한다.
- 교실 내 학생 생성/수정 시 gender 기준 avatar_key 선택과 교실 내 중복 회피 흐름이 있다.
- avatar 선택 목록은 역할별로 제한한다: student는 boy/girl, teacher는 teacherM/teacherF, admin은 admin과 teacherM/teacherF 계열을 사용한다.
- `avatar_key`가 현재 역할에서 허용되지 않거나 asset 파일이 없으면 역할별 기본 avatar로 fallback한다: student는 `boy01`, teacher는 `teacherM01`, admin은 `admin`.

## 칭찬

- teacher/admin은 교실 맥락에서 학생에게 compliment를 생성할 수 있다.
- student, guest, 담당 범위 밖 teacher는 compliment를 생성할 수 없다.
- compliment 생성 시 receiver 학생의 points가 증가한다.
- 짧은 시간 안의 같은 giver/receiver/classroom 중복 요청은 차단된다.
- 칭찬 목록과 타임라인은 학생 활동 기록 페이지에서 교실/권한 범위에 맞게 로드된다.
- 일간·주간·월간 칭찬왕 집계는 `ComplimentKings::Pick`이 담당한다.
- 일간은 해당 날짜, 주간은 월요일 시작 주, 월간은 달력 월을 Rails `Time.zone` 기준으로 집계한다.
- 활성 학생만 집계하고 최고 횟수가 같은 학생은 모두 포함한다.
- 교실별로 각 기간을 활성화하거나 비활성화할 수 있으며, 비활성 기간은 서버측 쿠폰 발급에서도 차단한다.
- 칭찬왕 결과는 별도 record로 저장하지 않고 조회할 때마다 다시 계산한다.
- 마지막 학교 운영일 사용 제한은 아직 구현되지 않았다. 상세 정책은 [`weekly_monthly_compliment_king.md`](../specs/weekly_monthly_compliment_king.md)를 참고한다.

## 쿠폰

- coupon template은 teacher personal template과 admin library template으로 구분된다.
- coupon template은 Active Storage `image`가 있으면 이를 우선 표시하고, 없으면 유효한 `default_image_key` asset을 표시한다.
- `default_image_key`가 비어 있거나 실제 asset이 없으면 쿠폰 썸네일 placeholder를 표시한다.
- teacher는 library template을 읽고 personal template으로 adopt할 수 있다.
- personal template에는 active/weight 불변식과 weight normalization 흐름이 있다.
- teacher/admin은 교실 맥락에서 학생에게 coupon draw/issue를 수행할 수 있다.
- 기본 학생 상세 페이지의 공통 학생 정보 카드에는 쿠폰 관리 페이지에서만 teacher/admin용 `쿠폰 지급` 버튼이 표시된다. 한눈에 보기, 활동 기록, 학생 메시지 페이지에는 이 버튼이 반복 노출되지 않는다.
- `쿠폰 지급` 버튼은 Turbo Frame으로 쿠폰 지급 카드를 로드하며, 학생 본인에게는 버튼과 카드가 표시되지 않는다.
- 쿠폰 지급 카드의 `쿠폰 뽑기`는 `policy_scope(CouponTemplate).active` 범위에서 가중치에 따라 template 하나를 뽑아 `issuance_basis: manual`, `basis_tag: default`로 발급한다.
- 쿠폰 지급 카드의 `쿠폰 지급`은 같은 active template 범위에서 선택한 template을 `issuance_basis: manual`, `basis_tag: selected`로 발급한다.
- 담당 teacher는 자기 교실의 active 학생에게만 쿠폰을 지급할 수 있고, admin은 접근 가능한 학생에게 지급할 수 있다. 외부 teacher, student, inactive 학생, 접근할 수 없거나 inactive인 template은 차단된다.
- 교실 페이지의 칭찬왕 쿠폰 발급은 기존처럼 가중치 기반 `쿠폰 뽑기`만 제공하며 선택 지급 UI는 제공하지 않는다.
- 칭찬왕 발급은 issuance basis, basis tag, period 정보로 일간·주간·월간을 구분한다.
- 같은 학생에게 같은 기간의 동일 칭찬왕 쿠폰을 중복 발급하지 않으며, 사용 처리된 쿠폰도 다시 발급하지 않는다.
- 수동·custom 쿠폰 발급은 칭찬왕 기간 활성 설정과 무관하다.
- 학생은 본인의 보유 coupon을 확인할 수 있다.
- `UserCoupon`은 issued/used 상태 전이를 가진다.
- coupon 발급/사용 이벤트는 `CouponEvent`로 기록된다.
- 보유 쿠폰은 기본 학생 상세 페이지인 쿠폰 관리 화면에 표시되고, 최근 발급 쿠폰은 학생 활동 기록 페이지에 표시된다.
- 학생은 쿠폰을 직접 사용 처리하지 않고 쿠폰 사용 요청을 보낸다.
- teacher/admin은 학생의 쿠폰 사용 요청을 승인하거나 학생 쿠폰을 직접 사용 처리할 수 있다.
- 쿠폰 사용 요청 또는 직접 사용 처리 성공 시 학생 화면과 관리 화면의 쿠폰 목록을 Turbo Streams로 갱신한다.
- 학생의 쿠폰 사용 요청은 교실 학생 카드의 쿠폰 요청 badge로 표시된다.
- teacher/admin은 쿠폰 요청 badge를 확인하고 학생 상세에서 승인한다.
- 교실 학생 카드의 쿠폰 요청 badge는 학생 상세의 쿠폰 영역으로 이동한다.
- teacher/admin이 쿠폰을 뽑으면 서버에서는 `draw_coupon` 시점에 쿠폰을 즉시 발급한다.
- teacher/admin 화면의 쿠폰 목록, 최근 발급, KPI는 쿠폰 뽑기 overlay를 닫은 뒤 delayed reveal로 갱신한다.
- 학생 화면의 쿠폰 목록은 teacher/admin이 overlay를 닫은 뒤 `reveal_issue` endpoint가 `student_coupons` stream으로 갱신한다.
- 쿠폰 뽑기 overlay 중에는 teacher/admin 화면 뒤에 새 쿠폰 카드가 먼저 보이지 않아야 한다.

## 메시지

- 교실에는 `message_policy` 설정이 있으며 기본값은 `replies_only`다.
- 과거 boolean 설정은 `message_policy`로 이관 완료되었고, 기존 boolean 컬럼은 제거되었다.
- `disabled`이면 학생/교사/admin 모두 해당 교실의 학생 메시지를 새로 작성하거나 답장할 수 없고, 공통 학생 정보 카드의 학생 메시지 버튼과 교실 학생 카드의 새 메시지 badge를 표시하지 않는다.
- `disabled`인 교실의 학생 메시지 페이지에 직접 접근하는 것도 차단한다.
- `replies_only`이면 teacher/admin은 학생에게 새 root message를 보낼 수 있고, student는 기존 root thread에만 답장할 수 있다.
- `student_initiated`이면 `replies_only` 흐름에 더해 student가 자기 소속 교실 teacher 전원에게 새 root message를 시작할 수 있다.
- student root message는 전송 1회당 단일 root thread로 생성된다. 필수 recipient에는 교실 teacher 중 정렬상 첫 teacher를 사용하며 admin에게 자동 발송하지 않는다.
- 같은 교실의 teacher와 admin은 root message의 recipient 여부와 관계없이 학생의 단일 thread를 공동 조회하고 답변할 수 있다.
- 기존 root thread reply는 `disabled`가 아닌 교실에서 thread 참여/관리 권한 기준으로 허용된다.
- 답글의 답글은 허용하지 않는다.
- teacher/admin은 관리 가능한 학생의 메시지 전용 페이지에서 thread별 reply를 작성할 수 있다.
- 메시지 UI는 root/reply form과 compact thread display 구조를 사용한다.
- 일반 SNS식 navbar notification/count/list는 제공하지 않는다.
- 학생 발신 미확인 메시지가 있으면 teacher/admin이 보는 교실 학생 카드에 새 메시지 badge를 표시한다.
- 새 메시지 badge/read 처리는 teacher별 개인 inbox가 아니라 교실 단위 공동 처리 상태다.
- teacher/admin 중 누군가 학생 상세나 메시지 전용 페이지를 열거나 메시지에 답변하면 학생 발신 unread 메시지를 read 처리해 badge가 사라진다.
- 학생 본인이 자기 화면을 여는 것은 학생 발신 unread 메시지를 read 처리하지 않는다.
- 쿠폰 요청 badge와 메시지 badge는 `users/_student_card_alerts.html.erb` alert 영역을 공유한다.
- 실시간 갱신은 Turbo Streams broadcast로 해당 학생의 alert 영역만 replace한다.
- 새 메시지 badge는 해당 학생의 메시지 전용 페이지로 이동한다.
- 현재 학생 카드 알림은 pending 쿠폰 사용 요청과 학생 발신 unread 메시지만 다룬다.
- 별도 Notification 모델, 알림 목록, teacher별 개인 inbox, navbar 알림은 구현되어 있지 않다.
- 특정 쿠폰 요청이나 특정 메시지 item으로 이동하는 deep link는 아직 MVP 범위 밖이다.

## 학생 상세 화면

- 교실 범위 학생 화면은 하나의 긴 화면이 아니라 별도 route/page 구조로 나뉜다.
- 기본 학생 상세 페이지 `GET /classrooms/:classroom_id/students/:id`는 쿠폰 관리 화면이다. 학생 정보 카드와 KPI, 보유 쿠폰, pending 쿠폰 사용 요청 및 teacher/admin의 승인 흐름을 보여준다.
- 특정 학생 한눈에 보기 `GET /classrooms/:classroom_id/students/:id/dashboard`는 URL의 classroom과 student를 기준으로 선택한 주의 활동을 보여준다.
- 학생 활동 기록 `GET /classrooms/:classroom_id/students/:id/activity`는 최근 발급 쿠폰과 칭찬 타임라인을 보여준다.
- 학생 메시지 `GET /classrooms/:classroom_id/students/:student_id/messages`는 메시지 작성 폼과 기존 thread를 보여주며 기존 POST 메시지 흐름을 유지한다.
- 네 페이지는 학생 avatar, 이름, 반 이름, KPI badge와 하위 페이지 이동 nav pills를 포함한 공통 학생 정보 카드를 사용한다.
- nav pills는 쿠폰 관리, 한눈에 보기, 활동 기록, 학생 메시지 순서이며 현재 페이지를 active 상태로 표시한다.
- 학생도 하위 페이지 이동 nav pills를 사용할 수 있다. `message_policy`가 `disabled`이면 학생 메시지 버튼은 표시하지 않는다.
- teacher/admin에게는 학생 정보·PIN 수정, 칭찬하기, 교실로 돌아가기 관리 버튼이 추가로 노출된다. 쿠폰 지급 버튼은 쿠폰 관리 페이지에서 권한이 있을 때만 표시된다.
- student에게는 teacher/admin 관리 버튼이 노출되지 않는다.
- 담당 범위 밖 teacher의 접근은 차단하고 admin은 전역 범위에서 접근할 수 있다.

## dashboard

- dashboard는 `GET /dashboard`의 `한눈에 보기` 화면이며 현재 사용자 role에 따라 내용을 나눈다.
- student dashboard는 PIN 로그인 세션의 active classroom membership을 기준으로 현재 교실의 활동을 표시한다.
- student dashboard는 `week_offset` query parameter로 이전 주와 다음 주를 이동하며, 선택한 주의 월요일부터 금요일까지를 집계 범위로 사용한다.
- student dashboard 상단에는 현재 교실에서 지금까지 받은 칭찬, 선택한 주에 받은 칭찬, 현재 보유 쿠폰, 선택한 주에 발급받은 쿠폰과 사용한 쿠폰 수를 5칸 summary panel로 표시한다.
- 선택한 주의 날짜별 칭찬 수는 자동 조정되는 y축 눈금과 곡선형 SVG 그래프로 표시한다.
- 선택한 주에 쿠폰을 발급받은 날은 `🎁`, 쿠폰을 사용한 날은 `✅` marker를 해당 날짜의 그래프 점 근처에 표시한다.
- 선택한 주에 칭찬과 쿠폰 발급/사용 활동이 모두 없으면 데이터 선, 점, marker, y축 숫자를 표시하지 않고 요일과 날짜가 있는 빈 그래프 배경을 유지한다.
- student dashboard의 주간 집계에서는 다른 교실, 다른 학생, 주말 활동을 제외한다.
- 기존 학생 로그인용 `GET /dashboard`는 유지된다.
- 특정 학생 한눈에 보기 `GET /classrooms/:classroom_id/students/:id/dashboard`는 기존 student dashboard와 같은 주간 집계와 화면을 재사용하되, `current_user`가 아니라 URL의 classroom과 student를 집계 대상으로 사용한다.
- 특정 학생 한눈에 보기도 `week_offset`, 월요일부터 금요일까지의 집계, 5칸 summary panel, 자동 y축 눈금, 곡선형 SVG 그래프, 쿠폰 발급/사용 marker와 활동 없는 주 표시를 지원한다.
- teacher dashboard는 담당 교실별 학생 수, 오늘 칭찬 수, pending 쿠폰 요청 수, 학생 발신 unread 메시지 수와 교실 이동 링크를 표시한다.
- admin dashboard는 전체 교실 수, 교사 수, 학생 수, pending 쿠폰 요청 수를 표시한다.

## 테스트 상태

- student PIN/auth, student portal, classroom student management, message, coupon, compliment, policy/scope, Turbo/HTML 핵심 흐름에 대한 RSpec 파일이 존재한다.
- 테스트 작성 원칙과 우선순위는 `docs/testing/rspec_strategy.md`를 기준으로 한다.
