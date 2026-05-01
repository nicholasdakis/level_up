from backend.utils import to_utc_datetime, find_utc_midnight_offset_mins, utc_minute_of_day, MINUTES_IN_DAY
from datetime import datetime, timezone

# to_utc_datetime tests

def test_to_utc_datetime_no_timestamp_no_fallback():
    result = to_utc_datetime("", None)
    assert isinstance(result, datetime)
    assert result.tzinfo == timezone.utc

def test_to_utc_datetime_no_timestamp_with_fallback():
    fallback = datetime(2026, 1, 1, tzinfo=timezone.utc)
    result = to_utc_datetime("", fallback)
    assert result == fallback

def test_to_utc_datetime_with_iso_format_string():
    result = to_utc_datetime("2026-04-11 21:42:59.642087+00")
    assert result == datetime(2026, 4, 11, 21, 42, 59, 642087, tzinfo=timezone.utc)

def test_to_utc_datetime_with_datetime():
    result = to_utc_datetime(datetime(2026, 1, 1, tzinfo=timezone.utc))
    assert result == datetime(2026, 1, 1, tzinfo=timezone.utc)

def test_to_utc_datetime_with_naive_datetime():
    result = to_utc_datetime(datetime(2026, 1, 1)) # no timezone info
    assert result == datetime(2026, 1, 1, tzinfo=timezone.utc)

def test_to_utc_datetime_with_unknown_type():
    fallback = datetime(2026, 1, 1, tzinfo=timezone.utc)
    result = to_utc_datetime(12345, fallback)
    assert result == fallback

# utc_minute_of_day tests

def test_utc_minute_of_day_returns_valid_range():
    # should always return a value between 0 and 1439 (minutes in a day)
    result = utc_minute_of_day()
    assert 0 <= result < MINUTES_IN_DAY

# find_utc_midnight_offset_mins tests
def test_offsets():
    assert -240 in find_utc_midnight_offset_mins(240)   # NYC (UTC-4), west of UTC
    assert 180 in find_utc_midnight_offset_mins(1260)   # Cyprus (UTC+3), east of UTC
    assert 0 in find_utc_midnight_offset_mins(0)        # UTC exactly
    assert 330 in find_utc_midnight_offset_mins(1110)   # India (UTC+5:30), non-whole hour offset
    assert -720 in find_utc_midnight_offset_mins(720)   # UTC-12 (furthest behind)
    assert 720 in find_utc_midnight_offset_mins(720)    # UTC+12 (furthest ahead), same utc_min as -720 but a different offset