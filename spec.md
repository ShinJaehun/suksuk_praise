# SPEC — codex_review toolchain smoke test

## 1. Background

현재 상태:
- X201에서 Codex CLI로 작업하고, X220 웹 인터페이스에서 설계/리뷰를 한다.
- spec.md를 X220에서 작성한 뒤 X201로 가져오는(pull_spec) 루프를 안정화하려 한다.

문제:
- 파일 동기화/리뷰 패킷 생성 흐름이 실제로 매끄럽게 돌아가는지 아직 검증되지 않았다.

왜 이 작업이 필요한가:
- “spec → 구현 → commit → send_review → 웹 토론” 루프가 안정적으로 돌아가야 이후 작업(실제 기능 개발)에서 컨텍스트 손실/토큰 낭비가 줄어든다.

---

## 2. Scope (이번 작업 범위)

### 포함
- spec.md를 X220 → X201로 pull_spec으로 동기화하는지 확인
- 작은 무해한 변경 1건을 만들고 커밋한다(예: README/주석/문구 수정)
- send_review가 review 파일을 생성하고 X220로 전송되는지 확인
- 웹(X220)에서 review 파일을 열어 commit message만으로 토론이 가능한지 확인

### 제외 (이번 작업에서 하지 않을 것)
- 도메인 로직 변경
- DB 마이그레이션
- 테스트 코드 대규모 추가/변경
- UI 변경

---

## 3. Constraints (제약 조건)

- 기존 동작 동일 유지 (기능/응답/정책 변화 금지)
- Public interface 변경 금지
- Turbo frame id / Turbo Stream 응답 관례 유지
- Pundit 규칙/스코프 변경 금지
- 위험한 명령(대량 삭제/마이그레이션 등) 금지

---

## 4. Acceptance Criteria (완료 조건)

- [ ] X201에서 `pull_spec` 실행 시, 로컬 프로젝트 루트의 `spec.md`가 overwrite 된다.
- [ ] 아주 작은 변경 1건을 만들고 커밋한다(커밋 메시지는 템플릿 준수).
- [ ] X201에서 `send_review <ref>` 실행 시 review 파일이 생성되고 원격으로 전송된다.
- [ ] X220에서 전송된 review 파일을 열어 “commit message 섹션”만으로 변경 의도를 이해할 수 있다.

---

## 5. Risks / Open Questions

- SSH 키/권한 문제로 pull_spec 또는 scp가 실패할 수 있음
- 원격 경로(~/review_diffs/spec.md, ~/review_diffs) 불일치 가능
- X201에서 실행 위치가 프로젝트 루트가 아니면 작업이 혼란스러울 수 있음
