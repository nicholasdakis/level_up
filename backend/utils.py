from datetime import datetime, timezone

# Converts a timestamp string or datetime to a UTC datetime
def to_utc_datetime(ts, fallback=None):
    # no timestamp provided, return fallback or current UTC time
    if not ts:
        return fallback or datetime.now(timezone.utc)

    # ISO-format string from Supabase (e.g. "2026-04-11 21:42:59.642087+00")
    if isinstance(ts, str):
        # parse the string into a datetime object
        dt = datetime.fromisoformat(ts)
        # if the string had no timezone info, assume UTC
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        # convert to UTC in case it was in a different timezone
        return dt.astimezone(timezone.utc)

    # already a datetime object
    if isinstance(ts, datetime):
        # if it has no timezone info, assume UTC
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        # convert to UTC in case it was in a different timezone
        return ts.astimezone(timezone.utc)

    # unknown type, return fallback or current UTC time
    return fallback or datetime.now(timezone.utc)