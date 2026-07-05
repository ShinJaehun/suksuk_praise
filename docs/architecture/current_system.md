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
- `/classrooms`는 admin의 교실 + 선생님 관리 허브 역할을 한다.
- `/classrooms/:id/edit`은 교실 설정, `/classrooms/:id/members`는 구성원 관리 화면이다.
- teacher nav는 담당 교실이 1개이면 해당 교실로 직접 이동하고, 여러 개이면 dropdown으로 담당 교실 목록을 보여준다.
- 교실 이름은 최대 50자로 제한한다.
- teacher/admin은 교실 범위 학생 페이지에서 학생을 조회하고 관리한다.
- 학생 canonical page는 `GET /classrooms/:classroom_id/students/:id`이다.
- 학생의 교실 활동 상태는 `User`가 아니라 `ClassroomMembership.status`로 관리하며, 허용값은 `active`, `inactive`, 기본값은 `active`다.
- `Classroom#students`는 일반 운영 화면에서 사용하는 active 학생 목록이다.
- teacher 교실 화면, 학생 PIN 로그인 목록, 칭찬 대상, 쿠폰 발급 대상, 새 메시지 생성 대상은 active 학생 기준이다.
- 기록 없는 단일 소속 학생 삭제 요청은 `User` hard delete로 처리한다.
- 현재 교실 기록이 있는 학생 삭제 요청은 `User`를 삭제하지 않고 현재 membership을 inactive 처리한다.
- 다른 교실 소속이 있는 학생은 `User`를 삭제하지 않고 현재 membership만 제거하며, 현재 교실 기록이 있으면 inactive 처리한다.
- inactive 학생은 teacher 기본 교실 화면과 PIN 로그인 목록에서 제외된다.
- 이미 로그인한 학생이 inactive가 되면 다음 요청에서 로그아웃 후 학생 로그인 화면으로 redirect된다.
- inactive 학생은 칭찬, 쿠폰 발급, 새 메시지 발신/수신 대상에서 제외된다.
- inactive 처리 후에도 기존 메시지 thread와 과거 칭찬/쿠폰 기록 조회는 유지된다.
- admin 구성원 관리 화면에서는 inactive 학생도 흐리게 표시하고 `비활성` badge를 붙인다.
- 학생 self-edit은 차단되어 있으며, 학생이 직접 변경 가능한 값은 PIN 중심이다.
- teacher/admin은 학생의 name, email, gender, avatar_key, PIN 등을 관리한다.
- 여러 학생 자동 생성은 한 번에 최대 30명까지 허용한다.
- 여러 학생 자동 생성 제한을 초과하면 Turbo modal content-missing 없이 alert를 표시하고 modal을 닫는다.
- 여러 학생 자동 생성 submit 중에는 modal 입력과 버튼 조작을 잠그고, 응답 실패 시 잠금을 복구한다.
- teacher/admin은 `classrooms/:id/members` 구성원 관리 화면에서 학생 로그인 URL을 확인할 수 있다.
- 구성원 관리 화면에서는 학생 로그인 URL 복사, QR 코드 보기, QR 코드 다운로드가 가능하다.
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
- 칭찬 목록과 타임라인은 학생 상세 화면에서 교실/권한 범위에 맞게 로드된다.

## 쿠폰

- coupon template은 teacher personal template과 admin library template으로 구분된다.
- coupon template은 Active Storage `image`가 있으면 이를 우선 표시하고, 없으면 유효한 `default_image_key` asset을 표시한다.
- `default_image_key`가 비어 있거나 실제 asset이 없으면 쿠폰 썸네일 placeholder를 표시한다.
- teacher는 library template을 읽고 personal template으로 adopt할 수 있다.
- personal template에는 active/weight 불변식과 weight normalization 흐름이 있다.
- teacher/admin은 교실 맥락에서 학생에게 coupon draw/issue를 수행할 수 있다.
- 학생은 본인의 보유 coupon을 확인할 수 있다.
- `UserCoupon`은 issued/used 상태 전이를 가진다.
- coupon 발급/사용 이벤트는 `CouponEvent`로 기록된다.
- 최근 발급 쿠폰과 보유 쿠폰 카드는 학생 상세 화면에 표시된다.
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
- `disabled`이면 학생/교사/admin 모두 해당 교실의 학생 메시지를 새로 작성하거나 답장할 수 없고, 학생 상세 메시지 영역과 새 메시지 badge를 표시하지 않는다.
- `replies_only`이면 teacher/admin은 학생에게 새 root message를 보낼 수 있고, student는 기존 root thread에만 답장할 수 있다.
- `student_initiated`이면 `replies_only` 흐름에 더해 student가 자기 소속 교실 teacher 전원에게 새 root message를 시작할 수 있다.
- student root message는 teacher마다 별도 root thread로 생성되며 admin에게는 자동 발송하지 않는다.
- 기존 root thread reply는 `disabled`가 아닌 교실에서 thread 참여/관리 권한 기준으로 허용된다.
- 답글의 답글은 허용하지 않는다.
- teacher/admin은 관리 가능한 학생 상세 화면에서 thread별 reply를 작성할 수 있다.
- 메시지 UI는 root/reply form과 compact thread display 구조를 사용한다.
- 일반 SNS식 navbar notification/count/list는 제공하지 않는다.
- 학생 발신 미확인 메시지가 있으면 teacher/admin이 보는 교실 학생 카드에 새 메시지 badge를 표시한다.
- 새 메시지 badge/read 처리는 teacher별 개인 inbox가 아니라 교실 단위 공동 처리 상태다.
- teacher/admin 중 누군가 학생 상세를 열거나 메시지에 답변하면 학생 발신 unread 메시지를 read 처리해 badge가 사라진다.
- 학생 본인이 자기 화면을 여는 것은 학생 발신 unread 메시지를 read 처리하지 않는다.
- 쿠폰 요청 badge와 메시지 badge는 `users/_student_card_alerts.html.erb` alert 영역을 공유한다.
- 실시간 갱신은 Turbo Streams broadcast로 해당 학생의 alert 영역만 replace한다.
- 새 메시지 badge는 학생 상세의 메시지 영역으로 이동한다.
- 현재 학생 카드 알림은 pending 쿠폰 사용 요청과 학생 발신 unread 메시지만 다룬다.
- 별도 Notification 모델, 알림 목록, teacher별 개인 inbox, navbar 알림은 구현되어 있지 않다.
- 특정 쿠폰 요청이나 특정 메시지 item으로 이동하는 deep link는 아직 MVP 범위 밖이다.

## 학생 상세 화면

- 학생 상세 화면은 개인정보/요약, 보유 쿠폰, 메시지, 최근 발급 쿠폰, 칭찬 타임라인을 함께 보여준다.
- teacher/admin에게는 학생 관리, 칭찬, 쿠폰 관련 버튼이 노출된다.
- student에게는 관리 버튼과 교실로 돌아가기 버튼이 노출되지 않는다.
- 역할별 노출은 controller/helper/partial 흐름을 통해 관리한다.

## dashboard

- dashboard는 `GET /dashboard`의 `한눈에 보기` 화면이며 현재 사용자 role에 따라 내용을 나눈다.
- student dashboard는 PIN 로그인 세션의 active classroom membership을 기준으로 현재 교실의 활동을 표시한다.
- student dashboard는 `week_offset` query parameter로 이전 주와 다음 주를 이동하며, 선택한 주의 월요일부터 금요일까지를 집계 범위로 사용한다.
- student dashboard 상단에는 현재 교실에서 지금까지 받은 칭찬, 선택한 주에 받은 칭찬, 현재 보유 쿠폰, 선택한 주에 발급받은 쿠폰과 사용한 쿠폰 수를 5칸 summary panel로 표시한다.
- 선택한 주의 날짜별 칭찬 수는 자동 조정되는 y축 눈금과 곡선형 SVG 그래프로 표시한다.
- 선택한 주에 쿠폰을 발급받은 날은 `🎁`, 쿠폰을 사용한 날은 `✅` marker를 해당 날짜의 그래프 점 근처에 표시한다.
- 선택한 주에 칭찬과 쿠폰 발급/사용 활동이 모두 없으면 데이터 선, 점, marker, y축 숫자를 표시하지 않고 요일과 날짜가 있는 빈 그래프 배경을 유지한다.
- student dashboard의 주간 집계에서는 다른 교실, 다른 학생, 주말 활동을 제외한다.
- teacher dashboard는 담당 교실별 학생 수, 오늘 칭찬 수, pending 쿠폰 요청 수, 학생 발신 unread 메시지 수와 교실 이동 링크를 표시한다.
- admin dashboard는 전체 교실 수, 교사 수, 학생 수, pending 쿠폰 요청 수를 표시한다.
- 학생 상세 페이지는 쿠폰, 메시지, 칭찬 타임라인 등 상세 기록 중심으로 유지한다.

## 테스트 상태

- student PIN/auth, student portal, classroom student management, message, coupon, compliment, policy/scope, Turbo/HTML 핵심 흐름에 대한 RSpec 파일이 존재한다.
- 테스트 작성 원칙과 우선순위는 `docs/testing/rspec_strategy.md`를 기준으로 한다.
