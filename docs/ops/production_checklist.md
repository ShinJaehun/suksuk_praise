# Production Checklist

## 배포 전

- `.env`가 커밋되지 않았는지 확인
- production용 secret이 올바른지 확인
- 이미지 빌드/풀 전략 확인
- DB 접속 정보 확인
- 필요한 migration 반영 여부 확인

## 배포 직후

- 앱 기동 확인
- 로그인 확인
- 주요 페이지 접근 확인
- 에러 로그 확인
- 관리자 기능 최소 점검

## 재배포 시

- 새 이미지 pull
- compose 재기동
- 필요 시 `db:prepare`
- 로그 확인
