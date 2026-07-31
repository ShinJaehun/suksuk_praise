# School And Classroom Boundaries

## 목적

학교는 조직·권한·운영 lifecycle의 상위 경계이며 교실과 교실 운영 기록은 그 아래에 속한다.

```text
School 1 ─ N Classroom

School
└── Classroom
    ├── ClassroomMembership
    ├── Compliment
    ├── Coupon / UserCoupon
    ├── UserMessage
    └── 운영 기록
```

## 교실 경계

- 모든 `Classroom`은 생성 시 하나의 `School`을 가져야 한다.
- 저장된 `Classroom.school_id`는 운영 기록이나 구성원의 유무와 관계없이 변경할 수 없다.
- 학교를 잘못 선택한 빈 교실은 다른 학교로 이동하지 않고 삭제한 뒤 다시 만든다.
- 칭찬, 쿠폰, 메시지와 활동 기록은 생성된 교실에 계속 귀속되며 다른 학교로 옮기거나 재해석하지 않는다.

## 교사 소속과 담당 교실

```text
Teacher 1 ─ 0..1 SchoolMembership
```

teacher 역할의 `ClassroomMembership`은 다음을 모두 만족해야 한다.

- 연결된 `User.role`이 `teacher`다.
- 교사에게 `SchoolMembership`이 있다.
- 교사의 학교와 `Classroom.school_id`가 같다.
- `student_number`가 없다.
- 상태는 `active`다.

교사는 같은 학교의 여러 교실을 담당할 수 있지만 다른 학교의 교실에는 배정할 수 없다. 학교 소속이 없는 teacher 계정 자체는 허용하지만 교실 담당자로 배정할 수 없다.

## 학생의 학교

학생에게 별도 `SchoolMembership`을 만들지 않는다. 학생의 학교는 active student `ClassroomMembership`이 연결하는 교실의 학교를 통해 결정한다.

## 학교 비활성화

학교 비활성화는 기록 삭제가 아니다. 기존 교실과 운영 기록을 보존하면서 신규 로그인과 운영 접근을 차단한다.

## 데이터 감사

다음 명령으로 학교·교실·교사 소속의 기존 데이터 무결성을 확인한다.

```bash
bin/rails school_structure:audit
```

이 task는 데이터를 수정하거나 자동 복구하지 않는 읽기 전용 감사 도구다. 발견된 문제는 보고하고 비정상 종료한다.
