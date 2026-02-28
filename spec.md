# SPEC 4 — 학생 화면 “칭찬하기” Turbo 로그 추가 + 하이라이트

## 1. Background

현재 상태:
- 학생 상세 화면: `/classrooms/:classroom_id/users/:id` (예: `/classrooms/1/users/9`)에서
  - 보유 쿠폰(사용) / 최근 발급 쿠폰 / 칭찬 타임라인 섹션이 렌더링된다.
- 쿠폰 발급/사용은 Turbo Stream으로 프레임을 갱신하며, 효과 트리거는 `turbo_stream.append "effects"` 패턴을 사용한다.
- 하이라이트는 `highlight_controller`가 `data-highlight-id-value`로 DOM id를 찾아 1초 강조 후 트리거 노드를 제거(cleanup)한다.
- 칭찬 타임라인은 현재 서버 렌더링된 리스트(또는 테이블)로만 표시되며, “즉시 칭찬 로그 추가” 액션 버튼은 없다(또는 Turbo로 연결되어 있지 않다).

문제:
- 교사가 학생 화면에서 즉시 “칭찬하기”를 누르고 기록을 남겼을 때,
  타임라인에 로그가 **즉시 반영되지 않거나**(전체 새로고침 필요),
  반영되더라도 방금 추가된 항목이 **시각적으로 구분되지 않는다**.

왜 이 작업이 필요한가:
- 교실 운영 UX에서 “칭찬 클릭 → 즉시 기록 확인” 피드백 루프를 만든다.
- 기존 Turbo/Effects/Highlight 패턴을 재사용하여 일관성을 유지한다.

---

## 2. Scope (이번 작업 범위)

### 포함

#### A) 학생 화면에 “칭찬하기” 버튼 추가
- 경로: `/classrooms/:classroom_id/users/:id`
- 버튼 클릭 시 서버에 “칭찬 생성(create)” 요청을 보낸다.
- 버튼은 Turbo 요청을 사용하며, 중복 제출 방지는 기존 `disable-on-submit` 패턴을 따른다.

#### B) Turbo Stream으로 칭찬 타임라인 즉시 갱신
- 칭찬 생성 성공 시:
  - 칭찬 타임라인 프레임(또는 컨테이너)을 Turbo Stream으로 갱신(append 또는 update)한다.
  - “방금 생성된 칭찬” 항목이 타임라인에 즉시 나타나야 한다.

#### C) 방금 추가된 칭찬 로그 하이라이트
- 성공 시 `turbo_stream.append "effects"`로 highlight 트리거를 추가한다.
- 타겟은 “방금 생성된 칭찬 로그 row DOM id”를 사용한다.
- `highlight_controller`는 기존과 동일하게:
  - 오버레이가 떠 있으면 대기(있을 경우)
  - 대상 element에 highlight 적용 후 1초 뒤 제거
  - trigger 노드는 cleanup으로 누적 방지

#### D) Effects cleanup 보장
- highlight 트리거는 반드시 self-remove되어 `#effects` 하위에 누적되지 않는다.

### 제외 (이번 작업에서 하지 않을 것)
- 칭찬 도메인 모델/정책의 대규모 리팩토링
- 칭찬 편집/삭제 기능
- 실시간 방송(ActionCable/WebSocket) 도입
- 타임라인 UI 레이아웃 대규모 변경(최소 변경으로 버튼/프레임만 추가)

---

## 3. Constraints (제약 조건)

- 기존 동작 동일 유지 (기존 쿠폰 기능/프레임/애니메이션 영향 없음)
- Public interface 변경 금지 (기존 URL/프레임 id 유지)
- Turbo frame id 유지 (칭찬 타임라인 영역에 안정적인 frame/container id 유지)
- Pundit 정책 구조 유지 (칭찬 생성 권한은 기존 정책을 따른다)
- 기존 테스트 깨지지 않아야 함
- `effects` 트리거 누적 방지 (cleanup 필수)

---

## 4. Acceptance Criteria (완료 조건)

- [ ] `/classrooms/:classroom_id/users/:id` 화면에 “칭찬하기” 버튼이 노출된다. (권한 조건이 있다면 해당 조건에 맞게 노출)
- [ ] 버튼 클릭 시 칭찬 로그가 DB에 생성된다.
- [ ] 생성 직후 칭찬 타임라인 영역이 Turbo Stream으로 즉시 갱신된다.
- [ ] 방금 생성된 칭찬 항목이 타임라인에서 1초간 highlight 된다.
- [ ] highlight 트리거 노드는 DOM에서 제거되어 `#effects` 하위에 누적되지 않는다.
- [ ] 중복 클릭/연타 시 UX가 깨지지 않는다(기존 disable-on-submit 패턴 준수).

모든 항목이 충족되면 작업 완료로 간주한다.

---

## 5. Risks / Open Questions

- 칭찬 타임라인이 현재 “프레임 없음/단순 반복 렌더”라면, 안정적인 Turbo 갱신을 위해 frame id(예: `dom_id(@user, :compliments)` 또는 `dom_id(@classroom, :compliments_for_user_#{@user.id})`)를 추가해야 할 수 있다.
- 칭찬 항목 row에 안정적인 DOM id가 없으면(예: `<div id="<%= dom_id(c) %>">`), highlight 타겟 지정을 위해 id 추가가 필요하다.
- 동일 화면에서 쿠폰 애니메이션 오버레이와 타임라인 하이라이트가 동시에 발생할 수 있는지, 발생한다면 대기 로직이 UX에 영향을 주는지 확인이 필요하다.
