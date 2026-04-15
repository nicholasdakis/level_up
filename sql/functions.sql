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
                'seconds_remaining', (82800 - v_seconds_since_claim)::INTEGER
            );
        END IF;
    END IF;

    -- Compute the new streak: if they claimed within the last 48 hours, keep the streak going.
    -- Otherwise they missed a day and it resets to 1.
    -- 172800 seconds = 48 hours
    IF v_last_claim IS NOT NULL AND EXTRACT(EPOCH FROM (v_now - v_last_claim)) < 172800 THEN
        SELECT streak + 1 INTO v_new_streak FROM streaks WHERE uid = p_uid AND streak_type = 'daily_claim_streak';
        IF NOT FOUND THEN
            v_new_streak := 1;
        END IF;
    ELSE
        v_new_streak := 1;
    END IF;

    -- All fields are updated in a single UPDATE so they are never partially applied.
    -- e.g. level can never update without exp_points also updating
    UPDATE users SET
        level = p_new_level,
        exp_points = p_new_exp,
        last_daily_claim = v_now,      -- Record when they claimed so the cooldown starts now
        can_claim_daily_reward = false  -- Prevent claiming again until the scheduler resets this
    WHERE uid = p_uid;

    -- Update the streak in the streaks table
    INSERT INTO streaks (uid, streak_type, streak, highest_streak, last_date)
    VALUES (p_uid, 'daily_claim_streak', v_new_streak, v_new_streak, v_now::DATE)
    ON CONFLICT (uid, streak_type)
    DO UPDATE SET streak = v_new_streak, highest_streak = GREATEST(streaks.highest_streak, v_new_streak), last_date = v_now::DATE;

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

-- record_poi_visit: Atomically checks the 24-hour cooldown for a POI visit and updates XP/level
CREATE OR REPLACE FUNCTION record_poi_visit(
    p_uid TEXT,          -- The user's ID
    p_poi_name TEXT,     -- The name of the POI being visited
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

    -- Upsert the visit timestamp (insert if first visit, update if returning)
    INSERT INTO poi_visits (uid, poi_name, last_visit)
    VALUES (p_uid, p_poi_name, v_now)
    ON CONFLICT (uid, poi_name) DO UPDATE SET last_visit = v_now;

    -- Update the user's XP and level atomically in the same transaction
    UPDATE users SET
        level = p_new_level,
        exp_points = p_new_exp
    WHERE uid = p_uid;

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

-- claim_achievement: atomically claims the achievement by creating a row for the specified achievement in achievement_claims table
-- if the row creation is successful, it means the achievement was not added before and was now added and thus claimed.
-- if the row creation is unsuccessful, it means the achievement is already claimed, so it won't be claimed again
CREATE OR REPLACE FUNCTION claim_achievement (
    p_uid TEXT,                 -- the user's ID
    p_achievement_id TEXT,      -- the achievement category
    p_tier INTEGER              -- the tier being claimed
)
RETURNS void as $$
DECLARE v_progress INTEGER; -- To store the user's progress cell for this achievement
BEGIN
    -- Lock the progress row so no other transaction can claim at the same time
    SELECT progress INTO v_progress FROM achievement_progress WHERE uid = p_uid AND achievement_id = p_achievement_id FOR UPDATE;
    -- make sure progress >= tier to ensure the claim is eligible but has not occurred
    IF v_progress >= p_tier THEN
    -- valid, so carry out the claim
    INSERT INTO achievement_claims (uid, achievement_id, tier, claimed_at)
    VALUES (p_uid, p_achievement_id, p_tier, NOW())
    ON CONFLICT (uid, achievement_id, tier)
    DO NOTHING; -- If the achievement is already claimed, the row already exists, so return
    ELSE
        RAISE EXCEPTION 'Progress not met';
    END IF;
END
$$ LANGUAGE plpgsql;