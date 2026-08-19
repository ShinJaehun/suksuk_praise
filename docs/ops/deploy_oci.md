# OCI Production Deploy Runbook

## Production 구성

2026-08-19 기준 운영 요청 경로는 다음과 같다.

```text
Cloudflare
→ Nginx 443
→ 127.0.0.1:3000 Rails
```

- 공식 도메인은 `praise.suksukclass.kr`이다.
- Cloudflare SSL/TLS는 Full (strict)를 사용한다.
- Rails는 `FORCE_SSL=true`와 `config.hosts = ["praise.suksukclass.kr"]`로 실행한다.
- Docker app port는 localhost에만 bind하며 OCI/host firewall에서 3000을 직접 공개하지 않는다.
- Nginx는 Cloudflare의 검증된 요청에서 실제 client IP를 복원하고, 알 수 없는 HTTPS SNI는 거부한다.
- `.env`, Cloudflare Origin private key 등 secret은 저장소에 두지 않는다.
- 이메일 발송과 Devise password recovery는 사용하지 않는다.

## 최초 DB 준비

새 production DB를 처음 준비할 때만 DB와 schema를 준비하고 최초 관리자를 생성한다.

```bash
docker compose -p suksuk_praise --env-file .env -f compose.prod.yml up -d db
docker compose -p suksuk_praise --env-file .env -f compose.prod.yml run --rm web bin/rails db:prepare
docker compose -p suksuk_praise --env-file .env -f compose.prod.yml run --rm web bin/rails app:bootstrap
docker compose -p suksuk_praise --env-file .env -f compose.prod.yml up -d web
```

`app:bootstrap`은 최초 설정 전용이며 일반 재배포에서는 실행하지 않는다.

## 일반 재배포

1. commit SHA 기반 immutable tag와 `latest`를 동일 이미지로 build/push한다.
2. 현재 실행 이미지를 rollback tag로 보존한다.
3. 새 이미지와 compose 파일을 준비하고 다음 명령으로 구성을 검증한다.

   ```bash
   docker compose -p suksuk_praise --env-file .env -f compose.prod.yml config --quiet
   ```

4. 일관된 백업이 필요하면 web을 중지한다.
5. PostgreSQL dump와 Active Storage 파일을 백업한다.
6. DB 백업은 gzip 무결성을, 파일 백업은 tar 목록을 확인하고 각각 SHA256을 기록한다.
7. migration이 있을 때만 새 이미지로 `bin/rails db:prepare`를 실행한다.
8. web container를 새 이미지로 recreate한다.
9. 실행 중인 container의 image ID가 배포 대상과 일치하는지 확인한다.
10. HTTPS/HSTS, Host 제한, 로그인, Action Cable WebSocket과 Turbo realtime 갱신을 smoke test한다.

문제 발생 시 보존한 rollback tag로 web을 recreate한다. 데이터 변경을 되돌려야 한다면 검증된 PostgreSQL 및 Active Storage 백업을 사용한다.
