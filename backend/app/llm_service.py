import json
from datetime import date

import httpx

from .config import get_settings
from .schemas import ScheduleCommand


SYSTEM_PROMPT = """당신은 SkeChat 일정 명령 추출기입니다.
반드시 제공된 JSON Schema에 맞는 객체 하나만 반환하세요.
허용 action은 chat, list, create, update, delete, unknown뿐입니다.
절대로 SQL, 테이블명, 임의 도구명 또는 사용자 ID를 생성하지 마세요.
UPDATE/DELETE는 제공된 실제 일정의 id만 schedule_id로 사용할 수 있습니다.
일정 내용의 핵심 표현은 schedule_query에 넣으세요.
changes에는 eta, time_delta_minutes, description, alarm_id,
alarm_minutes_before, location_id만 사용할 수 있습니다.
'30분 늦춰'는 time_delta_minutes=30, '1시간 당겨'는 -60으로 표현하세요.
사용자가 명시하지 않은 값은 만들지 말고 null로 두세요.
날짜가 명시되지 않았으면 date는 null로 두세요. 서버가 오늘로 확정합니다.
날짜와 시간은 Asia/Seoul 기준 ISO 8601 형식으로 작성하세요.
일정 시각이나 내용으로 보이지만 명령 동사를 알 수 없으면 create로 분류하세요.
그 외에 명령 종류가 불명확하면 unknown으로 분류하세요. 서버는 unknown도 create 후보로 재검증합니다.
단순 질문이나 대화면 chat으로 분류하고 response에 짧은 한국어 답변을 작성하세요.
DB 쓰기 명령은 실행 여부를 판단하지 말고 구조화만 하세요.
"""


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
