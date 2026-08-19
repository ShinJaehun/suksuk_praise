# Production Checklist

## 이미지/compose

- [ ] commit SHA tag와 `latest`가 동일 image ID를 가리킨다.
- [ ] 현재 이미지의 rollback tag를 보존했다.
- [ ] `docker compose ... config --quiet`가 성공한다.
- [ ] app port가 `127.0.0.1:3000`에만 bind된다.

## Backup

- [ ] PostgreSQL과 Active Storage를 백업했다.
- [ ] gzip/tar 내용을 확인하고 SHA256을 기록했다.

## HTTPS/Host

- [ ] Cloudflare가 Full (strict)이고 `FORCE_SSL=true`이다.
- [ ] HTTPS, HSTS와 secure session cookie가 정상이다.
- [ ] Rails는 `praise.suksukclass.kr`만 허용하고 unknown HTTPS SNI는 거부된다.
- [ ] OCI/host firewall에서 app port 3000이 공개되지 않는다.

## Real IP

- [ ] Cloudflare 요청의 실제 client IP가 Nginx와 Rails `request.remote_ip`에 전달된다.

## Login limiter

- [ ] 로그인과 `UserPasswordAttemptLimiter`의 email + remote IP 제한이 정상이다.
- [ ] 비밀번호 복구 링크가 노출되지 않는다.

## Action Cable

- [ ] `/cable`이 WebSocket 101로 연결되고 Turbo realtime 갱신이 동작한다.

## Rollback

- [ ] 실행 container의 image ID가 배포 대상과 일치한다.
- [ ] 보존한 image tag와 검증된 DB/파일 백업으로 복구할 수 있다.
