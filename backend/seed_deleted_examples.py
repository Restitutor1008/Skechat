"""Create three idempotent soft-deleted schedules for the recovery UI."""

from datetime import datetime

from sqlalchemy import select

from app.database import SessionLocal
from app.models import Alarm, Schedule, User


EXAMPLES = (
    ("recovery-example-alarm-1", datetime(2026, 8, 1, 10, 0), "삭제된 장보기"),
    ("recovery-example-alarm-2", datetime(2026, 8, 2, 15, 30), "삭제된 산책"),
    ("recovery-example-alarm-3", datetime(2026, 8, 3, 20, 0), "삭제된 독서"),
)


def seed() -> list[int]:
    with SessionLocal() as db:
        if db.get(User, "Skechatter") is None:
            raise RuntimeError("Skechatter 사용자가 없습니다. 사용자 seed를 먼저 실행하세요.")

        schedule_ids: list[int] = []
        for alarm_id, scheduled_at, description in EXAMPLES:
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

            schedule = db.scalar(
                select(Schedule).where(
                    Schedule.user_id == "Skechatter",
                    Schedule.alarm_id == alarm_id,
                )
            )
            if schedule is None:
                schedule = Schedule(
                    scheduled_at=scheduled_at,
                    timezone="Asia/Seoul",
                    description=description,
                    user_id="Skechatter",
                    alarm_id=alarm_id,
                    location_id=None,
                    is_completed=False,
                    is_obsolete=True,
                    is_exception=False,
                )
                db.add(schedule)
                db.flush()
            else:
                schedule.scheduled_at = scheduled_at
                schedule.description = description
                schedule.is_obsolete = True

            schedule_ids.append(schedule.schedule_id)

        db.commit()
        return schedule_ids


if __name__ == "__main__":
    print("seeded soft-deleted schedules:", seed())
