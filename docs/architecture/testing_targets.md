# Testing Targets

## 목적
이 문서는 현재 `suksuk_praise`에서 테스트 우선순위가 높은 핵심 규칙을 정리한다.

---

## 최우선 테스트 대상

- 쿠폰 발급 규칙
- 쿠폰 사용 규칙
- 같은 기간 중복 발급 방지
- 중복 요청/연타 방지
- 개인 템플릿 weight / active 불변식
- teacher/admin/student 권한 분기
- 핵심 request 응답(Turbo/HTML)

---

## 리팩토링 전에 고정할 것

- issue/use 상태 전이
- weight normalization 결과
- 주요 policy 분기
- draw/use 엔드포인트 동작

---

## 나중으로 미뤄도 되는 것

- 세세한 뷰 구조
- 자주 바뀌는 UI 문구
- low-value 시스템 테스트
