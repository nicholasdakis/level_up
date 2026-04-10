from datetime import datetime, timezone

# Helper method that converts Timestamp or datetime to UTC datetime
def to_utc_datetime(ts, fallback=None):
    # no timestamp provided, return fallback or current UTC time
    if not ts:
        return fallback or datetime.now(timezone.utc)
    
    # modern Firestore SDK Timestamp and standard datetime both have .timestamp()
    if hasattr(ts, 'timestamp'):
        return datetime.fromtimestamp(ts.timestamp(), tz=timezone.utc)
    
    # fallback for older Firestore SDK versions that use .to_datetime() instead
    if hasattr(ts, 'to_datetime'):
        return ts.to_datetime().replace(tzinfo=timezone.utc)
    
    # fallback for datetime objects without .timestamp()
    if isinstance(ts, datetime):
        return ts.replace(tzinfo=timezone.utc)
    
    # unknown type, return fallback or current UTC time
    return fallback or datetime.now(timezone.utc)