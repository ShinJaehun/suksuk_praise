# School Operations Architecture

## 1. 목적과 범위

이 문서는 학교별 권한, 휴무 정보, 운영일 계산과 칭찬왕 연동에 관한 확정 정책을 정리한다.
현재 구현과 이 브랜치에서 단계적으로 구현할 정책을 구분하며, 세부 모델·policy·route 이름은 각 구현 단계에서 현재 Rails 구조에 맞춰 확정한다.

학교 운영 기능은 휴무 여부와 관리 범위를 다룬다. 운동회, 현장체험학습, 교육 행사처럼 정상 등교하는 일정을 포함한 일반 학사일정 시스템은 만들지 않는다.

---

## 2. School의 책임

`School`은 다음 정보의 기준 범위다.

- 교실
- 교사의 학교 소속
- 학교별 관리자 권한
- 학교별 휴무 기간
- 학교 운영일 계산

학교는 칭찬왕을 선정하거나 결과를 보존하지 않는다. 칭찬왕에는 운영일 계산 결과만 제공한다.

---

## 3. global admin과 학교 manager

기존 전역 `User#role`은 `admin`, `teacher`, `student`를 유지하며 `school_manager` 같은 전역 role을 추가하지 않는다.

- global admin은 모든 학교를 관리한다.
- 학교 manager는 전역 role이 `teacher`인 사용자에게 학교 소속 단위로 부여하는 권한이다.
- 한 학교에는 manager가 여러 명 있을 수 있다.
- manager 지정과 해제는 초기에는 global admin만 수행한다.
- manager는 다른 manager를 지정하거나 해제할 수 없다.

학교 manager는 자신이 manager로 소속된 학교에 한해 다음 기능을 관리한다.

- 학교 정보 열람
- 학교별 휴무 기간 등록·수정·삭제
- 해당 학교의 학급 목록·상세 조회
- 해당 학교 학급 생성·기본 정보 수정
- 해당 학교 소속 member/manager 교사의 담당 교사 배정

`SchoolPolicy`와 scope는 일반 teacher와 manager에게 자신의 학교만 노출한다. 일반 teacher는 학교를 열람할 수 있지만 운영 기능을 관리할 수 없고, manager는 자신의 학교 운영 기능만 관리할 수 있다. global admin은 모든 학교를 조회하고 관리한다. 학교 생성·이름 수정·삭제는 global admin 전용이다.

이 policy는 학교 운영 정보와 휴무 기간 controller·route에 연결되어 있다. member는 자신의 학교 현황과 휴무 기간을 읽고, 해당 학교 manager와 global admin은 SchoolClosure를 관리한다. global admin은 manager를 지정·해제할 수 있다. manager는 학급을 다른 학교로 이동할 수 없고, teacher 계정 생성·삭제나 학교 소속 자체 변경은 할 수 없다.

---

## 4. SchoolMembership 역할

`SchoolMembership`은 교사의 학교 소속과 학교 단위 권한을 함께 표현한다.

- `member`: 일반 소속 교사
- `manager`: 해당 학교의 관리 권한을 가진 교사

역할은 integer enum으로 구현되어 있으며 기본값은 `member`다. 현재 교사 한 명은 최대 한 학교에만 소속되고 같은 학교의 여러 학급을 담당할 수 있다. 다른 학교 소속 teacher를 담당 교사로 배정하는 것은 차단하며 여러 학교 소속 지원은 현재 범위가 아니다. 한 학교에는 여러 manager를 둘 수 있고 global admin과 student는 SchoolMembership을 갖지 않는다.

학교 학급의 담당 teacher를 배정할 때 누락된 SchoolMembership을 member로 생성한다. 같은 학교의 기존 member·manager는 유지하고 다른 학교 membership은 validation 오류로 배정을 차단한다. 담당 해제 시에도 소속을 삭제하지 않는다. 기존 데이터는 `bin/rails school_memberships:backfill`로 멱등하게 보완하며 다른 학교 충돌은 변경하지 않고 `conflicts`로 집계한다.

학급 담당 교사는 학급과 같은 학교의 SchoolMembership을 가진 teacher만 가능하다. global admin과 학교 manager 모두 학급 배정 과정에서 미소속 teacher나 다른 학교 소속 teacher의 소속을 생성·변경하지 않으며, 필요한 학교 소속 변경은 교사 수정 화면에서 먼저 수행한다.

---

## 5. 학교별 휴무 기간

학교별 휴무 정보는 종류별 enum이 아니라 이름과 날짜 범위로 관리한다.

```text
SchoolClosure
- school
- name
- starts_on
- ends_on
```

- 방학, 재량휴업일, 임시휴업일과 그 밖에 학교가 쉬는 날짜를 같은 구조로 저장한다.
- 하루짜리 휴무는 시작일과 종료일을 같은 날짜로 저장한다.
- 이름과 시작일·종료일은 필수이며 종료일은 시작일보다 빠를 수 없다.
- 같은 학교의 휴무 기간이 겹치는 것은 허용한다.
- School 삭제는 휴무 기간이 있으면 제한한다.
- 주말 등교일을 운영일로 되돌리는 예외 기능은 초기 범위에 포함하지 않는다.

---

## 6. 공식 공휴일

전국 공휴일은 학교마다 중복 저장하지 않고 공통 데이터로 관리한다.

```text
PublicHoliday
- date
- name
- source
```

- 외부 공식 API의 결과를 DB에 저장하며 화면 요청마다 API를 호출하지 않는다.
- API 호출 실패 시 기존 저장 데이터를 유지한다.
- 올해와 다음 해 데이터를 동기화할 수 있도록 한다.
- 정기 동기화와 global admin의 수동 동기화 가능성을 고려한다.
- 공식 데이터에 아직 반영되지 않은 긴급 휴일은 학교별 휴무 기간으로 임시 보완할 수 있다.
- 제주 학교 홈페이지의 학사일정은 파싱하지 않는다.

`PublicHoliday`는 날짜, 이름, 출처를 로컬 DB에 저장하며 같은 날짜에도 이름이나 출처가 다르면 별도 공휴일로 저장할 수 있다. 동일한 날짜·이름·출처 조합은 중복 저장하지 않는다.

한국천문연구원 특일 정보 OpenAPI client와 연도별 동기화 service가 구현되어 있다. 외부 응답과 XML 파싱이 모두 성공한 뒤 transaction 안에서 해당 연도와 `kasi_special_days` source 데이터만 교체하며, 실패하거나 결과가 비어 있으면 기존 데이터를 유지한다.

동기화에는 `KASI_HOLIDAY_API_KEY` 환경변수가 필요하다. `bin/rails public_holidays:sync`는 현재 연도와 다음 연도를, `bin/rails "public_holidays:sync[2026]"`는 지정 연도만 동기화한다. 관리자 화면, background job과 정기 실행 설정은 아직 구현되지 않았다.

---

## 7. 학교 운영일 계산

운영일 판단은 `SchoolCalendar`에서 계산하며 view나 controller에 분산하지 않는다.

```text
토요일 또는 일요일이면 휴무
PublicHoliday가 해당 날짜에 존재하면 휴무
해당 학교의 SchoolClosure 범위에 포함되면 휴무
그 외에는 학교 운영일
```

현재 다음 동작을 제공한다.

```ruby
school_day?(date)
last_school_day_of_week(date)
last_school_day_of_month(date)
```

현재 계산에는 주말, 전국 공통 PublicHoliday와 해당 학교의 SchoolClosure를 반영한다. SchoolClosure 관리 화면은 구현되었지만 칭찬왕 사용 가능 날짜에는 아직 연결하지 않았다.

---

## 8. 칭찬왕과의 책임 경계

주간·월간 칭찬왕은 `Classroom` 기능이며 학교는 운영일 계산 결과만 제공한다.

- 주간 칭찬왕은 해당 주의 마지막 학교 운영일 00:00부터 그날이 끝날 때까지만 사용할 수 있도록 한다.
- 월간 칭찬왕은 해당 달의 마지막 학교 운영일 00:00부터 그날이 끝날 때까지만 사용할 수 있도록 한다.
- 사용 가능한 날짜에는 결과를 여러 번 열고 닫고 다시 집계할 수 있다.
- 칭찬왕 결과를 공식 수상 결과로 확정하거나 별도 record로 보존하지 않는다.
- 쿠폰 발급 후 순위가 바뀌어도 자동 보정하지 않으며, 추가 지급은 교사가 custom 쿠폰으로 처리한다.
- 사용 가능 날짜를 놓쳐도 소급 선정하거나 미선정 상태를 관리하지 않는다.

현재는 학교 운영일 계산과 이 날짜 제한이 구현되지 않았다. 현재 칭찬왕 동작은 [`weekly_monthly_compliment_king.md`](../specs/weekly_monthly_compliment_king.md)를 참고한다.

---

## 9. 구현 단계

이 브랜치에서는 다음 순서로 진행한다.

1. 학교 운영 정책 문서
2. SchoolMembership manager 역할
3. 학교 manager policy와 scope
4. SchoolClosure 모델과 운영일 계산
5. PublicHoliday 모델과 공식 데이터 동기화
6. 학교 운영 정보와 manager 지정
7. 칭찬왕 사용 가능 날짜 연동
8. 통합 테스트와 문서 동기화

구현 중 확인되는 현재 구조와 의존성에 따라 순서는 작게 조정할 수 있다.

---

## 10. 이번 범위에서 하지 않는 것

- 일반 학사일정과 정상 등교 행사 관리
- 학교 manager의 다른 manager 지정·해제
- 학생 구성원 관리와 쿠폰·칭찬·메시지 등 수업 운영 기능 전체의 manager 권한 확장
- 캘린더형 휴무일 UI
- 교사당 여러 학교 소속
- 주말 등교일 예외
- 학교별 공휴일 중복 저장
- 제주 학교 홈페이지 학사일정 파싱
- 칭찬왕 확정 모델, 소급 선정과 미선정 상태 관리
- 쿠폰 발급 후 순위 변경에 대한 자동 보정
- 공휴일 API 관리 UI와 학교 workspace의 추가 확장
