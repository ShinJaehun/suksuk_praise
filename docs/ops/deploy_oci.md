# DEPLOY_OCI.md

## 목적
이 문서는 `suksuk_praise`를 **OCI(Oracle Cloud Infrastructure)** 에 배포하기 전에,
로컬 Docker 검증 결과와 다음 작업 순서를 정리한 배포 메모다.

---

## 현재 완료된 상태

- Docker 설치 완료
- `Dockerfile` 기반 이미지 빌드 성공
- `compose.yml`로 `web` + `db` 실행 성공
- PostgreSQL 컨테이너 연결 성공
- `RAILS_ENV=production` 부팅 성공
- `SECRET_KEY_BASE` 환경변수 필요 확인
- `config.force_ssl`을 env 기반으로 제어하도록 조정
- 로그인 화면 렌더링 성공
- 실제 로그인 성공

---

## `.env` 와 `.env.example` 원칙

실제 민감값은 `.env`에 둔다.
저장소에는 값이 비어 있는 `.env.example`만 커밋한다.

### `.env.example` 예시

```env
SECRET_KEY_BASE=
SUKSUK_PRAISE_DATABASE_PASSWORD=
FORCE_SSL=false
```

### 원칙

- `.env`는 커밋하지 않는다
- `.env.example`은 필요한 키 목록만 보여준다
- 운영 서버에서는 별도의 실제 `.env`를 작성한다

---

## 현재 로컬 실행 절차

### 이미지/컨테이너 실행

```bash
docker compose up -d --build
```

### DB 준비

```bash
docker compose run --rm web bin/rails db:prepare
```

### 접속 확인

브라우저:
```text
http://localhost:3000
```

또는:

```bash
curl -I http://localhost:3000
```

---

## 현재 compose 구조

최소 구성:

- `db`: postgres:16
- `web`: Rails production container

아직 포함하지 않은 것:

- reverse proxy
- HTTPS 종료
- OCI 도메인 연결
- object storage
- 다른 Rails 앱 통합 운영

---

## OCI 배포의 다음 단계

다음 단계는 크게 아래 순서로 진행한다.

### 1. 로컬 구성 정리
- `.env.example` 추가
- 배포 문서 정리
- compose 재검증
- `git status` 깨끗한지 확인

### 2. OCI VM 준비
- 기존 OCI VM 재사용 여부 결정
- 공인 IP 확인
- SSH 접속 확인
- Docker / Compose 설치

### 3. 서버에 프로젝트 배치
- 서버에는 compose.prod.yml과 서버용 .env만 준비
- ghcr.io 에서 이미지 pull
- docker compose -f compose.prod.yml up -d
- 필요 시 db:prepare 실행

### 4. 외부 공개 준비
- reverse proxy 추가
- 도메인 연결
- HTTPS 적용
- 그 다음 `FORCE_SSL=true` 전환 검토

---

## 서버용 `.env` 최소 항목

예시 키 목록:

```env
SECRET_KEY_BASE=...
SUKSUK_PRAISE_DATABASE_PASSWORD=...
FORCE_SSL=true
```

주의:
- 운영용 `SECRET_KEY_BASE`는 로컬과 다른 값 사용
- 운영 DB 비밀번호는 강한 값 사용
- HTTPS 적용 전에는 `FORCE_SSL=false`로 둘 수도 있음

---

## 체크 포인트

OCI로 넘어가기 전에 아래는 다시 확인한다.

- [ ] `.env`가 git에 포함되지 않는가
- [ ] `.env.example`이 존재하는가
- [ ] `docker compose up -d --build`가 재현 가능한가
- [ ] 로그인까지 정상 동작하는가
- [ ] `compose.yml`에 민감값 하드코딩이 없는가

---

## 참고

이번 Docker 검증 과정에서 확인된 중요한 점:

- `simple_form`이 production 의존성으로 명시되어야 함
- `database.yml`은 production에서 env 기반 구성이 적절함
- 로컬 Docker 검증 단계에서는 `force_ssl`을 env로 제어하는 편이 좋음

이 문서는 OCI 실제 배포 작업의 출발점으로 사용한다.
