# 학생 명단과 출석번호 정책

## 1. 목적과 범위

이 문서는 교실별 학생 출석번호, 명단 정렬, 등록과 일괄 편집의 현재 정책을 정리한다.

## 2. 데이터 소유권

출석번호는 `User`가 아니라 `ClassroomMembership.student_number`에 저장한다. 학생은 교실마다 다른 membership을 가질 수 있으므로 출석번호는 교실 문맥의 값이다. 기존 데이터와의 호환을 위해 컬럼은 nullable이지만 신규 학생 등록에서는 필수다.

## 3. 출석번호 유효성

값이 있으면 1 이상의 정수여야 한다. 사용자 친화적 오류를 위한 model validation과 경쟁 조건을 막는 DB 제약을 함께 사용한다.

## 4. active/inactive 번호 정책

같은 교실의 active student끼리는 값이 있는 출석번호가 중복될 수 없다. PostgreSQL partial unique index도 student·active·non-null 범위에 이를 보장한다. inactive student끼리와 active/inactive 사이에는 같은 번호를 허용한다.

## 5. 명단 정렬

기본 roster는 번호가 있는 학생을 출석번호 오름차순으로 먼저 표시하고, 번호가 없는 학생을 뒤에 표시한다. 이후 학생 이름, user id, membership id로 안정적인 순서를 만든다.

`all` 필터는 active 그룹을 먼저, inactive 그룹을 다음에 표시하며 각 그룹 안에서 같은 roster 순서를 사용한다.

## 6. 역할과 수정 권한

teacher/admin은 정책상 관리 가능한 교실에서 학생 출석번호를 수정하거나 비울 수 있다. 학생 본인은 번호를 읽을 수 있지만 수정할 수 없고, 학생 PIN 요청에 섞인 출석번호 parameter도 반영하지 않는다. 명단 편집은 현재 교실과 현재 필터의 student membership만 허용하며 다른 교실이나 조작된 membership id를 거부한다.

## 7. 개별 학생 등록과 수정

신규 학생 등록은 출석번호, 이름, 성별, 기본 썸네일과 4자리 PIN을 입력한다. 신규 등록에서 출석번호는 필수다. teacher/admin 편집에서는 legacy 학생을 위해 번호를 새로 지정하거나 변경하거나 빈 값으로 되돌릴 수 있다.

## 8. 여러 학생 등록

학생 수와 공통 4자리 PIN으로 draft를 만들고 각 행에서 출석번호, 이름, 성별과 기본 썸네일을 입력한다. draft 내부 중복과 기존 active 번호 충돌을 검사하며 active 학생 최대 30명을 저장 직전 classroom lock 안에서 다시 확인한다. 전체 transaction으로 저장하므로 한 학생이라도 실패하면 모두 rollback한다. `RecordInvalid`와 `RecordNotUnique`도 입력 화면의 오류로 처리한다.

## 9. 학생 명단 일괄 편집

명단 편집은 출석번호, 이름, 성별과 기본 썸네일을 수정한다. PIN, 학생 상태, 학생 추가·삭제와 업로드 이미지는 수정하지 않는다.

현재 교실과 현재 필터 대상 student membership만 처리한다. 빈 출석번호는 `nil`로 저장한다. 저장 전에 현재 교실 active 학생의 최종 번호 상태를 계산하며 한 행 오류 시 전체 변경을 rollback한다. 오류 응답에는 제출한 입력값과 행별 오류를 유지한다.

## 10. 번호 교환과 순환 변경

두 학생의 번호 교환과 세 학생 이상의 번호 순환 변경을 지원한다. 최종 번호 상태가 유효하면 변경 대상 active 번호를 transaction 안에서 임시로 `nil` 처리한 뒤 최종 번호를 저장해 partial unique index와 충돌하지 않게 한다. User와 membership 변경은 같은 transaction에 포함된다.

## 11. 비활성화와 복구

비활성화할 때 출석번호를 지우지 않는다. inactive 학생은 active 학생과 같은 번호를 가질 수 있다. 복구할 때 active 번호 유일성을 다시 검증하며 같은 번호의 active 학생이 있으면 복구하지 않고 기존 상태를 유지한다.

## 12. 성별과 기본 썸네일

학생 기본 avatar는 성별별 허용 pool을 사용한다. 여러 학생 등록과 명단 편집에서 성별 변경에 맞춰 기본 avatar와 preview를 갱신하며, 유효하지 않은 gender/avatar 조합은 저장하지 않는다.

## 13. legacy avatar 보호

과거 데이터의 gender와 avatar가 일치하지 않아도 이름이나 번호만 수정할 때 기존 avatar를 자동 정리하지 않는다. 성별이 그대로인데 기존 값과 다른 잘못된 avatar를 제출하면 오류로 처리한다. 성별 변경 후 기존 avatar가 새 성별에 유효하면 유지하고, 유효하지 않으면 결정적인 fallback을 배정한다. 업로드 avatar attachment는 detach하거나 purge하지 않는다.

## 14. transaction과 경쟁 조건

개별·여러 학생 등록과 명단 일괄 편집은 관련 User와 membership 변경이 부분 저장되지 않도록 transaction을 사용한다. 학생 수와 번호 상태는 classroom lock 안에서 최종 검증한다. model validation 뒤 발생할 수 있는 `RecordInvalid`와 `RecordNotUnique`도 500 오류 대신 전체 rollback과 사용자 오류로 처리한다.

## 15. 테스트 불변식

다음 동작을 핵심 회귀 대상으로 유지한다.

- active 번호 중복 차단과 inactive 번호 중복 허용
- 출석번호와 상태 그룹별 안정적인 정렬
- 학생 본인의 번호 수정 차단
- 여러 학생 등록의 30명 제한과 전체 rollback
- 번호 교환·순환 변경
- 다른 교실·조작된 membership 차단
- legacy avatar와 업로드 attachment 보존
- 복구 시 번호 충돌
- DB 경쟁 조건의 전체 rollback과 오류 응답
