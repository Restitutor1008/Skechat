"""Create hourly active schedules from 07:00 through 16:00 for today."""

from datetime import datetime
from zoneinfo import ZoneInfo

from sqlalchemy import select

from app.database import SessionLocal
from app.models import Alarm, Schedule, User


DESCRIPTIONS = (
    "아침 준비",
    "가벼운 산책",
    "메일 확인",
    "집중 작업",
    "자료 정리",
    "점심 식사",
    "프로젝트 점검",
    "책 읽기",
    "스트레칭",
    "하루 마무리",
)


def seed() -> tuple[str, list[int]]:
    today = datetime.now(ZoneInfo("Asia/Seoul")).date()
    date_key = today.strftime("%Y%m%d")
    schedule_ids: list[int] = []

    with SessionLocal() as db:
        if db.get(User, "Skechatter") is None:
            raise RuntimeError("Skechatter 사용자가 없습니다. 사용자 seed를 먼저 실행하세요.")

        for index, (hour, description) in enumerate(
            zip(range(7, 17), DESCRIPTIONS, strict=True),
            start=1,
        ):
            alarm_id = f"today-{date_key}-alarm-{index:02d}"
            alarm = db.get(Alarm, alarm_id)
            if alarm is None:
                alarm = Alarm(
                    alarm_id=alarm_id,
                    alarm_music=None,
                    alarm_text=description,
                    minutes_before=10,
                    is_obsolete=False,
                )
                db.add(alarm)
                db.flush()
            else:
                alarm.alarm_text = description
                alarm.minutes_before = 10
                alarm.is_obsolete = False

            schedule = db.scalar(
                select(Schedule).where(
                    Schedule.user_id == "Skechatter",
                    Schedule.alarm_id == alarm_id,
                )
            )
            scheduled_at = datetime(today.year, today.month, today.day, hour)
            if schedule is None:
                schedule = Schedule(
                    scheduled_at=scheduled_at,
                    timezone="Asia/Seoul",
                    description=description,
                    user_id="Skechatter",
                    alarm_id=alarm_id,
                    location_id=None,
                    is_completed=False,
                    is_obsolete=False,
                    is_exception=False,
                )
                db.add(schedule)
                db.flush()
            else:
                schedule.scheduled_at = scheduled_at
                schedule.description = description
                schedule.location_id = None
                schedule.is_completed = False
                schedule.is_obsolete = False

            schedule_ids.append(schedule.schedule_id)

        db.commit()
    return today.isoformat(), schedule_ids


if __name__ == "__main__":
    seeded_date, ids = seed()
    print(f"seeded active schedules for {seeded_date}: {ids}")
