-- get_public_tables: Returns all user-created tables in the public schema — used by the backup script
CREATE OR REPLACE FUNCTION get_public_tables()
RETURNS TABLE(table_name TEXT)
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT table_name::TEXT
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE';
$$;

-- claim_daily_reward: Atomically checks the 23-hour cooldown and claims the daily reward
CREATE OR REPLACE FUNCTION claim_daily_reward(
    p_uid TEXT,        -- The user's ID
    p_new_level INTEGER, -- The new level to set after claiming
    p_new_exp INTEGER    -- The new XP to set after claiming
)
RETURNS JSONB AS $$ -- Returns a JSON object with the result so Python can read it easily
DECLARE
    v_last_claim TIMESTAMPTZ; -- When the user last claimed their daily reward
    v_seconds_since_claim FLOAT; -- How many seconds have passed since the last claim
    v_now TIMESTAMPTZ := NOW(); -- Capture the current time in UTC once so it's consistent throughout the function
    v_new_streak INTEGER; -- The updated consecutive-day streak after this claim
    v_streak_before_break INTEGER := 0; -- The streak value just before it broke, written to premium_perks for shield restoration
BEGIN
    -- Lock the row with FOR UPDATE so no other request can read or write this user's row until the function finishes
    SELECT last_daily_claim INTO v_last_claim
    FROM users WHERE uid = p_uid FOR UPDATE;

    -- Only check the cooldown if the user has claimed before
    IF v_last_claim IS NOT NULL THEN
        -- Calculate how many seconds have passed since their last claim
        v_seconds_since_claim := EXTRACT(EPOCH FROM (v_now - v_last_claim));

        -- 82800 seconds = 23 hours
        IF v_seconds_since_claim < 82800 THEN
            -- Not enough time has passed, return how many seconds they still need to wait
            RETURN jsonb_build_object(
                'claimed', false,
                'reason', 'cooldown',
                'seconds_remaining', (82800 - v_seconds_since_claim)::INTEGER,
                'daily_streak', 0 -- unused (added for consistency)
            );
        END IF;
    END IF;

    -- Compute the new streak: if they claimed within the last 48 hours, keep the streak going.
    -- Otherwise they missed a day and it resets to 1.
    -- 172800 seconds = 48 hours. 48 instead of 24 gives a one-day grace period so a user who
    -- claims at 11pm one day and 1am two days later doesn't lose their streak unfairly.
    IF v_last_claim IS NOT NULL AND EXTRACT(EPOCH FROM (v_now - v_last_claim)) < 172800 THEN
        SELECT streak + 1 INTO v_new_streak FROM streaks WHERE uid = p_uid AND streak_type = 'daily_consecutive_streak';
        IF NOT FOUND THEN
            v_new_streak := 1;
        END IF;
    ELSE
        -- Streak broke: save the old value to premium_perks so a shield can restore it later (premium users only)
        SELECT streak INTO v_streak_before_break FROM streaks WHERE uid = p_uid AND streak_type = 'daily_consecutive_streak';
        IF FOUND AND v_streak_before_break > 0 THEN
            IF EXISTS (SELECT 1 FROM users WHERE uid = p_uid AND is_premium = true) THEN
                INSERT INTO premium_perks (uid, shield_count, shields_reset_at, streak_before_break)
                VALUES (p_uid, 3, date_trunc('month', v_now) + interval '1 month', v_streak_before_break)
                ON CONFLICT (uid) DO UPDATE SET streak_before_break = v_streak_before_break;
            END IF;
        END IF;
        v_new_streak := 1;
    END IF;

    -- All fields are updated in a single UPDATE so they are never partially applied.
    -- e.g. level can never update without exp_points also updating
    UPDATE users SET
        level = p_new_level,
        exp_points = p_new_exp,
        last_daily_claim = v_now     -- Record when they claimed so the cooldown starts now
    WHERE uid = p_uid;

    -- Update the streak in the streaks table
    INSERT INTO streaks (uid, streak_type, streak, highest_streak, last_date)
    VALUES (p_uid, 'daily_consecutive_streak', v_new_streak, v_new_streak, v_now::DATE)
    ON CONFLICT (uid, streak_type)
    DO UPDATE SET streak = v_new_streak, highest_streak = GREATEST(streaks.highest_streak, v_new_streak), last_date = v_now::DATE;

    -- Track achievements atomically with the claim so a crash between the RPC and Python can't leave them out of sync
    INSERT INTO achievement_progress (uid, achievement_id, progress)
    VALUES (p_uid, 'daily_claims', 1)
    ON CONFLICT (uid, achievement_id) DO UPDATE
    SET progress = achievement_progress.progress + 1;

    INSERT INTO achievement_progress (uid, achievement_id, progress)
    VALUES (p_uid, 'level', p_new_level)
    ON CONFLICT (uid, achievement_id) DO UPDATE
    SET progress = p_new_level;

    INSERT INTO achievement_progress (uid, achievement_id, progress)
    VALUES (p_uid, 'daily_claim_streak', v_new_streak)
    ON CONFLICT (uid, achievement_id) DO UPDATE
    SET progress = v_new_streak;

    -- Return success with the new state so Python doesn't need to do another fetch
    RETURN jsonb_build_object(
        'claimed', true,
        'new_level', p_new_level,
        'new_exp', p_new_exp,
        'claimed_at', v_now,
        'daily_streak', v_new_streak
    );
END;
$$ LANGUAGE plpgsql;

-- record_poi_visit: Atomically checks the 24-hour cooldown for a POI visit and updates XP/level and any achievement progress
CREATE OR REPLACE FUNCTION record_poi_visit(
    p_uid TEXT,          -- The user's ID
    p_poi_name TEXT,     -- The name of the POI being visited
    p_category TEXT,     -- The category of the POI (e.g. 'restaurant', 'park')
    p_new_level INTEGER, -- The new level to set after visiting
    p_new_exp INTEGER    -- The new XP to set after visiting
)
RETURNS JSONB AS $$
DECLARE
    v_last_visit TIMESTAMPTZ; -- When the user last visited this POI
    v_seconds_since FLOAT;    -- How many seconds have passed since the last visit
    v_now TIMESTAMPTZ := NOW(); -- Capture current time once in UTC for consistency
BEGIN
    -- Lock the row for this user and POI combo to prevent race conditions
    -- If no row exists yet (first visit), nothing is locked which is fine
    SELECT last_visit INTO v_last_visit
    FROM poi_visits WHERE uid = p_uid AND poi_name = p_poi_name FOR UPDATE;

    -- Only check cooldown if they've visited this POI before
    IF v_last_visit IS NOT NULL THEN
        -- Extract the time into seconds
        v_seconds_since := EXTRACT(EPOCH FROM (v_now - v_last_visit));

        -- 86400 seconds = 24 hours
        IF v_seconds_since < 86400 THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Already visited in the last 24 hours',
                'seconds_remaining', (86400 - v_seconds_since)::INTEGER
            );
        END IF;
    END IF;

    -- Upsert the visit timestamp and category, increment times_visited on each check-in
    INSERT INTO poi_visits (uid, poi_name, last_visit, category, times_visited)
    VALUES (p_uid, p_poi_name, v_now, p_category, 1)
    ON CONFLICT (uid, poi_name) DO UPDATE SET
        last_visit = v_now,
        category = p_category,
        times_visited = poi_visits.times_visited + 1;

    -- Update the user's XP and level atomically in the same transaction
    UPDATE users SET
        level = p_new_level,
        exp_points = p_new_exp
    WHERE uid = p_uid;

    -- Update the user's "level" cell of the achievements_progress table
    INSERT INTO achievement_progress (uid, achievement_id, progress)
    VALUES (p_uid, 'level', p_new_level)
    ON CONFLICT (uid, achievement_id) DO UPDATE 
    SET progress = p_new_level;

    -- Update the user's "poi_visits" cell of the achievements_progress table
    INSERT INTO achievement_progress (uid, achievement_id, progress)
    VALUES (p_uid, 'poi_visits', 1)
    ON CONFLICT (uid, achievement_id) DO UPDATE 
    SET progress = achievement_progress.progress + 1;

    -- Update the user's "poi_categories" cell of the achievements_progress table
    INSERT INTO achievement_progress (uid, achievement_id, progress)
    VALUES (p_uid, 'poi_categories', (SELECT COUNT(DISTINCT category) FROM poi_visits WHERE uid = p_uid))
    ON CONFLICT (uid, achievement_id) DO UPDATE
    SET progress = (SELECT COUNT(DISTINCT category) FROM poi_visits WHERE uid = p_uid);

    -- Update the user's "poi_regular" cell of the achievements_progress table
    INSERT INTO achievement_progress (uid, achievement_id, progress)
    VALUES (p_uid, 'poi_regular', (SELECT MAX(times_visited) FROM poi_visits WHERE uid = p_uid))
    ON CONFLICT (uid, achievement_id) DO UPDATE
    SET progress = (SELECT MAX(times_visited) FROM poi_visits WHERE uid = p_uid);

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql;

-- consume_tokens: atomically consumes tokens from the rate_limits table
-- returns TRUE if tokens were consumed, FALSE if there weren't enough
CREATE OR REPLACE FUNCTION consume_tokens(p_id TEXT, p_amount INT, p_max_tokens INT)
RETURNS BOOLEAN AS $$
DECLARE
    v_current_tokens INT;
    v_last_refill TIMESTAMPTZ;
    v_now TIMESTAMPTZ := NOW();
BEGIN
    -- lock the row for this document so no other transaction can read/write it at the same time
    SELECT current_tokens, last_refill_time
    INTO v_current_tokens, v_last_refill
    FROM rate_limits WHERE id = p_id FOR UPDATE;

    IF NOT FOUND THEN
        -- row doesn't exist yet, so this is first time setup
        -- insert with tokens already decremented by the requested amount
        INSERT INTO rate_limits (id, current_tokens, last_refill_time)
        VALUES (p_id, p_max_tokens - p_amount, v_now);
        RETURN TRUE;
    END IF;

    -- check if 24 hours have passed since the last refill
    -- if so, reset tokens back to max and update the refill timestamp
    IF (v_now - v_last_refill) >= INTERVAL '1 day' THEN
        v_current_tokens := p_max_tokens;
        v_last_refill := v_now;
    END IF;

    -- not enough tokens to consume, return false without modifying anything
    IF v_current_tokens < p_amount THEN
        RETURN FALSE;
    END IF;

    -- enough tokens available, so deduct the requested amount and write back
    -- last_refill_time is also written back in case it was just reset above
    UPDATE rate_limits
    SET current_tokens = v_current_tokens - p_amount,
        last_refill_time = v_last_refill
    WHERE id = p_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


-- refund_tokens: atomically refunds tokens back to the rate_limits table
-- called when a search fails so the token isn't wasted
-- returns TRUE if the refund succeeded, FALSE if the row didn't exist
CREATE OR REPLACE FUNCTION refund_tokens(p_id TEXT, p_amount INT, p_max_tokens INT)
RETURNS BOOLEAN AS $$
DECLARE
    v_current_tokens INT;
BEGIN
    -- lock the row so no other transaction can modify it at the same time
    SELECT current_tokens INTO v_current_tokens
    FROM rate_limits WHERE id = p_id FOR UPDATE;

    -- cannot refund if the row doesn't exist yet
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- add the tokens back, but cap at max to prevent exceeding the limit
    UPDATE rate_limits
    SET current_tokens = LEAST(v_current_tokens + p_amount, p_max_tokens)
    WHERE id = p_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- upsert_achievement_progress: atomically updates the user's achievement_progress row for
-- the specified achievement. if the row already exists, it adds onto its progress value, and
-- if it is a fresh row, the increment amount is its new progress value
CREATE OR REPLACE FUNCTION upsert_achievement_progress (
    p_uid TEXT,                  -- the user's ID
    p_achievement_id TEXT,       -- the achievement category (e.g. 'poi_visits', 'food_streak')
    p_increment_amount INTEGER   -- how much to add to the current progress
)
RETURNS INTEGER AS $$
BEGIN
    -- Insert a new progress row if one doesn't exist yet,
    -- or add to the existing progress if it does (no read needed, fully atomic)
    INSERT INTO achievement_progress (uid, achievement_id, progress)
    VALUES (p_uid, p_achievement_id, p_increment_amount)
    ON CONFLICT (uid, achievement_id)
    DO UPDATE SET progress = achievement_progress.progress + p_increment_amount;
    RETURN (SELECT progress FROM achievement_progress WHERE uid = p_uid AND achievement_id = p_achievement_id);
END;
$$ LANGUAGE plpgsql;

-- set_achievement_progress: like upsert_achievement_progress but sets the progress to an
-- exact value instead of incrementing. used for achievements like streaks where the value
-- can go down (e.g. a streak resets to 1 when the user misses a day)
CREATE OR REPLACE FUNCTION set_achievement_progress (
    p_uid TEXT,                  -- the user's ID
    p_achievement_id TEXT,       -- the achievement category (e.g. 'daily_claim_streak')
    p_value INTEGER              -- the exact progress value to set
)
RETURNS INTEGER AS $$
BEGIN
    INSERT INTO achievement_progress (uid, achievement_id, progress)
    VALUES (p_uid, p_achievement_id, p_value)
    ON CONFLICT (uid, achievement_id)
    DO UPDATE SET progress = p_value;
    RETURN p_value;
END;
$$ LANGUAGE plpgsql;

-- update_food_streak: computes the food logging streak using today's real date, not the date on the food log
-- Called from Python after a food log upsert. Returns the new streak value
CREATE OR REPLACE FUNCTION update_food_streak(
    p_uid TEXT         -- the user's ID
)
RETURNS INTEGER AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_last_date DATE;
    v_current_streak INTEGER;
    v_new_streak INTEGER;
BEGIN
    -- Lock the streak row so no other transaction can update it at the same time
    SELECT last_date, streak INTO v_last_date, v_current_streak
    FROM streaks WHERE uid = p_uid AND streak_type = 'food_streak' FOR UPDATE;

    IF FOUND THEN
        IF v_today = v_last_date THEN
            -- Already logged today, no change
            RETURN v_current_streak;
        ELSIF v_today = v_last_date + 1 THEN
            -- Consecutive day, continue the streak
            v_new_streak := v_current_streak + 1;
        ELSE
            -- Gap in dates, reset
            v_new_streak := 1;
        END IF;
    ELSE
        -- No streak row yet, start at 1
        v_new_streak := 1;
    END IF;

    -- Upsert the streak row with today as last_date
    INSERT INTO streaks (uid, streak_type, streak, highest_streak, last_date)
    VALUES (p_uid, 'food_streak', v_new_streak, v_new_streak, v_today)
    ON CONFLICT (uid, streak_type)
    DO UPDATE SET streak = v_new_streak, highest_streak = GREATEST(streaks.highest_streak, v_new_streak), last_date = v_today;

    RETURN v_new_streak;
END;
$$ LANGUAGE plpgsql;

-- add_fcm_token: atomically appends a token to the fcm_tokens array if not already present
-- array_append with a NOT ANY guard prevents duplicates without needing a read first
CREATE OR REPLACE FUNCTION add_fcm_token(p_uid TEXT, p_token TEXT)
RETURNS void AS $$
    UPDATE users
    SET fcm_tokens = array_append(fcm_tokens, p_token)
    WHERE uid = p_uid AND NOT (p_token = ANY(fcm_tokens));
$$ LANGUAGE sql;

-- remove_fcm_token: atomically removes all occurrences of a token from the fcm_tokens array
-- array_remove is a no-op if the token is not present, so no guard is needed
CREATE OR REPLACE FUNCTION remove_fcm_token(p_uid TEXT, p_token TEXT)
RETURNS void AS $$
    UPDATE users
    SET fcm_tokens = array_remove(fcm_tokens, p_token)
    WHERE uid = p_uid;
$$ LANGUAGE sql;

-- experience_needed: mirrors the Dart/Python formula so SQL can calculate XP thresholds
CREATE OR REPLACE FUNCTION experience_needed(p_level INTEGER)
RETURNS INTEGER AS $$
DECLARE
    v_raw FLOAT;
BEGIN
    v_raw := 100.0 * POWER(1.25, p_level - 0.5) * 1.05 + (p_level * 10);
    RETURN (ROUND(v_raw / 10.0) * 10)::INTEGER;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- use_referral: atomically validates and inserts a referral, awards XP to the referee, ensures one-way relationships and no duplicate referrals
CREATE OR REPLACE FUNCTION use_referral(p_referee_uid TEXT, p_referral_code TEXT)
RETURNS JSONB AS $$
DECLARE
    v_referrer_uid TEXT;
    v_mutual_exists BOOLEAN;
    v_referee_level INTEGER;
    v_referee_exp INTEGER;
    v_xp_needed INTEGER;
    v_xp_award INTEGER;
    v_new_level INTEGER;
    v_new_exp INTEGER;
BEGIN
    -- Check the referee exists and has reached level 3, lock their row
    SELECT level, exp_points INTO v_referee_level, v_referee_exp
    FROM users WHERE uid = p_referee_uid FOR UPDATE;

    IF v_referee_level IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    IF v_referee_level < 3 THEN
        RAISE EXCEPTION 'You must reach level 3 before using a referral code';
    END IF;

    -- Check the referee hasn't already used a referral code
    IF EXISTS (SELECT 1 FROM referrals WHERE referee_uid = p_referee_uid) THEN
        RAISE EXCEPTION 'You have already used a referral code';
    END IF;

    -- Lock the referrer's row and check for mutual referral in one query
    SELECT u.uid, (r.referee_uid IS NOT NULL)
    INTO v_referrer_uid, v_mutual_exists
    FROM users u
    LEFT JOIN referrals r ON r.referrer_uid = p_referee_uid AND r.referee_uid = u.uid
    WHERE u.referral_code = p_referral_code
    FOR UPDATE OF u;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid referral code';
    END IF;

    IF v_referrer_uid = p_referee_uid THEN
        RAISE EXCEPTION 'Cannot use your own referral code';
    END IF;

    IF v_mutual_exists THEN
        RAISE EXCEPTION 'Mutual referrals are not allowed';
    END IF;

    -- Calculate XP award: max(500, xp_needed_for_next_level * 0.75)
    v_xp_needed := experience_needed(v_referee_level);
    v_xp_award := GREATEST(500, (v_xp_needed * 0.75)::INTEGER);

    -- Apply XP and handle level-ups
    v_new_exp := v_referee_exp + v_xp_award;
    v_new_level := v_referee_level;
    WHILE v_new_exp >= experience_needed(v_new_level) LOOP
        v_new_exp := v_new_exp - experience_needed(v_new_level);
        v_new_level := v_new_level + 1;
    END LOOP;

    -- Update referee's level and XP
    UPDATE users SET level = v_new_level, exp_points = v_new_exp WHERE uid = p_referee_uid;

    -- Update level achievement progress for referee
    INSERT INTO achievement_progress (uid, achievement_id, progress)
    VALUES (p_referee_uid, 'level', v_new_level)
    ON CONFLICT (uid, achievement_id) DO UPDATE
    SET progress = v_new_level;

    -- Insert the referral row with referee_xp_awarded = true
    INSERT INTO referrals (referee_uid, referrer_uid, referral_code, referee_xp_awarded)
    VALUES (p_referee_uid, v_referrer_uid, p_referral_code, true);

    -- Increment the referrer's referrals achievement progress
    INSERT INTO achievement_progress (uid, achievement_id, progress)
    VALUES (v_referrer_uid, 'referrals', 1)
    ON CONFLICT (uid, achievement_id) DO UPDATE
    SET progress = achievement_progress.progress + 1;

    RETURN jsonb_build_object(
        'new_level', v_new_level,
        'new_exp', v_new_exp,
        'xp_awarded', v_xp_award
    );
END;
$$ LANGUAGE plpgsql;

-- claim_referral_reward: atomically awards XP to the referrer and marks the referral as fully complete
CREATE OR REPLACE FUNCTION claim_referral_reward(p_referrer_uid TEXT, p_referee_uid TEXT)
RETURNS JSONB AS $$
DECLARE
    v_referrer_level INTEGER;
    v_referrer_exp INTEGER;
    v_xp_needed INTEGER;
    v_xp_award INTEGER;
    v_new_level INTEGER;
    v_new_exp INTEGER;
BEGIN
    -- Lock the referrer's row and verify the referral exists and hasn't been claimed yet
    SELECT level, exp_points INTO v_referrer_level, v_referrer_exp
    FROM users WHERE uid = p_referrer_uid FOR UPDATE;

    IF NOT EXISTS (
        SELECT 1 FROM referrals
        WHERE referrer_uid = p_referrer_uid
          AND referee_uid = p_referee_uid
          AND referee_xp_awarded = true
          AND referrer_xp_awarded = false
    ) THEN
        RAISE EXCEPTION 'No pending referral reward found';
    END IF;

    -- Calculate XP award: max(500, xp_needed * 0.75)
    v_xp_needed := experience_needed(v_referrer_level);
    v_xp_award := GREATEST(500, (v_xp_needed * 0.75)::INTEGER);

    -- Apply XP and handle level-ups
    v_new_exp := v_referrer_exp + v_xp_award;
    v_new_level := v_referrer_level;
    WHILE v_new_exp >= experience_needed(v_new_level) LOOP
        v_new_exp := v_new_exp - experience_needed(v_new_level);
        v_new_level := v_new_level + 1;
    END LOOP;

    -- Update referrer's level and XP
    UPDATE users SET level = v_new_level, exp_points = v_new_exp WHERE uid = p_referrer_uid;

    -- Update level achievement progress
    INSERT INTO achievement_progress (uid, achievement_id, progress)
    VALUES (p_referrer_uid, 'level', v_new_level)
    ON CONFLICT (uid, achievement_id) DO UPDATE
    SET progress = v_new_level;

    -- Mark the referral as fully complete
    UPDATE referrals SET referrer_xp_awarded = true, referrer_notified = true
    WHERE referrer_uid = p_referrer_uid AND referee_uid = p_referee_uid;

    RETURN jsonb_build_object(
        'new_level', v_new_level,
        'new_exp', v_new_exp,
        'xp_awarded', v_xp_award
    );
END;
$$ LANGUAGE plpgsql;

-- claim_achievement: atomically claims the achievement by creating a row for the specified achievement in achievement_claims table
-- if the row creation is successful, it means the achievement was not added before and was now added and thus claimed.
-- if the row creation is unsuccessful, it means the achievement is already claimed, so it won't be claimed again
CREATE OR REPLACE FUNCTION claim_achievement (
    p_uid TEXT,                 -- the user's ID
    p_achievement_id TEXT,      -- the achievement category
    p_tier INTEGER              -- the tier being claimed
)
RETURNS void as $$
DECLARE
    v_progress INTEGER; -- To store the user's progress cell for this achievement
    v_rows INTEGER;     -- How many rows the INSERT actually affected (0 if DO NOTHING fired)
    v_streak_type TEXT; -- Mapped streak_type for streak-based achievements
BEGIN
    -- Streak achievements must check highest_streak (not current progress) so a broken streak
    -- doesn't block claiming a tier the user legitimately reached in the past
    v_streak_type := CASE p_achievement_id
        WHEN 'daily_claim_streak' THEN 'daily_consecutive_streak'
        WHEN 'food_streak'        THEN 'food_streak'
        WHEN 'workout_streak'     THEN 'workout_streak'
        ELSE NULL
    END;

    IF v_streak_type IS NOT NULL THEN
        SELECT highest_streak INTO v_progress FROM streaks WHERE uid = p_uid AND streak_type = v_streak_type;
    ELSE
        -- Lock the progress row so no other transaction can claim at the same time
        SELECT progress INTO v_progress FROM achievement_progress WHERE uid = p_uid AND achievement_id = p_achievement_id FOR UPDATE;
    END IF;

    -- make sure progress >= tier to ensure the claim is eligible but has not occurred
    IF v_progress >= p_tier THEN
        -- valid, so carry out the claim
        INSERT INTO achievement_claims (uid, achievement_id, tier, claimed_at)
        VALUES (p_uid, p_achievement_id, p_tier, NOW())
        ON CONFLICT (uid, achievement_id, tier)
        DO NOTHING; -- If the achievement is already claimed, the row already exists, so return
        GET DIAGNOSTICS v_rows = ROW_COUNT;
        -- Only increment total_achievements if this was a new claim, not a duplicate
        IF v_rows > 0 THEN
            INSERT INTO achievement_progress (uid, achievement_id, progress)
            VALUES (p_uid, 'total_achievements', 1)
            ON CONFLICT (uid, achievement_id) DO UPDATE
            SET progress = achievement_progress.progress + 1;
        END IF;
    ELSE
        RAISE EXCEPTION 'Progress not met';
    END IF;
END
$$ LANGUAGE plpgsql;

-- get_xp_standing: returns the user's XP rank and total user count
-- rank is determined by: level DESC, exp_points DESC, uid ASC
CREATE OR REPLACE FUNCTION get_xp_standing(p_level INT, p_exp_points INT, p_uid TEXT)
RETURNS TABLE(rank BIGINT, total BIGINT) LANGUAGE sql STABLE AS $$
  SELECT
    (SELECT COUNT(*) + 1 FROM users
     WHERE level > p_level
        OR (level = p_level AND exp_points > p_exp_points)
        OR (level = p_level AND exp_points = p_exp_points AND uid < p_uid)) AS rank,
    (SELECT COUNT(*) FROM users) AS total;
$$;

-- get_foods_standing: returns the user's rank by all-time food log count and total user count
CREATE OR REPLACE FUNCTION get_foods_standing(p_uid TEXT)
RETURNS TABLE(rank BIGINT, total BIGINT) LANGUAGE sql STABLE AS $$
  WITH counts AS (
    SELECT uid, COUNT(*) AS cnt FROM food_logs_v2 GROUP BY uid
  )
  SELECT
    (SELECT COUNT(*) + 1 FROM counts WHERE cnt > COALESCE((SELECT cnt FROM counts WHERE uid = p_uid), 0)) AS rank,
    (SELECT COUNT(DISTINCT uid) FROM food_logs_v2) AS total;
$$;

-- get_workouts_standing: returns the user's rank by all-time workout count and total user count
CREATE OR REPLACE FUNCTION get_workouts_standing(p_uid TEXT)
RETURNS TABLE(rank BIGINT, total BIGINT) LANGUAGE sql STABLE AS $$
  WITH counts AS (
    SELECT uid, COUNT(*) AS cnt FROM workouts GROUP BY uid
  )
  SELECT
    (SELECT COUNT(*) + 1 FROM counts WHERE cnt > COALESCE((SELECT cnt FROM counts WHERE uid = p_uid), 0)) AS rank,
    (SELECT COUNT(DISTINCT uid) FROM workouts) AS total;
$$;

-- award_ad_xp: Atomically awards XP for a verified rewarded ad watch
-- Called only by the AdMob SSV backend route, never by the client directly
CREATE OR REPLACE FUNCTION award_ad_xp(
    p_uid TEXT,
    p_new_level INTEGER,
    p_new_exp INTEGER
)
RETURNS VOID AS $$
BEGIN
    -- Lock the row so two simultaneous SSV callbacks can't double-award
    PERFORM uid FROM users WHERE uid = p_uid FOR UPDATE;

    UPDATE users
    SET level = p_new_level, exp_points = p_new_exp
    WHERE uid = p_uid;
END
$$ LANGUAGE plpgsql;

-- search_exercises: searches the public exercise library plus the calling user's custom exercises
CREATE OR REPLACE FUNCTION search_exercises(
    p_uid TEXT DEFAULT '',        -- uid of the requesting user, used to include their custom exercises
    p_q TEXT DEFAULT '',          -- name search string, empty means no filter
    p_equipment TEXT[] DEFAULT '{}',  -- e.g. '{barbell,dumbbell}', empty means no filter
    p_muscle TEXT[] DEFAULT '{}',     -- e.g. '{chest,triceps}', empty means no filter
    p_level TEXT[] DEFAULT '{}',      -- e.g. '{beginner}', empty means no filter
    p_limit INT DEFAULT 30
)
RETURNS TABLE (
    id INT,
    name TEXT,
    category TEXT,
    force TEXT,
    level TEXT,
    mechanic TEXT,
    equipment TEXT,
    instructions TEXT[],
    primary_muscle TEXT,
    secondary_muscles TEXT[],
    is_custom BOOLEAN
)
LANGUAGE SQL
SECURITY DEFINER
AS $$
    SELECT
        e.id,
        e.name,
        e.category,
        e.force,
        e.level,
        e.mechanic,
        e.equipment,
        e.instructions,
        MAX(CASE WHEN em.muscle_type = 'primary' THEN mg.name END) AS primary_muscle,              -- one primary muscle per exercise
        ARRAY_REMOVE(ARRAY_AGG(DISTINCT CASE WHEN em.muscle_type = 'secondary' THEN mg.name END), NULL) AS secondary_muscles,  -- all secondary muscles as an array, NULLs removed
        bool_or(e.is_custom) AS is_custom
    FROM exercises e
    LEFT JOIN exercise_muscles em ON em.exercise_id = e.id  -- join muscle mappings (may be 0 or many rows per exercise)
    LEFT JOIN muscle_groups mg ON mg.id = em.muscle_id      -- resolve muscle group name from id
    WHERE (e.is_public = true OR (p_uid <> '' AND e.created_by = p_uid))  -- built-in or the user's own custom exercises
      AND (p_q = '' OR e.name ILIKE '%' || p_q || '%')     -- name filter, skipped if query is empty
      AND (array_length(p_equipment, 1) IS NULL OR LOWER(e.equipment) = ANY(p_equipment))  -- equipment filter, skipped if array is empty
      AND (array_length(p_level, 1) IS NULL OR LOWER(e.level) = ANY(p_level))              -- level filter, skipped if array is empty
    GROUP BY e.id, e.name, e.category, e.force, e.level, e.mechanic, e.equipment, e.instructions  -- group so AGG functions work per exercise
    HAVING (
        array_length(p_muscle, 1) IS NULL OR               -- muscle filter goes in HAVING because it depends on the aggregated join
        BOOL_OR(LOWER(mg.name) = ANY(p_muscle))            -- BOOL_OR checks if any of the exercise's muscles match the filter
    )
    ORDER BY e.name
    LIMIT p_limit;
$$;

-- log_workout: atomically inserts the workout, exercises, sets, updates exercise stats,
-- awards XP scaled to level and duration, updates workout streak, and tracks achievements.
-- p_exercises is a JSONB array of {exercise_id, exercise_name, sets: [{set_number, reps, weight_kg}]}
CREATE OR REPLACE FUNCTION log_workout(
    p_uid              TEXT,
    p_name             TEXT,
    p_date             DATE,
    p_duration_seconds INTEGER,
    p_exercises        JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_workout_id        UUID;
    v_exercise          JSONB;
    v_set               JSONB;
    v_ex_id             UUID;
    v_exercise_name     TEXT;
    v_set_count         INTEGER;
    v_best_weight       NUMERIC;
    v_best_reps         INTEGER;
    v_last_weight       NUMERIC;
    v_last_reps         INTEGER;
    v_session_volume    NUMERIC;
    v_estimated_1rm     NUMERIC;
    v_ex_order          INTEGER := 0;
    -- existing PR values read before sets are inserted, used to mark is_personal_record
    v_existing_pr_weight NUMERIC;
    v_existing_pr_reps   INTEGER;
    -- XP calculation
    v_level             INTEGER;
    v_exp               INTEGER;
    v_daily_base        NUMERIC;
    v_base_xp           INTEGER;
    v_duration_bonus    INTEGER;
    v_xp_gained         INTEGER := 0;
    v_new_level         INTEGER;
    v_new_exp           INTEGER;
    -- workout streak
    v_last_date                DATE;
    v_current_streak           INTEGER;
    v_new_streak               INTEGER;
    v_today                    DATE := CURRENT_DATE;
    v_xp_already_awarded_today BOOLEAN;
    -- double session / muscle variety
    v_today_workout_count      INTEGER;
    v_distinct_muscles         INTEGER;
BEGIN
    -- check if the user already completed a workout today (XP is once per day)
    SELECT EXISTS (
        SELECT 1 FROM workouts
        WHERE uid = p_uid AND completed = true AND date = v_today
    ) INTO v_xp_already_awarded_today;

    -- insert workout row
    INSERT INTO workouts (uid, name, date, duration_seconds, completed)
    VALUES (p_uid, p_name, p_date, p_duration_seconds, true)
    RETURNING workout_id INTO v_workout_id;

    -- insert exercises and sets
    FOR v_exercise IN SELECT * FROM jsonb_array_elements(p_exercises) LOOP
        v_exercise_name := v_exercise->>'exercise_name';

        INSERT INTO workout_exercises (workout_id, exercise_id, exercise_name, exercise_order)
        VALUES (
            v_workout_id,
            NULLIF(v_exercise->>'exercise_id', '')::INTEGER,
            v_exercise_name,
            v_ex_order
        )
        RETURNING workout_exercise_id INTO v_ex_id;

        v_ex_order      := v_ex_order + 1;
        v_set_count     := 0;
        v_best_weight   := NULL;
        v_best_reps     := NULL;
        v_last_weight   := NULL;
        v_last_reps     := NULL;
        v_session_volume := 0;

        -- read existing PRs before inserting sets to mark is_personal_record correctly
        SELECT pr_weight_kg, pr_reps
        INTO v_existing_pr_weight, v_existing_pr_reps
        FROM user_exercise_stats
        WHERE uid = p_uid AND exercise_name = v_exercise_name;

        FOR v_set IN SELECT * FROM jsonb_array_elements(v_exercise->'sets') LOOP
            INSERT INTO workout_sets (workout_exercise_id, set_number, reps, weight_kg, set_type, is_personal_record)
            VALUES (
                v_ex_id,
                (v_set->>'set_number')::INTEGER,
                NULLIF(v_set->>'reps', '')::INTEGER,
                NULLIF(v_set->>'weight_kg', '')::NUMERIC,
                'working',
                -- mark as PR if this set beats the stored weight or reps record
                (
                    (NULLIF(v_set->>'weight_kg', '')::NUMERIC IS NOT NULL AND (v_existing_pr_weight IS NULL OR NULLIF(v_set->>'weight_kg', '')::NUMERIC > v_existing_pr_weight))
                    OR
                    (NULLIF(v_set->>'reps', '')::INTEGER IS NOT NULL AND (v_existing_pr_reps IS NULL OR NULLIF(v_set->>'reps', '')::INTEGER > v_existing_pr_reps))
                )
            );

            v_set_count := v_set_count + 1;
            v_last_weight := NULLIF(v_set->>'weight_kg', '')::NUMERIC;
            v_last_reps   := NULLIF(v_set->>'reps', '')::INTEGER;

            IF v_last_weight IS NOT NULL AND v_last_reps IS NOT NULL THEN
                v_session_volume := v_session_volume + (v_last_weight * v_last_reps);
                v_best_weight := GREATEST(COALESCE(v_best_weight, v_last_weight), v_last_weight);
                v_best_reps   := GREATEST(COALESCE(v_best_reps, v_last_reps), v_last_reps);
            END IF;
        END LOOP;

        -- Epley 1RM estimate
        IF v_best_weight IS NOT NULL AND v_best_reps IS NOT NULL THEN
            v_estimated_1rm := ROUND(v_best_weight * (1.0 + v_best_reps / 30.0), 2);
        ELSE
            v_estimated_1rm := NULL;
        END IF;

        -- upsert exercise stats with PR tracking
        INSERT INTO user_exercise_stats (
            uid, exercise_name,
            pr_weight_kg, pr_reps, pr_volume_kg, estimated_1rm,
            last_weight_kg, last_reps, last_logged_at, total_sets
        )
        VALUES (
            p_uid, v_exercise_name,
            v_best_weight, v_best_reps, ROUND(v_session_volume, 2), v_estimated_1rm,
            v_last_weight, v_last_reps, NOW(), v_set_count
        )
        ON CONFLICT (uid, exercise_name) DO UPDATE SET
            pr_weight_kg   = GREATEST(user_exercise_stats.pr_weight_kg, EXCLUDED.pr_weight_kg),
            pr_reps        = GREATEST(user_exercise_stats.pr_reps, EXCLUDED.pr_reps),
            pr_volume_kg   = GREATEST(user_exercise_stats.pr_volume_kg, EXCLUDED.pr_volume_kg),
            estimated_1rm  = GREATEST(user_exercise_stats.estimated_1rm, EXCLUDED.estimated_1rm),
            last_weight_kg = EXCLUDED.last_weight_kg,
            last_reps      = EXCLUDED.last_reps,
            last_logged_at = EXCLUDED.last_logged_at,
            total_sets     = user_exercise_stats.total_sets + EXCLUDED.total_sets;
    END LOOP;

    -- XP, streak, and achievements are only awarded once per day
    IF NOT v_xp_already_awarded_today THEN
        -- lock user row for XP update
        SELECT level, exp_points INTO v_level, v_exp
        FROM users WHERE uid = p_uid FOR UPDATE;

        -- XP formula: 40% of daily reward base + up to 30% of that as duration bonus (scales with level)
        -- daily reward base mirrors calculate_daily_reward_xp in progression_service.py: 25*level + 2*randint(1,level)
        -- use level as the random seed stand-in for determinism (no randomness needed in SQL)
        v_daily_base     := 25.0 * v_level + 2.0 * v_level;
        v_base_xp        := ROUND(v_daily_base * 0.4)::INTEGER;
        v_duration_bonus := ROUND(v_base_xp * LEAST(p_duration_seconds::NUMERIC / 3600.0, 0.3))::INTEGER;
        v_xp_gained      := v_base_xp + v_duration_bonus;

        -- apply level-ups
        v_new_exp   := v_exp + v_xp_gained;
        v_new_level := v_level;
        WHILE v_new_exp >= experience_needed(v_new_level) LOOP
            v_new_exp   := v_new_exp - experience_needed(v_new_level);
            v_new_level := v_new_level + 1;
        END LOOP;

        UPDATE users SET level = v_new_level, exp_points = v_new_exp WHERE uid = p_uid;

        -- update workout streak
        SELECT last_date, streak INTO v_last_date, v_current_streak
        FROM streaks WHERE uid = p_uid AND streak_type = 'workout_streak' FOR UPDATE;

        IF FOUND THEN
            IF v_today = v_last_date THEN
                v_new_streak := v_current_streak;
            ELSIF v_today = v_last_date + 1 THEN
                v_new_streak := v_current_streak + 1;
            ELSE
                v_new_streak := 1;
            END IF;
        ELSE
            v_new_streak := 1;
        END IF;

        INSERT INTO streaks (uid, streak_type, streak, highest_streak, last_date)
        VALUES (p_uid, 'workout_streak', v_new_streak, v_new_streak, v_today)
        ON CONFLICT (uid, streak_type) DO UPDATE SET
            streak         = v_new_streak,
            highest_streak = GREATEST(streaks.highest_streak, v_new_streak),
            last_date      = v_today;

        INSERT INTO achievement_progress (uid, achievement_id, progress)
        VALUES (p_uid, 'workouts_logged', 1)
        ON CONFLICT (uid, achievement_id) DO UPDATE
        SET progress = achievement_progress.progress + 1;

        INSERT INTO achievement_progress (uid, achievement_id, progress)
        VALUES (p_uid, 'workout_streak', v_new_streak)
        ON CONFLICT (uid, achievement_id) DO UPDATE
        SET progress = v_new_streak;

        INSERT INTO achievement_progress (uid, achievement_id, progress)
        VALUES (p_uid, 'level', v_new_level)
        ON CONFLICT (uid, achievement_id) DO UPDATE
        SET progress = v_new_level;
    ELSE
        -- already awarded XP today, just read current values for the return
        SELECT level, exp_points INTO v_new_level, v_new_exp
        FROM users WHERE uid = p_uid;
        SELECT streak INTO v_new_streak
        FROM streaks WHERE uid = p_uid AND streak_type = 'workout_streak';
    END IF;

    -- double_session: increment if this is the 2nd+ completed workout today
    SELECT COUNT(*) INTO v_today_workout_count
    FROM workouts
    WHERE uid = p_uid AND completed = true AND date = v_today;

    IF v_today_workout_count >= 2 THEN
        INSERT INTO achievement_progress (uid, achievement_id, progress)
        VALUES (p_uid, 'double_session', 1)
        ON CONFLICT (uid, achievement_id) DO UPDATE
        SET progress = achievement_progress.progress + 1;
    END IF;

    -- muscle_variety: count distinct primary muscles from built-in exercises in this workout
    SELECT COUNT(DISTINCT mg.name) INTO v_distinct_muscles
    FROM workout_exercises we
    JOIN exercise_muscles em ON em.exercise_id = we.exercise_id::INTEGER
    JOIN muscle_groups mg ON mg.id = em.muscle_id
    WHERE we.workout_id = v_workout_id
      AND em.muscle_type = 'primary'
      AND we.exercise_id IS NOT NULL;

    IF v_distinct_muscles >= 3 THEN
        INSERT INTO achievement_progress (uid, achievement_id, progress)
        VALUES (p_uid, 'muscle_variety', v_distinct_muscles)
        ON CONFLICT (uid, achievement_id) DO UPDATE
        SET progress = GREATEST(achievement_progress.progress, v_distinct_muscles);
    END IF;

    RETURN jsonb_build_object(
        'workout_id',   v_workout_id,
        'xp_gained',    v_xp_gained,
        'new_level',    v_new_level,
        'new_exp',      v_new_exp,
        'new_streak',   v_new_streak,
        'best_streak',  (SELECT highest_streak FROM streaks WHERE uid = p_uid AND streak_type = 'workout_streak'),
        'streak_last_date', v_today::TEXT
    );
END;
$$ LANGUAGE plpgsql;

-- update_like_count: fires after any insert or delete on the likes table and keeps the
-- denormalized like_count column on the target table in sync automatically
CREATE OR REPLACE FUNCTION update_like_count() RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.content_type = 'routine' THEN
            UPDATE workout_templates SET like_count = like_count + 1 WHERE template_id = NEW.content_id::uuid;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.content_type = 'routine' THEN
            -- GREATEST guards against like_count going negative from stale data
            UPDATE workout_templates SET like_count = GREATEST(like_count - 1, 0) WHERE template_id = OLD.content_id::uuid;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER likes_update_count
AFTER INSERT OR DELETE ON likes
FOR EACH ROW EXECUTE FUNCTION update_like_count();

-- get_every_prev_set: for each exercise name in p_exercise_names, returns all sets from the
-- most recent completed session where that exercise appears, ordered by set_number.
-- used to populate the PREVIOUS column in the active workout screen on a per-set basis.
CREATE OR REPLACE FUNCTION get_every_prev_set(p_uid TEXT, p_exercise_names TEXT[])
RETURNS TABLE(exercise_name TEXT, set_number INT, weight_kg NUMERIC, reps INT)
LANGUAGE SQL
SECURITY DEFINER
AS $$
    SELECT
        we.exercise_name,
        ws.set_number,
        ws.weight_kg,
        ws.reps
    FROM workout_sets ws
    JOIN workout_exercises we USING (workout_exercise_id)
    JOIN workouts w USING (workout_id)
    WHERE w.uid = p_uid
      AND w.completed = true
      AND we.exercise_name = ANY(p_exercise_names)
      AND w.workout_id = (
          -- most recent workout containing this exercise for this user
          SELECT w2.workout_id
          FROM workouts w2
          JOIN workout_exercises we2 USING (workout_id)
          WHERE w2.uid = p_uid
            AND w2.completed = true
            AND we2.exercise_name = we.exercise_name
          ORDER BY w2.created_at DESC
          LIMIT 1
      )
    ORDER BY we.exercise_name, ws.set_number;
$$;

-- leaderboard_by_foods: top 100 users by food log count, optionally filtered by date
DROP FUNCTION IF EXISTS leaderboard_by_foods(DATE);
CREATE OR REPLACE FUNCTION leaderboard_by_foods(since_date DATE DEFAULT NULL)
RETURNS TABLE(uid TEXT, username TEXT, level INT, exp_points INT, pfp_base64 TEXT, is_premium BOOLEAN, count BIGINT)
LANGUAGE SQL STABLE AS $$
    SELECT u.uid, u.username, u.level, u.exp_points, u.pfp_base64, u.is_premium, COUNT(*) AS count
    FROM food_logs_v2 f
    JOIN users u ON u.uid = f.uid
    WHERE (since_date IS NULL OR f.date >= since_date)
    GROUP BY u.uid, u.username, u.level, u.exp_points, u.pfp_base64, u.is_premium
    ORDER BY count DESC
    LIMIT 100;
$$;

-- leaderboard_by_workouts: top 100 users by workout count, optionally filtered by date
DROP FUNCTION IF EXISTS leaderboard_by_workouts(DATE);
CREATE OR REPLACE FUNCTION leaderboard_by_workouts(since_date DATE DEFAULT NULL)
RETURNS TABLE(uid TEXT, username TEXT, level INT, exp_points INT, pfp_base64 TEXT, is_premium BOOLEAN, count BIGINT)
LANGUAGE SQL STABLE AS $$
    SELECT u.uid, u.username, u.level, u.exp_points, u.pfp_base64, u.is_premium, COUNT(*) AS count
    FROM workouts w
    JOIN users u ON u.uid = w.uid
    WHERE (since_date IS NULL OR w.date >= since_date)
    GROUP BY u.uid, u.username, u.level, u.exp_points, u.pfp_base64, u.is_premium
    ORDER BY count DESC
    LIMIT 100;
$$;

-- get_recent_exercises: most recently used unique exercises for a user, sorted by recency
CREATE OR REPLACE FUNCTION get_recent_exercises(p_uid TEXT, p_limit INT DEFAULT 25)
RETURNS TABLE(exercise_id INT, exercise_name TEXT)
LANGUAGE SQL
SECURITY DEFINER
AS $$
    SELECT exercise_id, exercise_name
    FROM (
        SELECT DISTINCT ON (we.exercise_name)  -- one row per exercise, keeping the newest session
            we.exercise_id,
            we.exercise_name,
            w.created_at
        FROM workout_exercises we
        JOIN workouts w USING (workout_id)
        WHERE w.uid = p_uid
          AND w.completed = true
        ORDER BY we.exercise_name, w.created_at DESC, we.exercise_order ASC  -- DESC so DISTINCT ON picks the latest
    ) sub
    ORDER BY sub.created_at DESC  -- re-sort after dedup since DISTINCT ON does not preserve recency order
    LIMIT p_limit;
$$;


-- Atomically spends one streak shield from premium_perks and restores the user's
-- daily_consecutive_streak to streak_before_break (the value it held just before it broke).
-- Returns the updated shield_count and the restored streak value.
-- Bundled as one RPC so a failed streak restore cannot leave the user without a shield.
CREATE OR REPLACE FUNCTION apply_streak_shield(p_uid TEXT)
RETURNS TABLE(out_shield_count INTEGER, out_restored_streak INTEGER) AS $$
DECLARE
  v_shield_count INTEGER;
  v_restored_streak INTEGER;
BEGIN
  UPDATE premium_perks
  SET shield_count = GREATEST(shield_count - 1, 0)
  WHERE uid = p_uid
  RETURNING shield_count INTO v_shield_count;

  UPDATE streaks
  SET streak = (SELECT streak_before_break FROM premium_perks WHERE uid = p_uid),
      last_date = CURRENT_DATE
  WHERE uid = p_uid AND streak_type = 'daily_consecutive_streak'
  RETURNING streak INTO v_restored_streak;

  -- Mark today as claimed so the daily reward cannot be collected again after using a shield
  UPDATE users
  SET last_daily_claim = NOW()
  WHERE uid = p_uid;

  out_shield_count := v_shield_count;
  out_restored_streak := v_restored_streak;
  RETURN NEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
