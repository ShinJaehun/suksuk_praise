# SPEC — Coupon Mobile Accessibility & Turbo Consistency Hardening

## 1. Background

현재 상태:
- 모바일/데스크탑 쿠폰 행이 분리되어 있음
- 모바일에서는 icon-only 버튼 사용
- 일부 button_to에 form class="contents" 사용
- Turbo는 프레임 단위로 업데이트됨

문제:
- 모바일 icon-only 버튼에 aria-label 없음 (접근성 문제)
- form contents 사용이 일관되지 않음
- Turbo row 단위 업데이트 가능성에 대한 안정성 점검 필요

왜 이 작업이 필요한가:
- 접근성 보강
- 구조적 안정성 확보
- Turbo 동작과 DOM 구조의 명확성 유지

---

## 2. Scope (이번 작업 범위)

### 포함
- 모바일 icon-only 버튼에 aria-label 추가
- form class="contents" 제거 또는 통일
- Turbo update가 row 단위가 아닌 frame 단위로만 동작함을 확인
- row-level replace가 있다면 모바일/데스크탑 동시 반영 구조 점검

### 제외 (이번 작업에서 하지 않을 것)
- UI 레이아웃 변경
- 비즈니스 로직 수정
- Weight 로직 변경

---

## 3. Constraints (제약 조건)

- 기존 동작 동일 유지
- Public interface 변경 금지
- Turbo frame id 유지
- Pundit 정책 구조 유지
- 기존 테스트 깨지지 않아야 함

---

## 4. Acceptance Criteria (완료 조건)

- [ ] 모바일 icon-only 버튼에 aria-label 존재
- [ ] form contents 사용 제거 또는 완전 통일
- [ ] Turbo update가 모바일/데스크탑 모두 정상 반영됨
- [ ] 데스크탑 테이블 구조 영향 없음

모든 항목이 충족되면 작업 완료로 간주한다.

---

## 5. Risks / Open Questions

- Turbo가 특정 row만 replace하는 로직이 숨어있는가?
- Safari에서 article + turbo replace 동작 문제는 없는가?
