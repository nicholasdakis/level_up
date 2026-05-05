from datetime import datetime, timezone, timedelta
from unittest.mock import MagicMock
from backend.services.snapshot_service import SnapshotService
from backend.utils import find_utc_midnight_offset_mins

def make_user(uid, utc_offset_minutes, level=1, exp_points=0):
    return {
        "uid": uid,
        "utc_offset_minutes": utc_offset_minutes,
        "level": level,
        "exp_points": exp_points,
        "app_color": None,
        "last_daily_claim": None,
    }

def make_mock_repo(users):
    mock_repo = MagicMock()
    mock_repo.get_users_by_offsets.return_value = users
    mock_repo.get_streaks_by_uids.return_value = []
    mock_repo.get_achievements_by_uids.return_value = []
    mock_repo.get_claims_by_uids.return_value = []
    mock_repo.get_food_logs_by_uids_and_date.return_value = []
    mock_repo.upsert_daily_snapshots.return_value = None
    return mock_repo

# No users in the target timezone — run() should return early without writing anything
def test_no_users_returns_zero():
    mock_repo = make_mock_repo([])
    service = SnapshotService(mock_repo)
    assert service.run([0]) == 0
    mock_repo.upsert_daily_snapshots.assert_not_called()

# A user behind UTC (UTC-4, NYC) should be counted and their snapshot written
def test_nyc_gets_snapshot():
    mock_repo = make_mock_repo([make_user("nyc_uid", utc_offset_minutes=-240)])
    service = SnapshotService(mock_repo)
    offsets = list(find_utc_midnight_offset_mins(240))  # NYC midnight = 04:00 UTC = 240 mins
    assert service.run(offsets) == 1

# A user ahead of UTC (UTC+3, Cyprus) should be counted and their snapshot written
def test_cyprus_gets_snapshot():
    mock_repo = make_mock_repo([make_user("cyprus_uid", utc_offset_minutes=180)])
    service = SnapshotService(mock_repo)
    offsets = list(find_utc_midnight_offset_mins(1260))  # Cyprus midnight = 21:00 UTC = 1260 mins
    assert service.run(offsets) == 1

# Multiple users at the same midnight should each get their own snapshot row
def test_multiple_users_all_get_snapshots():
    users = [
        make_user("user_a", utc_offset_minutes=-240),
        make_user("user_b", utc_offset_minutes=-240),
    ]
    mock_repo = make_mock_repo(users)
    service = SnapshotService(mock_repo)
    offsets = list(find_utc_midnight_offset_mins(240))
    assert service.run(offsets) == 2

# UTC+0 is treated as behind-UTC (offset <= 0), so the snapshot date should be today not tomorrow
def test_utc_zero_gets_today_date():
    mock_repo = make_mock_repo([make_user("utc_uid", utc_offset_minutes=0)])
    service = SnapshotService(mock_repo)
    offsets = list(find_utc_midnight_offset_mins(0))
    service.run(offsets)

    rows = mock_repo.upsert_daily_snapshots.call_args[0][0]
    expected_date = datetime.now(timezone.utc).date().isoformat()
    assert rows[0]["snapshot_date"] == expected_date

# Users ahead of UTC are already in tomorrow so their snapshot should use tomorrow's date
def test_ahead_of_utc_user_gets_tomorrow_date():
    mock_repo = make_mock_repo([make_user("cyprus_uid", utc_offset_minutes=180)])
    service = SnapshotService(mock_repo)
    offsets = list(find_utc_midnight_offset_mins(1260))
    service.run(offsets)

    rows = mock_repo.upsert_daily_snapshots.call_args[0][0]
    expected_date = (datetime.now(timezone.utc) + timedelta(days=1)).date().isoformat()
    assert rows[0]["snapshot_date"] == expected_date

# Users behind UTC are still on today so their snapshot should use today's date
def test_behind_utc_user_gets_today_date():
    mock_repo = make_mock_repo([make_user("nyc_uid", utc_offset_minutes=-240)])
    service = SnapshotService(mock_repo)
    offsets = list(find_utc_midnight_offset_mins(240))
    service.run(offsets)

    rows = mock_repo.upsert_daily_snapshots.call_args[0][0]
    expected_date = datetime.now(timezone.utc).date().isoformat()
    assert rows[0]["snapshot_date"] == expected_date

# Streaks, achievements, and claims must be indexed by uid and included in the snapshot data
def test_snapshot_data_includes_streaks_achievements_claims():
    mock_repo = make_mock_repo([make_user("uid_1", utc_offset_minutes=0)])
    mock_repo.get_streaks_by_uids.return_value = [
        {"uid": "uid_1", "streak_type": "daily_consecutive_streak", "streak": 5, "highest_streak": 10, "last_date": "2026-05-01"},
    ]
    mock_repo.get_achievements_by_uids.return_value = [
        {"uid": "uid_1", "achievement_id": "level", "progress": 3},
    ]
    mock_repo.get_claims_by_uids.return_value = [
        {"uid": "uid_1", "achievement_id": "level", "tier": 3},
    ]
    service = SnapshotService(mock_repo)
    service.run(list(find_utc_midnight_offset_mins(0)))

    rows = mock_repo.upsert_daily_snapshots.call_args[0][0]
    data = rows[0]["data"]
    assert data["streaks"]["daily_consecutive_streak"]["streak"] == 5
    assert data["achievement_progress"]["level"] == 3
    assert {"achievement_id": "level", "tier": 3} in data["achievement_claims"]

# The snapshot data must include the core user fields — a missing key would corrupt the snapshot
def test_snapshot_data_contains_user_fields():
    mock_repo = make_mock_repo([make_user("uid_1", utc_offset_minutes=0, level=5, exp_points=200)])
    service = SnapshotService(mock_repo)
    offsets = list(find_utc_midnight_offset_mins(0))
    service.run(offsets)

    rows = mock_repo.upsert_daily_snapshots.call_args[0][0]
    data = rows[0]["data"]
    assert data["level"] == 5
    assert data["exp_points"] == 200
    assert "streaks" in data
    assert "achievement_progress" in data
    assert "achievement_claims" in data
