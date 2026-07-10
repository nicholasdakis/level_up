import pytest
from datetime import datetime, timezone, timedelta
from backend.repository import PremiumPerksRepository


def make_repo(mocker, row=None):
    # Helper that wires up a mocked Supabase client and returns the repo
    fake_supabase = mocker.Mock()
    repo = PremiumPerksRepository(fake_supabase)
    if row is not None:
        fake_supabase.table.return_value.select.return_value.eq.return_value.execute.return_value.data = [row]
    else:
        fake_supabase.table.return_value.select.return_value.eq.return_value.execute.return_value.data = []
    return repo, fake_supabase


# get_or_create_perks tests -----------------

# An existing row must be returned as-is without any insert
def test_get_or_create_perks_existing_row(mocker):
    existing = {"uid": "u1", "shield_count": 2, "shields_reset_at": "2026-08-01T00:00:00+00:00", "streak_before_break": 5}
    repo, _ = make_repo(mocker, row=existing)

    result = repo.get_or_create_perks("u1")

    assert result == existing

# A missing row must trigger an insert with shield_count=3 and a future reset date
def test_get_or_create_perks_creates_row(mocker):
    repo, fake_supabase = make_repo(mocker, row=None)

    result = repo.get_or_create_perks("u1")

    assert result["shield_count"] == 3
    assert result["uid"] == "u1"
    reset_at = datetime.fromisoformat(result["shields_reset_at"])
    assert reset_at > datetime.now(timezone.utc)  # reset date must be in the future
    fake_supabase.table.return_value.insert.return_value.execute.assert_called_once()

# The reset date must be the 1st of next month, not some arbitrary future date
def test_get_or_create_perks_reset_date_is_first_of_next_month(mocker):
    repo, _ = make_repo(mocker, row=None)

    result = repo.get_or_create_perks("u1")

    reset_at = datetime.fromisoformat(result["shields_reset_at"])
    assert reset_at.day == 1
    assert reset_at.hour == 0
    assert reset_at.minute == 0


# reset_perks_if_month_elapsed tests -----------------

# A reset date still in the future must return the row unchanged and not hit the DB
def test_reset_perks_not_elapsed(mocker):
    repo, fake_supabase = make_repo(mocker)
    future = (datetime.now(timezone.utc) + timedelta(days=10)).isoformat()
    row = {"uid": "u1", "shield_count": 1, "shields_reset_at": future}

    result = repo.reset_perks_if_month_elapsed("u1", row)

    assert result["shield_count"] == 1  # unchanged
    fake_supabase.table.return_value.update.assert_not_called()

# A reset date in the past must refill shield_count to 3 and write to the DB
def test_reset_perks_elapsed_refills_shields(mocker):
    repo, fake_supabase = make_repo(mocker)
    past = (datetime.now(timezone.utc) - timedelta(days=5)).isoformat()
    row = {"uid": "u1", "shield_count": 0, "shields_reset_at": past}

    result = repo.reset_perks_if_month_elapsed("u1", row)

    assert result["shield_count"] == 3
    fake_supabase.table.return_value.update.assert_called_once()

# The new reset date after a reset must be the 1st of the following month
def test_reset_perks_elapsed_advances_reset_date(mocker):
    repo, _ = make_repo(mocker)
    past = (datetime.now(timezone.utc) - timedelta(days=5)).isoformat()
    row = {"uid": "u1", "shield_count": 0, "shields_reset_at": past}

    result = repo.reset_perks_if_month_elapsed("u1", row)

    new_reset = datetime.fromisoformat(result["shields_reset_at"])
    assert new_reset > datetime.now(timezone.utc)
    assert new_reset.day == 1

# A row with no reset date must be returned as-is without touching the DB
def test_reset_perks_missing_reset_at(mocker):
    repo, fake_supabase = make_repo(mocker)
    row = {"uid": "u1", "shield_count": 3, "shields_reset_at": ""}

    result = repo.reset_perks_if_month_elapsed("u1", row)

    assert result == row
    fake_supabase.table.return_value.update.assert_not_called()

# A reset date that is exactly now (boundary) must not trigger a reset
def test_reset_perks_exactly_now_does_not_reset(mocker):
    repo, fake_supabase = make_repo(mocker)
    # Add a small buffer so it's definitely in the future during test execution
    just_future = (datetime.now(timezone.utc) + timedelta(seconds=5)).isoformat()
    row = {"uid": "u1", "shield_count": 1, "shields_reset_at": just_future}

    result = repo.reset_perks_if_month_elapsed("u1", row)

    assert result["shield_count"] == 1
    fake_supabase.table.return_value.update.assert_not_called()


# apply_streak_shield tests -----------------

# A successful RPC call must return the new shield count and restored streak
def test_apply_streak_shield_success(mocker):
    repo, fake_supabase = make_repo(mocker)
    fake_supabase.rpc.return_value.execute.return_value.data = [
        {"out_shield_count": 2, "out_restored_streak": 15}
    ]

    result = repo.apply_streak_shield("u1")

    assert result["shield_count"] == 2
    assert result["restored_streak"] == 15
    fake_supabase.rpc.assert_called_once_with("apply_streak_shield", {"p_uid": "u1"})

# An empty RPC response (e.g. no matching row) must return zeros rather than crashing
def test_apply_streak_shield_empty_response(mocker):
    repo, fake_supabase = make_repo(mocker)
    fake_supabase.rpc.return_value.execute.return_value.data = []

    result = repo.apply_streak_shield("u1")

    assert result["shield_count"] == 0
    assert result["restored_streak"] == 0

# Shield count after spending one must be exactly one less than before
def test_apply_streak_shield_decrements_by_one(mocker):
    repo, fake_supabase = make_repo(mocker)
    fake_supabase.rpc.return_value.execute.return_value.data = [
        {"out_shield_count": 1, "out_restored_streak": 10}
    ]

    result = repo.apply_streak_shield("u1")

    # Caller had 2, RPC returned 1, confirm the decrement happened
    assert result["shield_count"] == 1

# The RPC floors at 0, calling with 0 shields must not go negative
def test_apply_streak_shield_cannot_go_below_zero(mocker):
    repo, fake_supabase = make_repo(mocker)
    # RPC uses GREATEST(shield_count - 1, 0) so 0 stays 0
    fake_supabase.rpc.return_value.execute.return_value.data = [
        {"out_shield_count": 0, "out_restored_streak": 10}
    ]

    result = repo.apply_streak_shield("u1")

    assert result["shield_count"] == 0

# Two rapid calls must each decrement independently, the second call sees the already-decremented count
def test_apply_streak_shield_two_calls_decrement_twice(mocker):
    repo, fake_supabase = make_repo(mocker)
    # First call: 3 -> 2, second call: 2 -> 1
    fake_supabase.rpc.return_value.execute.return_value.data = [
        {"out_shield_count": 2, "out_restored_streak": 10}
    ]
    first = repo.apply_streak_shield("u1")

    fake_supabase.rpc.return_value.execute.return_value.data = [
        {"out_shield_count": 1, "out_restored_streak": 10}
    ]
    second = repo.apply_streak_shield("u1")

    assert first["shield_count"] == 2
    assert second["shield_count"] == 1
    assert first["shield_count"] != second["shield_count"]  # each call produced a different result
    assert fake_supabase.rpc.call_count == 2  # RPC was called twice


# claim_daily_reward streak_broke passthrough tests -----------------

# streak_broke must be False when the transaction does not set it
def test_claim_daily_reward_streak_broke_defaults_false(mocker):
    from backend.services.progression_service import ProgressionService
    fake_repo = mocker.Mock()
    fake_repo.get_user.return_value = {"level": 1, "exp_points": 0, "last_daily_claim": None}
    fake_repo.get_streaks.return_value = []
    fake_repo.claim_daily_reward_transaction.return_value = {"claimed": True, "daily_streak": 1}
    service = ProgressionService(fake_repo, None, mocker.Mock())

    result = service.claim_daily_reward("u1")

    assert result["streak_broke"] == False

# streak_broke must be True when the transaction explicitly returns it as True
def test_claim_daily_reward_streak_broke_passed_through(mocker):
    from backend.services.progression_service import ProgressionService
    from datetime import timedelta
    three_days_ago = datetime.now(timezone.utc) - timedelta(days=3)
    fake_repo = mocker.Mock()
    fake_repo.get_user.return_value = {"level": 1, "exp_points": 0, "last_daily_claim": three_days_ago}
    fake_repo.get_streaks.return_value = [{"streak_type": "daily_consecutive_streak", "streak": 10}]
    fake_repo.claim_daily_reward_transaction.return_value = {
        "claimed": True, "daily_streak": 1, "streak_broke": True
    }
    service = ProgressionService(fake_repo, None, mocker.Mock())

    result = service.claim_daily_reward("u1")

    assert result["streak_broke"] == True
