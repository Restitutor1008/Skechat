# SkeChat

MySQL의 `todolistresti` DB를 참조하는 Flutter 일정 앱입니다. Flutter는 DB에 직접 접속하지 않고 Python FastAPI REST API를 사용합니다. 일정 응답은 정규화된 `schedules`, `users`, `alarms`, `locations` 테이블을 조인해 구성하며 `is_obsolete` 필드는 클라이언트에 노출하지 않습니다. 채팅은 Ollama 호환 API의 `gemma4:e4b` 모델에 현재 DB 일정 컨텍스트를 전달합니다.

## 구성

- `lib/models`: REST 응답 모델
- `lib/core/config/app_config.dart`: 실행 중 조정할 동작 상수
- `lib/data/services`: HTTP 통신
- `lib/data/repositories`: 데이터 접근 추상화
- `lib/providers`: Riverpod 상태와 화면 동작 (`AsyncNotifier`/`Notifier`)
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

일정의 완료 여부는 삭제 여부와 별개인 `schedules.is_completed`로 관리합니다. `PATCH /api/todos/{todo_id}`에 `{"is_completed": true}`를 보내 완료 처리할 수 있으며, Flutter 메인 화면은 완료 여부와 관계없이 시각순으로 표시합니다.

활성 일정 조회는 무제한 전체 조회를 허용하지 않으며 `GET /api/todos?date=YYYY-MM-DD`처럼 날짜가 필수입니다. Flutter 채팅도 현재 화면에서 선택한 날짜만 LLM 컨텍스트로 전달합니다. 일반 REST 요청 timeout은 12초, LLM 채팅 요청 timeout은 60초입니다.

일정 카드는 완료 여부와 관계없이 이른 시각부터 늦은 시각 순으로 쌓입니다. 오늘 일정이 길면 현재 시각과 가장 가까운 카드가 먼저 보이도록 스크롤 위치를 맞추며, 앞뒤 일정은 위아래 스크롤로 확인합니다.

Flutter 상태 관리는 Riverpod 3의 `Notifier` 계열을 사용합니다. 선택 날짜 변경과 날짜별 REST 조회는 `scheduleProvider`, 채팅 미리보기·복구·적용은 `chatProvider`, 12/24시간 표시는 `clockFormatProvider`로 분리했습니다. 화면에는 스크롤 컨트롤러, 입력 debounce, 팝업처럼 위젯 생명주기에 직접 연결된 상태만 남깁니다.

REST 모델과 Riverpod 상태 값은 Freezed로 불변 객체와 `copyWith`를 생성하고, REST JSON 변환은 `json_serializable`을 사용합니다. 모델이나 상태 선언을 변경한 뒤 생성 파일은 다음 명령으로 갱신합니다.

```powershell
dart run build_runner build
```

채팅 입력 debounce, REST/LLM timeout, 최대 알람 시간, 달력 범위, 한국 시간 오프셋처럼 운영 중 조정할 수 있는 값은 `lib/core/config/app_config.dart`에 모아 둡니다. 색상이나 개별 애니메이션처럼 위젯에 종속된 값은 해당 위젯에 유지합니다.

## LLM과 MCP

Ollama 호환 서버가 `.env`의 `OLLAMA_BASE_URL`에서 실행되고 `LLM_MODEL=gemma4:e4b` 모델을 제공해야 합니다. MCP 서버는 다음 명령으로 stdio 실행할 수 있습니다.

```powershell
cd backend
python mcp_server.py
```

MCP stdio 서버는 일정 전용 REST 도구만 공개합니다. FastAPI 시작 시 MCP 프로세스와 `ClientSession`을 한 번 열고 애플리케이션이 종료될 때까지 재사용하며, stdio 메시지가 섞이지 않도록 도구 호출을 순차 처리합니다. 세션이 끊기면 해당 쓰기를 자동 재시도하지 않고 닫은 뒤 다음 요청에서 새 세션을 연결합니다.

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

명령 해석은 LLM을 한 번만 호출한 뒤 Python에서 단계적으로 보정합니다. 명령 종류가 불명확하면 생성 후보로 처리하되 시각과 내용을 모두 확인해야 실제 미리보기를 만듭니다. 날짜가 없으면 Flutter에서 현재 보고 있는 날짜를 사용하고, 상대 시간은 기존 일정 시각을 기준으로 계산합니다. 알람을 명시하지 않은 생성·수정은 기본 10분 전 알람을 사용합니다. 생성 장소가 생략되면 `location_id`를 `NULL`로 유지합니다. 일정 시각·내용을 확인할 수 없거나 대상 후보가 여러 개이면 쓰기를 중단하고 구체적인 정보를 요청합니다.

장소명은 LLM이 ID를 추측하지 않고 REST의 장소 목록에서 Python이 일치 항목을 확정합니다. `장소 없음` 요청은 명시적 `NULL` 변경으로 처리하므로 장소 미지정→지정 및 지정→미지정 변경을 모두 지원합니다.

채팅 명령 처리 로그는 로그인 확인 전용 `login_histories`와 분리된 `schedule_command_logs`에 저장됩니다. 전화번호, 이메일, 비밀번호, 토큰, API 키와 Bearer 인증값은 저장 전에 마스킹하며 원문은 SHA-256 해시만 남깁니다. 보존 기간은 코드에 30일로 고정되어 있고, 새 명령 처리 시와 API 서버 실행 중 매시간 만료 로그를 삭제합니다.

## 혼합 CRUD 안전장치

- 생성·수정 항목의 날짜, 시간, 내용, 알림, 장소를 항목별로 편집할 수 있습니다.
- 각 카드의 `OK!`는 해당 일정만 로컬 SQLite 트랜잭션으로 먼저 확정하고 나머지 카드는 유지합니다. 하단의 `선택한 일정 모두 적용`은 선택된 나머지 항목을 묶어서 처리합니다.
- 일정 날짜와 시각은 분리되어 있습니다. `scheduled_date`는 필수이고 `scheduled_at`은 nullable이므로 “오늘 안에”처럼 시각 없는 일정을 00:00으로 위장하지 않습니다. 미리보기에는 회색 `시간 미입력`, 저장된 일정에는 빈 시간 칸을 표시합니다.
- 중앙 DB의 혼합 작업은 한 트랜잭션으로 실행되고, 실행 직후 다른 변경이 없으면 전체 작업을 한 번에 되돌릴 수 있습니다.
- 서버에 연결할 수 없으면 명시적인 한국어 생성·수정·삭제 문장을 로컬에서 규칙 기반으로 분석하고 SQLite 한 트랜잭션에 저장합니다. 자연어가 불명확하면 추측 실행하지 않습니다.
- 미리보기 이후 중앙 일정이 바뀐 항목은 충돌로 표시하고 자동 선택 해제합니다. 사용자는 최신 대상을 새로고침해 재시도하거나 해당 항목을 제외하고 나머지만 실행할 수 있습니다.
- 낮은 신뢰도 또는 `아니라`, `아니고`, `말고`, `정정` 같은 정정 표현은 노란 경고와 확인 질문을 표시합니다. 이 항목은 기본 미선택이며 사용자가 `적용` 또는 `제외`에 답하기 전까지 실행할 수 없습니다. 경고 항목을 편집하면 이전 답변은 무효화되어 다시 확인해야 합니다.

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

## 공휴일 동기화

중앙 MySQL의 `holidays`가 기준 데이터이며 Flutter SQLite의 `holidays`는 오프라인 캐시입니다. 앱 시작·화면 복귀·주기 동기화 시 `GET /api/holidays/sync`에서 `updated_at` 이후 변경분만 받아 로컬 DB에 반영합니다. 로컬 데이터가 아직 없을 때만 `world_holidays` 내장 데이터를 화면 표시용으로 사용합니다.

중앙 공휴일 데이터를 갱신할 때는 root 계정이 아니라 migration 전용 Secret을 사용합니다.

```powershell
cd backend
python migrate.py --secret-file "E:\Documents\Restitutor\Practical\.env.migration"
python sync_korean_holidays.py --secret-file "E:\Documents\Restitutor\Practical\.env.migration"
```

Android의 로컬 DB 파일명은 `skechat_local.db`입니다. 현재 개발용 application ID 기준 실제 경로는 `/data/user/0/com.example.skechat/databases/skechat_local.db`이며 일반 앱이나 사용자는 이 샌드박스 경로에 직접 접근할 수 없습니다. 앱 삭제 또는 데이터 초기화를 하면 함께 삭제되고, 다음 실행 시 중앙 DB에서 다시 동기화됩니다.

## 혼합 다중 CRUD 파이프라인

한 채팅 문장에 생성·수정·삭제가 함께 들어오면 LLM은 `mixed` 명령과 항목별 `create`, `update`, `delete` 배열을 반환합니다. 서버는 모든 대상 일정의 소유권과 `updated_at` 버전을 미리 검증한 뒤 하나의 `schedule_operations` 작업에 저장합니다. Flutter는 작업별 색상 라벨과 체크박스를 표시하며, 사용자가 선택한 항목만 `OK!` 한 번으로 실행합니다.

선택한 혼합 작업은 중앙 DB에서 한 트랜잭션으로 처리됩니다. 충돌 항목은 실행 전에 자동 선택 해제되고 미리보기로 돌아오므로 새로고침하거나 제외할 수 있습니다. 실제 실행에 들어간 항목은 부분 적용되지 않으며, 실행 후 다른 변경이 없으면 생성·수정·삭제 전체를 한 번에 되돌릴 수 있습니다.

## 오프라인 CRUD와 배치 전송

일정 추가·수정·완료·삭제·복구는 SQLite에 먼저 반영합니다. 새 일정은 음수 임시 ID를 사용하고, 아직 배치에 포함되지 않은 변경은 일정별 최종 상태 하나로 합칩니다. 마지막 CRUD 이후 5분 동안 추가 변경이 없을 때 최대 100건을 `POST /api/offline/todos/batch` 한 요청으로 전송합니다.

각 전송에는 앱이 생성해 SQLite에 보존하는 `batch_id`와 작업별 `operation_id`가 포함됩니다. 서버는 `sync_batches`에 payload hash, 상태, 작업 수, 시도 횟수, 확정 시각과 결과 영수증을 저장하며 전체 CRUD와 영수증을 한 트랜잭션으로 확정합니다. 응답이 유실되면 앱은 같은 `batch_id`를 다시 보내고, 서버는 CRUD를 반복하지 않고 저장된 결과를 반환합니다. 앱은 `COMMITTED` 영수증을 확인한 뒤에만 해당 outbox 행을 삭제합니다. 서버 처리 상태는 `GET /api/offline/batches/{batch_id}`로 확인할 수 있습니다. 일정 본문과 비밀번호는 전송 감사 정보에 기록하지 않습니다.

생성 성공 후에는 서버가 발급한 양수 ID로 로컬 임시 ID와 뒤이어 대기 중인 작업의 대상 ID를 함께 교체합니다. 전송 실패 뒤 새 CRUD가 생기면 이미 고정된 배치는 그대로 유지하고 새 변경은 다음 배치로 분리합니다.

오프라인에서는 CRUD가 추가되어도 즉시 재접속하지 않습니다. 연결 실패 재시도는 30초부터 최대 5분까지 지수 백오프를 적용하고, 앱 화면을 반복해서 열어도 예약된 재시도 시각 전에는 요청하지 않습니다.
