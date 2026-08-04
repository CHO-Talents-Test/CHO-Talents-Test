# 운영 로그 한글 번역 점검 런북

이 문서는 `activity_logs`에 기록된 영문 액션/상세 값이 관리자 화면과 Slack에서 한글로 표시되도록 반복 점검·보완하는 표준 절차다.

## 한 번만 할 설정

비밀값을 채팅에 보내지 말고, 저장소 루트의 Git 제외 파일 `.env.local`에 아래 값을 추가한다.

```dotenv
# 실제 작업 대상. PROD 또는 DEV 중 하나를 명시한다.
LOG_TRANSLATION_TARGET_ENV=PROD
LOG_TRANSLATION_PROJECT_REF=rabakjtjtkelpskptnvi

# 위 project ref와 일치하는 Supabase 프로젝트 URL
SUPABASE_URL=https://rabakjtjtkelpskptnvi.supabase.co

# Supabase Dashboard > Settings > API Keys의 Secret key (sb_secret_...)
# 절대 채팅, Git, 정적 JS, app_config에 넣지 않는다.
SUPABASE_SECRET_KEY=...
```

`SUPABASE_SECRET_KEY`는 현재 권장되는 서버 전용 키이며 PostgREST에서 RLS를 우회하므로 이 작업에 충분하다. 아직 새 Secret key를 발급할 수 없는 기존 프로젝트는 레거시 `SUPABASE_SERVICE_ROLE_KEY`를 대신 사용할 수 있다. SQL 실행 전용 연결 문자열(`SUPABASE_DB_CONNECTION_STRING`)은 이 반복 작업에 필수는 아니며, 스키마 변경이나 대규모 마이그레이션 때만 별도로 둔다.

설정 뒤에는 한 번만 “운영 로그 번역용 `.env.local` 설정 완료”라고 알린다. 이후 요청마다 대시보드 로그인이나 키 재전달은 필요 없다.

설정이 끝나면 아래 자동화가 직접 로그와 코드북을 조회한다. 기본값은 읽기 전용이므로 먼저 점검 결과를 확인하고, 반영 요청이 있을 때만 `--apply`를 실행한다.

```bash
node scripts/sync-log-translations.mjs --check
node scripts/sync-log-translations.mjs --apply
```

## 작업 범위와 저장 위치

| 대상 | 현재 저장 위치 | 보완 방법 |
|---|---|---|
| 로그 액션 코드 (`activity_logs.action`) | DB `code_items`의 `activity_logs.action` 그룹 | 실제 로그에 존재하지만 한글 라벨이 없거나 영문 라벨만 있으면 DB에 upsert |
| 상세 key/값 (`activity_logs.details`) | `js/activity-log.js`의 공통 매핑 | 영문 key/값을 읽어 매핑을 소스에 추가하고 화면/Slack에서 한글 치환 |
| 과거 상세 원문 | `activity_logs.details` | 기본적으로 원문을 유지한다. 별도의 백필 요청이 있을 때만 한글 원문으로 변경 |

따라서 “DB 번역 업데이트”는 기본적으로 액션 코드의 `code_items` 라벨을 의미한다. 상세 문구의 번역은 현재 DB 테이블이 아니라 공통 JavaScript 매핑으로 관리된다.

## 기본 실행 절차

1. `.env.local`에서 `LOG_TRANSLATION_TARGET_ENV`, project ref, URL이 서로 맞는지 확인한다. 자동화는 대상 ref가 `config/public-config.js`의 해당 환경과 다르면 중단한다.
2. `scripts/sync-log-translations.mjs --check`으로 Secret key(또는 레거시 service_role 키)를 사용해 현재 로그 액션과 코드북을 조회한다. 사용자 이름, 계정, IP 같은 식별 정보는 번역 판정에 필요하지 않으므로 결과에 포함하거나 보고하지 않는다.
3. 액션은 `code_items(group_key = 'activity_logs.action')`, 상세는 `js/activity-log.js`의 액션/상세 매핑과 비교한다.
4. 실제 로그에서 발견된 누락 항목만 `--apply`로 보완한다. 기존 한글 라벨, 정렬 순서, 감사 분류 메타데이터는 바꾸지 않는다.
5. 액션 라벨은 `code_items`에 upsert한 뒤, 같은 기준으로 다시 조회해 누락이 없음을 검증한다. 상세 매핑 변경은 정적 검사와 화면 표시 확인을 한다.
6. 보고에는 대상 환경, 추가/수정된 코드 수와 코드명, 검증 결과만 담는다. 로그 원문이나 비밀값은 공유하지 않는다.

기본 조회 범위는 현재 보존 중인 삭제되지 않은 로그 전체다. 요청에서 “최근 30일”처럼 범위를 지정하면 그 범위로 좁힌다.

## 이후 요청 문구

아래처럼 간단히 요청하면 된다.

```text
운영(PROD) 로그 번역 점검하고 누락된 한글 항목 보완해줘.
```

조회만 원하면 “조회만 해줘”, DB/소스 반영까지 원하면 “보완해줘”라고 구분한다. 환경을 쓰지 않으면 이 문서의 `LOG_TRANSLATION_TARGET_ENV` 값을 사용하되, 쓰기 전에는 반드시 project ref를 대조한다.

## 보안 원칙

- `SUPABASE_SECRET_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, DB 연결 문자열은 채팅, 이슈, 커밋, 브라우저 코드에 절대 넣지 않는다.
- `.env.local`은 Git에서 제외된다. 새 장비에서는 `.env.example`을 참고해 로컬에서만 만든다.
- 서비스 롤 키가 노출됐다고 의심되면 Supabase에서 즉시 교체하고 `.env.local`도 갱신한다.
- 이 런북 범위의 쓰기는 `code_items`의 로그 액션 한글 라벨과 번역에 필요한 소스 매핑으로 한정한다. 로그 삭제, 사용자 정보 변경, RLS/권한 변경은 별도 요청 없이는 수행하지 않는다.
