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

# ARGB integer values of the colors free users are allowed to set as their app theme
FREE_PRESET_COLORS = {
    0xFF2D2D2D,  # Default
    0xFF4F8EF7,  # Blue
    0xFF7C5CBF,  # Purple
    0xFFE05C8A,  # Pink
    0xFF2EBF91,  # Teal
    0xFFE8864B,  # Orange
    0xFF5782AF,  # Steel
    0xFF4F17A1,  # Violet
    0xFFE84B4B,  # Red
    0xFF1A2A4A,  # Navy
    0xFF1A3A2A,  # Forest
    0xFF2A1A3A,  # Midnight
    0xFF3A1A1A,  # Crimson
}

def paginate_query(query, page_size: int = 1000) -> list:
    # Fetches all rows from a query by paginating through in chunks to bypass Supabase's hard row cap
    offset = 0
    all_rows = []
    while True:
        rows = query.range(offset, offset + page_size - 1).execute().data or []
        all_rows.extend(rows)
        if len(rows) < page_size:
            break
        offset += page_size
    return all_rows

# ----------------------
# Daily Snapshot related utility functions
MINUTES_IN_DAY = 1440 # for wrapping around the time when converting it

# Method to calculate utc time in mins for the formula local time in mins = utc time in mins + offset in mins
def utc_minute_of_day():
    now = datetime.now(timezone.utc)
    return now.hour * 60 + now.minute

# Method that returns the offsets in minutes that are currently at midnight (with a 1 minute buffer on either side to account for slight timing differences between the CRON job and the server)
def find_utc_midnight_offset_mins(utc_min):
    # the raw offset that would be at midnight exactly in local time
    raw = -utc_min
    # normalize the offsets to be between -720 and 720, which correspond to the furthest timezones UTC-12 and UTC+12
    # includes buffers of 1 minute on either side, so 3 offsets are returned in total
    offsets = [(raw + delta + 720) % MINUTES_IN_DAY - 720 for delta in [-1, 0, 1]]
    # edge case for UTC-12 and UTC+12, which have the same utc_min but different offsets
    if -720 in offsets:
        offsets.append(720)
    elif 720 in offsets:
        offsets.append(-720)
    offsets = list(set(offsets)) # dedupe in case of duplicates from the edge case handling
    return offsets
# ----------------------