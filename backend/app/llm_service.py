import json
from datetime import date
import re

import httpx

from .config import get_settings
from .schemas import ScheduleCommand


SYSTEM_PROMPT = """당신은 SkeChat 일정 명령 추출기입니다.
반드시 제공된 JSON Schema에 맞는 객체 하나만 반환하세요.
허용 action은 chat, list, create, update, delete, mixed, unknown뿐입니다.
절대로 SQL, 테이블명, 임의 도구명 또는 사용자 ID를 생성하지 마세요.
UPDATE/DELETE는 제공된 실제 일정의 id만 schedule_id로 사용할 수 있습니다.
일정 내용의 핵심 표현은 schedule_query에 넣으세요.
changes에는 eta, time_delta_minutes, description, alarm_id,
alarm_minutes_before, location_id, location_query, clear_location만 사용할 수 있습니다.
'30분 늦춰'는 time_delta_minutes=30, '1시간 당겨'는 -60으로 표현하세요.
사용자가 명시하지 않은 값은 만들지 말고 null로 두세요.
장소를 없애거나 '장소 없음'으로 바꾸라고 하면 clear_location=true로 두세요.
장소 이름을 지정하면 ID를 추측하지 말고 해당 이름을 location_query에 넣으세요.
날짜가 명시되지 않았으면 date는 null로 두세요. 서버가 오늘로 확정합니다.
날짜와 시간은 Asia/Seoul 기준 ISO 8601 형식으로 작성하세요.
일정 시각이나 내용으로 보이지만 명령 동사를 알 수 없으면 create로 분류하세요.
그 외에 명령 종류가 불명확하면 unknown으로 분류하세요. 서버는 unknown도 create 후보로 재검증합니다.
단순 질문이나 대화면 chat으로 분류하고 response에 짧은 한국어 답변을 작성하세요.
DB 쓰기 명령은 실행 여부를 판단하지 말고 구조화만 하세요.
CREATE/UPDATE/DELETE 요청이 두 개 이상 포함되면 종류가 같아도 action=mixed로 두고
operations 배열에 문장 순서대로 각 작업을 분리하세요.
mixed의 각 operation에는 action, confidence, schedule_id 또는 schedule_query,
date, changes를 독립적으로 채우세요. 생성 작업은 changes.eta와 description을
반드시 포함하고, 수정/삭제 대상 ID는 제공된 실제 일정에서만 선택하세요.
예: '23시에 치과를 만들고 회의 제목을 월간 회의로 바꾸고 운동은 삭제해줘'는
chat이 아니라 mixed이며 operations에 create, update, delete 세 항목을 넣어야 합니다.
"""


CRUD_HINT_PATTERNS = {
    "create": re.compile(r"(?:추가|생성|등록|만들)"),
    "update": re.compile(r"(?:수정|변경|바꾸|늦춰|당겨)"),
    "delete": re.compile(r"(?:삭제|지워|없애)"),
}
TIME_HINT_PATTERN = re.compile(
    r"(?:(?:오전|오후)\s*)?\d{1,2}\s*시|(?<!\d)\d{1,2}:\d{2}(?!\d)"
)

SYSTEM_PROMPT += """
사용자가 시각을 말하지 않았다면 시간을 추측하거나 00:00으로 만들지 말고 changes.eta를 null로 두세요.
날짜만 있는 일정은 정상적인 일정입니다. 일정 내용도 알 수 없으면 빈 문자열을 추측해 만들지 마세요.
"시간 없이", "오늘 안에", "언제든"은 eta=null을 의미합니다.
반복 일정은 action=mixed의 operations 항목으로 반환하고 entity_type=routine으로 설정하세요.
routine에는 name, frequency(DAILY/WEEKLY/MONTHLY/YEARLY), repeat_interval,
start_date, start_time, weekdays, day_of_month, timezone을 채우세요.
"매일"은 DAILY, "매주" 또는 "매 월요일"은 WEEKLY, "매월"은 MONTHLY입니다.
한 요청 안의 일반 일정은 entity_type=schedule, 루틴은 entity_type=routine으로 함께 반환할 수 있습니다.
"""

RECURRENCE_HINT_PATTERN = re.compile(
    r"매일|매주|매월|매년|매\s*[월화수목금토일]요일|격주|\d+\s*(?:일|주|개월)마다"
)


def _mixed_action_hint(message: str) -> str:
    actions = [
        action for action, pattern in CRUD_HINT_PATTERNS.items() if pattern.search(message)
    ]
    repeated_create = actions == ["create"] and len(TIME_HINT_PATTERN.findall(message)) >= 2
    has_recurrence = bool(RECURRENCE_HINT_PATTERN.search(message))
    if len(actions) < 2 and not repeated_create and not has_recurrence:
        return ""
    detected = actions if not repeated_create else ["create", "create"]
    if has_recurrence and "create" not in detected:
        detected.append("create")
    return (
        "\n서버 사전 분석에서 여러 일정 쓰기 작업이 감지되었습니다: "
        + ", ".join(detected)
        + ". 문맥상 명백한 정정 표현이 아니라면 종류가 같아도 action=mixed로 분류하고 "
        "operations에 각 작업을 빠짐없이 분리하세요. chat으로 분류하지 마세요.\n"
    )


async def classify_schedule_command(
    message: str,
    schedules: list[dict],
    reference_date: date,
) -> ScheduleCommand:
    settings = get_settings()
    payload = {
        "model": settings.llm_model,
        "stream": False,
        "format": ScheduleCommand.model_json_schema(),
        "options": {"temperature": 0},
        "messages": [
            {
                "role": "system",
                "content": SYSTEM_PROMPT
                + _mixed_action_hint(message)
                + f"\n현재 날짜: {reference_date.isoformat()}, 시간대: Asia/Seoul\n"
                + "현재 사용자의 일정:\n"
                + json.dumps(schedules, ensure_ascii=False),
            },
            {"role": "user", "content": message},
        ],
    }
    async with httpx.AsyncClient(timeout=120) as client:
        response = await client.post(
            f"{settings.ollama_base_url.rstrip('/')}/api/chat", json=payload
        )
        response.raise_for_status()
    content = response.json()["message"]["content"]
    return ScheduleCommand.model_validate_json(content)
