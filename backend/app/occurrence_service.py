import calendar
from collections.abc import Iterator
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from .models import Routine, RoutineFrequency


WEEKDAY_INDEX = {
    "MON": 0,
    "TUE": 1,
    "WED": 2,
    "THU": 3,
    "FRI": 4,
    "SAT": 5,
    "SUN": 6,
}


def _at_routine_time(routine: Routine, day: date) -> datetime:
    zone = ZoneInfo(routine.timezone)
    return datetime.combine(day, routine.start_time or time.min, tzinfo=zone)


def _clamped_date(year: int, month: int, requested_day: int) -> date:
    return date(year, month, min(requested_day, calendar.monthrange(year, month)[1]))


def _candidate_dates(routine: Routine) -> Iterator[date]:
    interval = routine.repeat_interval
    if routine.frequency == RoutineFrequency.DAILY:
        current = routine.start_date
        while True:
            yield current
            current += timedelta(days=interval)

    elif routine.frequency == RoutineFrequency.WEEKLY:
        weekdays = sorted(WEEKDAY_INDEX[item] for item in (routine.weekdays or []))
        week_start = routine.start_date - timedelta(days=routine.start_date.weekday())
        week_offset = 0
        while True:
            current_week = week_start + timedelta(weeks=week_offset)
            for weekday in weekdays:
                candidate = current_week + timedelta(days=weekday)
                if candidate >= routine.start_date:
                    yield candidate
            week_offset += interval

    elif routine.frequency == RoutineFrequency.MONTHLY:
        month_offset = 0
        while True:
            absolute_month = (
                routine.start_date.year * 12
                + routine.start_date.month
                - 1
                + month_offset
            )
            year, zero_based_month = divmod(absolute_month, 12)
            candidate = _clamped_date(
                year,
                zero_based_month + 1,
                routine.day_of_month or routine.start_date.day,
            )
            if candidate >= routine.start_date:
                yield candidate
            month_offset += interval

    else:
        year_offset = 0
        while True:
            year = routine.start_date.year + year_offset
            candidate = _clamped_date(
                year,
                routine.start_date.month,
                routine.start_date.day,
            )
            if candidate >= routine.start_date:
                yield candidate
            year_offset += interval


def _occurrences(routine: Routine) -> Iterator[datetime]:
    if not routine.is_active:
        return
    emitted = 0
    for candidate in _candidate_dates(routine):
        if routine.end_date is not None and candidate > routine.end_date:
            return
        if routine.repeat_count is not None and emitted >= routine.repeat_count:
            return
        emitted += 1
        yield _at_routine_time(routine, candidate)


def _in_routine_zone(value: datetime, routine: Routine) -> datetime:
    zone = ZoneInfo(routine.timezone)
    if value.tzinfo is None:
        return value.replace(tzinfo=zone)
    return value.astimezone(zone)


def get_next_occurrence(
    routine: Routine, after_datetime: datetime
) -> datetime | None:
    """Return the first occurrence strictly after the supplied instant."""
    after = _in_routine_zone(after_datetime, routine)
    for occurrence in _occurrences(routine):
        if occurrence > after:
            return occurrence
    return None


def get_occurrences(
    routine: Routine,
    range_start: datetime,
    range_end: datetime,
) -> list[datetime]:
    """Calculate occurrences in the half-open interval [start, end)."""
    start = _in_routine_zone(range_start, routine)
    end = _in_routine_zone(range_end, routine)
    if end <= start:
        raise ValueError("range_end must be after range_start")
    result: list[datetime] = []
    for occurrence in _occurrences(routine):
        if occurrence >= end:
            break
        if occurrence >= start:
            result.append(occurrence)
    return result
