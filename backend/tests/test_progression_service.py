import pytest
from datetime import datetime, timezone, timedelta
from backend.services.progression_service import (
    ProgressionService,
    experience_needed,
    calculate_daily_reward_xp,
    calculate_level_up,
    streak_multiplier,
)

# experience_needed tests -----------------

# Hardcoded value so a formula change is immediately caught
def test_experience_needed_level_0():
    assert experience_needed(0) == 90

# Hardcoded value so a formula change is immediately caught
def test_experience_needed_level_1():
    assert experience_needed(1) == 130

# The XP curve must never flatten or reverse — users should always need more XP to level up
def test_experience_needed_always_increases():
    for level in range(1, 500):
        assert experience_needed(level) < experience_needed(level + 1)

# calculate_daily_reward_xp tests -----------------

# Level 1 has no randomness since randint(1, 1) always returns 1, so the result is deterministic
def test_calculate_daily_reward_xp_level_1():
    assert calculate_daily_reward_xp(1) == 27  # 25*1 + 2*1

# Pin the minimum payout at level 10 — mocker forces randint to its lowest possible value
def test_calculate_daily_reward_xp_level_10_minimum(mocker):
    mocker.patch("backend.services.progression_service.random.randint", return_value=1)
    assert calculate_daily_reward_xp(10) == 252  # 25*10 + 2*1

# Pin the maximum payout at level 10 — mocker forces randint to its highest possible value
def test_calculate_daily_reward_xp_level_10_maximum(mocker):
    mocker.patch("backend.services.progression_service.random.randint", return_value=10)
    assert calculate_daily_reward_xp(10) == 270  # 25*10 + 2*10

# Confirm the formula still behaves at a high level
def test_calculate_daily_reward_xp_level_100_minimum(mocker):
    mocker.patch("backend.services.progression_service.random.randint", return_value=1)
    assert calculate_daily_reward_xp(100) == 2502  # 25*100 + 2*1

# Confirm the formula still behaves at a high level
def test_calculate_daily_reward_xp_level_100_maximum(mocker):
    mocker.patch("backend.services.progression_service.random.randint", return_value=100)
    assert calculate_daily_reward_xp(100) == 2700  # 25*100 + 2*100

# Higher-level users should always get more XP — guards against the formula accidentally flattening
def test_calculate_daily_reward_xp_scales_with_level(mocker):
    mocker.patch("backend.services.progression_service.random.randint", return_value=1)
    assert calculate_daily_reward_xp(50) > calculate_daily_reward_xp(10)
    assert calculate_daily_reward_xp(10) > calculate_daily_reward_xp(1)

# streak_multiplier tests -----------------

# Below the first tier — no bonus should be applied
def test_streak_multiplier_no_streak():
    assert streak_multiplier(0) == 1.0
    assert streak_multiplier(2) == 1.0  # 2 is the last value before the tier-3 cutoff

# Both the boundary (3) and the last value before the next tier (9) must return 1.1
def test_streak_multiplier_tier_3():
    assert streak_multiplier(3) == 1.1
    assert streak_multiplier(9) == 1.1

# Both the boundary (10) and the last value before the next tier (29) must return 1.25
def test_streak_multiplier_tier_10():
    assert streak_multiplier(10) == 1.25
    assert streak_multiplier(29) == 1.25

# Both the boundary (30) and the last value before the next tier (49) must return 1.4
def test_streak_multiplier_tier_30():
    assert streak_multiplier(30) == 1.4
    assert streak_multiplier(49) == 1.4

# The top tier — boundary and an arbitrarily large value must both return 1.5
def test_streak_multiplier_tier_50():
    assert streak_multiplier(50) == 1.5
    assert streak_multiplier(999) == 1.5

# calculate_level_up tests -----------------

# XP gained that doesn't reach the threshold — level and XP should be unchanged
def test_calculate_level_up_same_level():
    assert calculate_level_up(10, 0, 100) == (10, 100)

# Gaining zero XP should be a no-op
def test_calculate_level_up_zero_xp_gained():
    assert calculate_level_up(5, 200, 0) == (5, 200)

# Gaining exactly enough XP to level up once, plus 1 — the leftover 1 XP should carry over
def test_calculate_level_up_one_level():
    threshold = experience_needed(10)
    assert calculate_level_up(10, 0, threshold + 1) == (11, 1)

# Starting partway through a level — only the remaining gap should be needed to cross the threshold
def test_calculate_level_up_with_partial_starting_xp():
    threshold = experience_needed(10)
    starting_xp = threshold - 50  # 50 XP short of leveling up
    assert calculate_level_up(10, starting_xp, 50) == (11, 0)

# XP beyond the threshold must carry into the new level, not be silently dropped
def test_calculate_level_up_remainder_carries_over():
    threshold = experience_needed(10)
    assert calculate_level_up(10, 0, threshold + 99) == (11, 99)

# Adding exactly enough XP to cross 3 level thresholds should land on level 13
# with the same starting XP, since each threshold is consumed exactly
def test_calculate_level_up_multiple_levels():
    starting_level = 10
    starting_xp = 100
    xp_gained = (
        experience_needed(starting_level)
        + experience_needed(starting_level + 1)
        + experience_needed(starting_level + 2)
    )
    assert calculate_level_up(starting_level, starting_xp, xp_gained) == (starting_level + 3, starting_xp)

# _can_claim_daily_reward tests -----------------

# A user who has never claimed should always be allowed to claim
def test_can_claim_daily_reward_no_previous_claim():
    service = ProgressionService(None, None, None)
    assert service._can_claim_daily_reward({"last_daily_claim": None}) == True

# 10 hours is well under the 23-hour (82800 second) cooldown
def test_can_claim_daily_reward_too_soon():
    service = ProgressionService(None, None, None)
    ten_hours_ago = datetime.now(timezone.utc) - timedelta(hours=10)
    assert service._can_claim_daily_reward({"last_daily_claim": ten_hours_ago}) == False

# 24 hours is past the 23-hour cooldown — claim should be allowed
def test_can_claim_daily_reward_enough_time_passed():
    service = ProgressionService(None, None, None)
    yesterday = datetime.now(timezone.utc) - timedelta(hours=24)
    assert service._can_claim_daily_reward({"last_daily_claim": yesterday}) == True

# is_moving_too_fast_for_poi tests -----------------

# No prior fetch stored for this user — nothing to compare against so it can't be too fast
def test_is_moving_too_fast_no_previous_location():
    service = ProgressionService(None, None, None)
    assert service.is_moving_too_fast_for_poi("user_123", 40.7, -74.0) == False

# Same coordinates twice — distance is 0 so speed is 0 regardless of time elapsed
def test_is_moving_too_fast_stationary():
    service = ProgressionService(None, None, None)
    service.is_moving_too_fast_for_poi("user_123", 40.7, -74.0)
    assert service.is_moving_too_fast_for_poi("user_123", 40.7, -74.0) == False

# ~100m in 1000 seconds = 0.1 m/s, well under the 12 m/s threshold
# Injecting the previous fetch directly avoids needing to mock datetime
def test_is_moving_too_fast_slow_movement():
    service = ProgressionService(None, None, None)
    service._last_poi_fetch["user_123"] = (40.7, -74.0, datetime.now(timezone.utc) - timedelta(seconds=1000))
    assert service.is_moving_too_fast_for_poi("user_123", 40.70090, -74.0) == False

# ~1000m in 1 second = 1000 m/s, physically impossible and way over the 12 m/s threshold
# Injecting the previous fetch directly avoids needing to mock datetime
def test_is_moving_too_fast_impossible_speed():
    service = ProgressionService(None, None, None)
    service._last_poi_fetch["user_123"] = (40.7, -74.0, datetime.now(timezone.utc) - timedelta(seconds=1))
    assert service.is_moving_too_fast_for_poi("user_123", 40.709, -74.0) == True

# _track_achievement tests -----------------

# A valid server-tracked achievement ID should reach the repo with the correct arguments
def test_track_achievement_valid_id_calls_repo(mocker):
    fake_achievement_repo = mocker.Mock()
    service = ProgressionService(None, None, fake_achievement_repo)

    service._track_achievement("user_123", "level")

    # increment is always hardcoded to 1 — the client cannot send a fake amount
    fake_achievement_repo.upsert_achievement_progress.assert_called_once_with("user_123", "level", 1)

# An unrecognised ID should be rejected before touching the repo
def test_track_achievement_invalid_id_calls_repo(mocker):
    fake_achievement_repo = mocker.Mock()
    service = ProgressionService(None, None, fake_achievement_repo)

    service._track_achievement("user_123", "invalid_achievement_id_123456789")

    fake_achievement_repo.upsert_achievement_progress.assert_not_called()

# A DB crash must never propagate up and break the action that triggered the achievement
def test_track_achievement_swallows_exceptions(mocker):
    fake_achievement_repo = mocker.Mock()
    fake_achievement_repo.upsert_achievement_progress.side_effect = Exception("DB crash")
    service = ProgressionService(None, None, fake_achievement_repo)

    service._track_achievement("user_123", "level")  # must not raise

    fake_achievement_repo.upsert_achievement_progress.assert_called_once_with("user_123", "level", 1)

# claim_daily_reward tests -----------------

def make_claim_service(mocker, user, streaks=None, transaction_result=None):
    # Helper that wires up the three mocked repos claim_daily_reward needs
    fake_repo = mocker.Mock()
    fake_achievement_repo = mocker.Mock()
    fake_repo.get_user.return_value = user
    fake_repo.get_streaks.return_value = streaks or []
    fake_repo.claim_daily_reward_transaction.return_value = transaction_result or {
        "claimed": True, "daily_streak": 1
    }
    return ProgressionService(fake_repo, None, fake_achievement_repo)

# When the transaction says the cooldown hasn't passed, claimed must be False and no XP awarded
def test_claim_daily_reward_cooldown_not_met(mocker):
    user = {"level": 1, "exp_points": 0, "last_daily_claim": None}
    service = make_claim_service(mocker, user, transaction_result={
        "claimed": False, "seconds_remaining": 3600
    })

    result = service.claim_daily_reward("user_123")

    assert result["claimed"] == False
    assert result["xp_gained"] == 0
    assert result["seconds_remaining"] == 3600

# A normal successful claim — must return claimed=True with positive XP and the streak value
def test_claim_daily_reward_success(mocker):
    user = {"level": 5, "exp_points": 0, "last_daily_claim": None}
    service = make_claim_service(mocker, user, transaction_result={
        "claimed": True, "daily_streak": 3
    })

    result = service.claim_daily_reward("user_123")

    assert result["claimed"] == True
    assert result["xp_gained"] > 0
    assert result["daily_streak"] == 3

# Leveling up during a claim must trigger set_achievement_progress for the level achievement
def test_claim_daily_reward_level_up_tracks_achievement(mocker):
    threshold = experience_needed(1)
    # Give the user enough exp that the daily reward will push them over the level 1 threshold
    user = {"level": 1, "exp_points": threshold - 1, "last_daily_claim": None}
    service = make_claim_service(mocker, user, transaction_result={
        "claimed": True, "daily_streak": 1
    })

    result = service.claim_daily_reward("user_123")

    # Level must have increased
    assert result["new_level"] == 2
    # Achievement repo must have been told the new level
    service._achievement_repo.set_achievement_progress.assert_any_call("user_123", "level", 2)

# If the last claim was more than 48 hours ago the streak resets so the multiplier must be 1.0
def test_claim_daily_reward_streak_resets_after_48_hours(mocker):
    three_days_ago = datetime.now(timezone.utc) - timedelta(days=3)
    user = {"level": 1, "exp_points": 0, "last_daily_claim": three_days_ago}
    # Give the user a streak of 30 which would normally give a 1.4x multiplier
    streaks = [{"streak_type": "daily_consecutive_streak", "streak": 30}]
    service = make_claim_service(mocker, user, streaks=streaks, transaction_result={
        "claimed": True, "daily_streak": 1
    })

    result = service.claim_daily_reward("user_123")

    # Streak resets so multiplier must be 1.0 and bonus_xp must be 0
    assert result["streak_multiplier"] == 1.0
    assert result["bonus_xp"] == 0

# An active streak within 48 hours must apply the correct multiplier
def test_claim_daily_reward_streak_multiplier_applied(mocker):
    one_day_ago = datetime.now(timezone.utc) - timedelta(hours=25)
    user = {"level": 1, "exp_points": 0, "last_daily_claim": one_day_ago}
    # Streak of 10 gives a 1.25x multiplier
    streaks = [{"streak_type": "daily_consecutive_streak", "streak": 10}]
    service = make_claim_service(mocker, user, streaks=streaks, transaction_result={
        "claimed": True, "daily_streak": 11
    })

    result = service.claim_daily_reward("user_123")

    assert result["streak_multiplier"] == 1.25
    assert result["bonus_xp"] > 0

# update_username tests -----------------

# A taken username must be rejected before touching the DB
def test_update_username_taken(mocker):
    fake_repo = mocker.Mock()
    fake_repo.username_exists.return_value = True
    service = ProgressionService(fake_repo, None, mocker.Mock())

    result = service.update_username("user_123", "takenname")

    assert result == {"success": False, "error": "Username taken"}
    fake_repo.set_user_data.assert_not_called()

# A new user setting their username for the first time (username == uid) should not trigger change_username
def test_update_username_first_time(mocker):
    fake_repo = mocker.Mock()
    fake_repo.username_exists.return_value = False
    fake_repo.get_user.return_value = {"username": "user_123"}  # username == uid, so no prior username
    fake_achievement_repo = mocker.Mock()
    service = ProgressionService(fake_repo, None, fake_achievement_repo)

    result = service.update_username("user_123", "newname")

    assert result == {"success": True}
    fake_achievement_repo.upsert_achievement_progress.assert_called_once_with("user_123", "set_username", 1)

# A user changing an existing username should trigger both set_username and change_username achievements
def test_update_username_change_existing(mocker):
    fake_repo = mocker.Mock()
    fake_repo.username_exists.return_value = False
    fake_repo.get_user.return_value = {"username": "oldname"}  # already has a real username
    fake_achievement_repo = mocker.Mock()
    service = ProgressionService(fake_repo, None, fake_achievement_repo)

    service.update_username("user_123", "newname")

    calls = [c.args for c in fake_achievement_repo.upsert_achievement_progress.call_args_list]
    assert ("user_123", "set_username", 1) in calls
    assert ("user_123", "change_username", 1) in calls

# check_in_poi tests -----------------

def make_checkin_service(mocker, user=None, transaction_result=None):
    fake_repo = mocker.Mock()
    fake_achievement_repo = mocker.Mock()
    fake_repo.get_user.return_value = user or {"level": 1, "exp_points": 0}
    fake_repo.record_poi_visit_transaction.return_value = transaction_result or {"success": True}
    return ProgressionService(fake_repo, None, fake_achievement_repo)

# A user more than 30m away must be rejected before any DB call
def test_check_in_poi_too_far(mocker):
    service = make_checkin_service(mocker)

    # Place user 1km away from the POI
    result = service.check_in_poi("user_123", "Coffee Shop", 40.7, -74.0, 40.709, -74.0)

    assert result["success"] == False
    assert result["error"] == "Too far from this spot"
    service._repo.get_user.assert_not_called()

# A check-in that hits the 24h cooldown inside the transaction must return success=False
def test_check_in_poi_on_cooldown(mocker):
    service = make_checkin_service(mocker, transaction_result={"success": False, "error": "Already visited"})

    # Place user right next to the POI (same point = 0m)
    result = service.check_in_poi("user_123", "Coffee Shop", 40.7, -74.0, 40.7, -74.0)

    assert result["success"] == False

# A valid nearby check-in must return success=True and a positive XP reward
def test_check_in_poi_success(mocker):
    service = make_checkin_service(mocker)

    result = service.check_in_poi("user_123", "Coffee Shop", 40.7, -74.0, 40.7, -74.0)

    assert result["success"] == True
    assert result["xp_gained"] > 0

# Leveling up during a check-in must trigger set_achievement_progress for the level achievement
def test_check_in_poi_level_up_tracks_achievement(mocker):
    threshold = experience_needed(1)
    user = {"level": 1, "exp_points": threshold - 1}  # one XP short of leveling up
    service = make_checkin_service(mocker, user=user)

    result = service.check_in_poi("user_123", "Park", 40.7, -74.0, 40.7, -74.0)

    assert result["new_level"] == 2
    service._achievement_repo.set_achievement_progress.assert_called_once_with("user_123", "level", 2)

# upsert_food_log tests -----------------

# A successful food log must track the food_logs achievement and update the food streak
def test_upsert_food_log_tracks_achievement(mocker):
    fake_repo = mocker.Mock()
    fake_repo.update_food_streak.return_value = 3
    fake_achievement_repo = mocker.Mock()
    service = ProgressionService(fake_repo, None, fake_achievement_repo)

    service.upsert_food_log("user_123", "2026-05-04", [], [], [], [])

    fake_achievement_repo.upsert_achievement_progress.assert_called_once_with("user_123", "food_logs", 1)
    fake_achievement_repo.set_achievement_progress.assert_called_once_with("user_123", "food_streak", 3)

# A DB crash in the streak update must be swallowed and not break the food log itself
def test_upsert_food_log_streak_exception_swallowed(mocker):
    fake_repo = mocker.Mock()
    fake_repo.update_food_streak.side_effect = Exception("DB crash")
    service = ProgressionService(fake_repo, None, mocker.Mock())

    service.upsert_food_log("user_123", "2026-05-04", [], [], [], [])  # must not raise

    fake_repo.upsert_food_log.assert_called_once()

# delete_reminder tests -----------------

# A reminder that doesn't belong to the user must be rejected without touching the DB
def test_delete_reminder_wrong_user(mocker):
    fake_reminder_repo = mocker.Mock()
    fake_reminder_repo.get_reminders.return_value = [{"id": "reminder_abc"}]
    service = ProgressionService(None, fake_reminder_repo, None)

    result = service.delete_reminder("user_123", "reminder_xyz")  # wrong id

    assert result == False
    fake_reminder_repo.delete_reminder.assert_not_called()

# A successful deletion must return True and track the delete_reminder achievement
def test_delete_reminder_success(mocker):
    fake_reminder_repo = mocker.Mock()
    fake_reminder_repo.get_reminders.return_value = [{"id": "reminder_abc"}]
    fake_reminder_repo.delete_reminder.return_value = True
    fake_achievement_repo = mocker.Mock()
    service = ProgressionService(None, fake_reminder_repo, fake_achievement_repo)

    result = service.delete_reminder("user_123", "reminder_abc")

    assert result == True
    fake_achievement_repo.upsert_achievement_progress.assert_called_once_with("user_123", "delete_reminder", 1)

# If the DB deletion fails the achievement must not be tracked
def test_delete_reminder_db_failure_does_not_track(mocker):
    fake_reminder_repo = mocker.Mock()
    fake_reminder_repo.get_reminders.return_value = [{"id": "reminder_abc"}]
    fake_reminder_repo.delete_reminder.return_value = False
    fake_achievement_repo = mocker.Mock()
    service = ProgressionService(None, fake_reminder_repo, fake_achievement_repo)

    result = service.delete_reminder("user_123", "reminder_abc")

    assert result == False
    fake_achievement_repo.upsert_achievement_progress.assert_not_called()

# claim_achievement tests -----------------

# An achievement ID not in the valid list must raise before touching the repo
def test_claim_achievement_invalid_id(mocker):
    service = ProgressionService(None, None, mocker.Mock())
    import pytest as _pytest
    with _pytest.raises(ValueError, match="Unknown achievement"):
        service.claim_achievement("user_123", "fake_achievement_999", 1)

# A valid ID but a tier that doesn't exist for it must raise before touching the repo
def test_claim_achievement_invalid_tier(mocker):
    service = ProgressionService(None, None, mocker.Mock())
    import pytest as _pytest
    with _pytest.raises(ValueError, match="Invalid tier"):
        service.claim_achievement("user_123", "level", 999)  # 999 is not a valid tier for level

# A valid claim must call the repo and track the total_achievements achievement
def test_claim_achievement_success(mocker):
    fake_achievement_repo = mocker.Mock()
    fake_achievement_repo.claim_achievement.return_value = True
    service = ProgressionService(None, None, fake_achievement_repo)

    service.claim_achievement("user_123", "level", 3)

    fake_achievement_repo.claim_achievement.assert_called_once_with("user_123", "level", 3)
    fake_achievement_repo.upsert_achievement_progress.assert_called_once_with("user_123", "total_achievements", 1)

# update_goals tests -----------------

# None values must be stripped before reaching the repo so existing goals are not overwritten
def test_update_goals_strips_none_values(mocker):
    fake_repo = mocker.Mock()
    service = ProgressionService(fake_repo, None, None)

    service.update_goals("user_123", calories_goal=2000, protein_goal=None, carbs_goal=None, fat_goal=None, weight_goal_type=None)

    call_data = fake_repo.upsert_goals.call_args[0][1]
    assert "calories_goal" in call_data
    assert "protein_goal" not in call_data  # None was stripped

# _haversine tests -----------------

# Two identical points have zero distance
def test_haversine_same_point():
    service = ProgressionService(None, None, None)
    assert service._haversine(40.0, -74.0, 40.0, -74.0) == pytest.approx(0)

# Cross-check against a known real-world distance to catch formula regressions
def test_haversine_known_distance():
    service = ProgressionService(None, None, None)
    distance = service._haversine(40.7128, -74.0060, 34.0522, -118.2437)  # NYC to LA
    assert distance == pytest.approx(3944000, rel=0.01)  # within 1% of 3944km

# Short distances matter most — POI check-ins use a 50m radius
def test_haversine_short_distance():
    service = ProgressionService(None, None, None)
    distance = service._haversine(0.0, 0.0, 0.00027, 0.0)  # ~30m north at the equator
    assert distance == pytest.approx(30, abs=1)  # within 1 meter

# Distance A to B must equal distance B to A — asymmetry would mean the check-in radius is direction-dependent
def test_haversine_is_symmetric():
    service = ProgressionService(None, None, None)
    a = service._haversine(40.7, -74.0, 34.0, -118.2)
    b = service._haversine(34.0, -118.2, 40.7, -74.0)
    assert a == pytest.approx(b)
