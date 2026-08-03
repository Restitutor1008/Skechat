# SkeChat

MySQL의 `todolistresti` DB를 참조하는 Flutter 일정 앱입니다. Flutter는 DB에 직접 접속하지 않고 Python FastAPI REST API를 사용합니다. 일정 응답은 정규화된 `schedules`, `users`, `alarms`, `locations` 테이블을 조인해 구성하며 `is_obsolete` 필드는 클라이언트에 노출하지 않습니다. 채팅은 Ollama 호환 API의 `gemma4:e4b` 모델에 현재 DB 일정 컨텍스트를 전달합니다.

## 구성

- `lib/models`: REST 응답 모델
- `lib/data/services`: HTTP 통신
- `lib/data/repositories`: 데이터 접근 추상화
- `lib/viewmodels`: 화면 상태와 동작
- `lib/views`: 화면과 재사용 위젯
- `backend/app`: FastAPI, SQLAlchemy 모델, 서비스와 REST 라우트
- `backend/mcp_server.py`: DB 일정 도구를 노출하는 MCP stdio 서버 골격

## 실행

루트 `.env.example`을 참고해 `.env`의 DB 계정을 설정합니다. 실제 `.env`는 Git에서 제외됩니다. API는 `todolistresti`의 기존 일정 관련 테이블을 사용합니다.

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r backend\requirements.txt
cd backend
..\.venv\Scripts\python.exe run.py
```

다른 터미널에서 Flutter 앱을 실행합니다.

```powershell
flutter pub get
flutter run
```

Android 에뮬레이터에서는 호스트 PC의 localhost가 `10.0.2.2`이므로 다음처럼 실행합니다.

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

REST 문서는 API 실행 후 `http://127.0.0.1:8000/docs`에서 확인할 수 있습니다.

일정의 완료 여부는 삭제 여부와 별개인 `schedules.is_completed`로 관리합니다. `PATCH /api/todos/{todo_id}`에 `{"is_completed": true}`를 보내 완료 처리할 수 있으며, Flutter 메인 화면은 선택한 날짜에 완료 일정이 있을 때만 이를 남은 할 일보다 위에 표시합니다.

## LLM과 MCP

Ollama 호환 서버가 `.env`의 `OLLAMA_BASE_URL`에서 실행되고 `LLM_MODEL=gemma4:e4b` 모델을 제공해야 합니다. MCP 서버는 다음 명령으로 stdio 실행할 수 있습니다.

```powershell
cd backend
python mcp_server.py
```

MCP stdio 서버는 일정 전용 REST 도구만 공개하며 FastAPI가 채팅 요청마다 MCP 클라이언트로 연결합니다.

### 채팅 일정 수정 파이프라인

채팅을 통한 쓰기는 `LLM → MCP(stdio) → REST API → MySQL` 순서만 사용합니다. MCP 서버는 DB 모듈을 import하지 않으며 다음 일정 전용 도구만 공개합니다.

- `list_schedule`
- `list_locations`
- `preview_create_schedule`
- `preview_update_schedule`
- `preview_delete_schedule`
- `confirm_schedule_operation`
- `cancel_schedule_operation`
- `undo_schedule_operation`

수정과 삭제는 먼저 변경 내용을 보여주며, 같은 사용자와 같은 대화에서 `YES` 또는 `NO`를 입력해야 처리됩니다. 확인되지 않은 작업은 5분 뒤 만료됩니다. 실행된 작업은 변경 전후 값과 작업 UUID가 `schedule_operations`에 기록되며, 이후 일정이 다시 변경되지 않았을 때만 `되돌리기 <작업 UUID>`로 복구할 수 있습니다. LLM은 raw SQL을 생성하거나 실행할 수 없습니다.

명령 해석은 LLM을 한 번만 호출한 뒤 Python에서 단계적으로 보정합니다. 명령 종류가 불명확하면 생성 후보로 처리하되 시각과 내용을 모두 확인해야 실제 미리보기를 만듭니다. 날짜가 없으면 `Asia/Seoul` 기준 오늘을 사용하고, 상대 시간은 기존 일정 시각을 기준으로 계산합니다. 알람을 명시하지 않은 생성·수정은 기본 10분 전 알람을 사용합니다. 생성 장소가 생략되면 `location_id`를 `NULL`로 유지합니다. 일정 시각·내용을 확인할 수 없거나 대상 후보가 여러 개이면 쓰기를 중단하고 구체적인 정보를 요청합니다.

채팅 명령 처리 로그는 로그인 확인 전용 `login_histories`와 분리된 `schedule_command_logs`에 저장됩니다. 전화번호, 이메일, 비밀번호, 토큰, API 키와 Bearer 인증값은 저장 전에 마스킹하며 원문은 SHA-256 해시만 남깁니다. 보존 기간은 코드에 30일로 고정되어 있고, 새 명령 처리 시와 API 서버 실행 중 매시간 만료 로그를 삭제합니다.

## Routine API

반복 일정 API는 현재 사용자 식별을 위해 `X-User-Id` 헤더를 요구합니다. 예: `X-User-Id: Skechatter`.

- `POST /api/routines`
- `GET /api/routines`
- `GET /api/routines/{id}`
- `PATCH /api/routines/{id}`
- `DELETE /api/routines/{id}`
- `GET /api/routines/{id}/next-occurrence?after=...`
- `GET /api/routines/{id}/occurrences?range_start=...&range_end=...`

Routine 삭제 시 연결된 Schedule은 삭제되지 않고 `routine_id`만 `NULL`이 됩니다. API 시작 시 Alembic migration이 자동 적용되며 수동 적용은 `backend`에서 다음과 같이 실행할 수 있습니다.

```powershell
..\.venv\Scripts\python.exe -m alembic upgrade head
```
