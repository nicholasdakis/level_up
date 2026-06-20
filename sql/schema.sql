-- Token bucket rate limiter for API endpoints (e.g. food logging AI calls)
CREATE TABLE rate_limits (
    id TEXT PRIMARY KEY,               -- identifier for the rate-limited resource (e.g. 'food_logging')
    current_tokens INTEGER,            -- how many tokens are currently available
    last_refill_time TIMESTAMPTZ       -- when tokens were last refilled
);

-- Seed the food logging rate limit with 5000 tokens
INSERT INTO rate_limits (id, current_tokens, last_refill_time)
VALUES ('food_logging', 5000, NOW());

-- citext extension so that usernames are case-insensitive
CREATE EXTENSION IF NOT EXISTS citext;

-- Core user table combining all user data into one row per user
CREATE TABLE users (
    uid TEXT PRIMARY KEY,              -- Firebase Auth UID

    exp_points INTEGER NOT NULL DEFAULT 0,   -- current XP within the user's level
    level INTEGER NOT NULL DEFAULT 1,        -- current level
    pfp_base64 TEXT,                   -- profile picture stored as a Base64-encoded string
    username CITEXT UNIQUE NOT NULL,   -- display name, case-insensitive unique
    app_color BIGINT,                  -- Flutter Color value stored as an integer
    can_claim_daily_reward BOOLEAN NOT NULL DEFAULT true,  -- whether the user can claim their daily reward
    fcm_tokens TEXT[] NOT NULL DEFAULT '{}', -- Firebase Cloud Messaging tokens for push notifications
    last_daily_claim TIMESTAMPTZ,     -- when the user last claimed their daily reward
    notifications_enabled BOOLEAN NOT NULL DEFAULT true,   -- whether the user has push notifications turned on
    utc_offset_minutes SMALLINT DEFAULT NULL,  -- user's UTC offset in minutes for snapshot scheduling
    email TEXT,                          -- user's email address, nullable for existing users who signed up before this column was added
    referral_code TEXT UNIQUE,           -- unique referral code, generated lazily on first request
    units TEXT NOT NULL DEFAULT 'metric' -- display units preference: 'metric' or 'imperial'
);

-- Tracks referrals between users; referee_uid is the primary key so a user can only be referred once
CREATE TABLE referrals (
    referee_uid TEXT PRIMARY KEY REFERENCES users(uid) ON DELETE CASCADE, -- the new user who signed up via the code
    referrer_uid TEXT REFERENCES users(uid) ON DELETE CASCADE,            -- the user who shared their code
    referral_code TEXT NOT NULL,                                          -- the code that was used
    referred_at TIMESTAMPTZ DEFAULT NOW(),                                -- when the referral happened
    referee_xp_awarded BOOLEAN NOT NULL DEFAULT false,                   -- whether the referee has received their XP bonus
    referrer_xp_awarded BOOLEAN NOT NULL DEFAULT false,                  -- whether the referrer has received their XP bonus
    referrer_notified BOOLEAN NOT NULL DEFAULT false                      -- whether the referrer has seen the notification popup
);

-- Daily food logs per user, one row per day with meals stored as JSONB arrays
CREATE TABLE food_logs (
    uid TEXT REFERENCES users(uid) ON DELETE CASCADE,
    date DATE,                         -- the calendar date for this log
    breakfast JSONB[],                 -- array of food items logged for breakfast
    lunch JSONB[],                     -- array of food items logged for lunch
    dinner JSONB[],                    -- array of food items logged for dinner
    snack JSONB[],                     -- array of food items logged for snacks
    PRIMARY KEY (uid, date)            -- one log per user per day
);

-- Daily water intake logs per user, one row per day with individual entries as a JSONB array
CREATE TABLE water_logs (
    uid TEXT REFERENCES users(uid) ON DELETE CASCADE,
    date DATE,                         -- the calendar date for this log
    entries_ml JSONB[],                -- array of {amount_ml: int} objects, one per log entry
    PRIMARY KEY (uid, date)            -- one row per user per day, upserted on each log
);

-- Daily body weight logs per user, one row per day
CREATE TABLE weight_logs (
    uid TEXT REFERENCES users(uid) ON DELETE CASCADE,
    date DATE,                         -- the calendar date for this log
    weight_kg NUMERIC(5, 2),           -- body weight in kg, converted from lbs if imperial
    PRIMARY KEY (uid, date)            -- one row per user per day, overwritten on re-log
);

-- Scheduled push notification reminders set by the user
CREATE TABLE reminders (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, -- auto-generated unique ID
    uid TEXT REFERENCES users(uid) ON DELETE CASCADE,
    scheduled_at TIMESTAMPTZ,          -- when the notification should be sent
    message TEXT,                      -- the notification message body
    notification_id BIGINT             -- client-side notification ID for cancellation
);

-- Tracks the last time a user visited each point of interest for the 24-hour cooldown
CREATE TABLE poi_visits (
    uid TEXT REFERENCES users(uid) ON DELETE CASCADE,
    poi_name TEXT,                     -- name of the point of interest
    last_visit TIMESTAMPTZ,            -- when the user last checked in
    category TEXT,                     -- POI category (e.g. 'restaurant', 'park')
    times_visited INTEGER NOT NULL DEFAULT 1, -- total check-ins at this POI
    PRIMARY KEY (uid, poi_name)        -- one row per user per POI
);

-- Stores processed responses so retried requests return the same result instead of re-executing
CREATE TABLE idempotency_keys (
    key TEXT,                          -- client-generated unique key (e.g. UUID) per request
    uid TEXT REFERENCES users(uid) ON DELETE CASCADE,
    endpoint TEXT,                     -- which route was called (e.g. "claim_daily_reward")
    response JSONB,                    -- the exact JSON response returned the first time
    created_at TIMESTAMPTZ DEFAULT now(),
    expires_at TIMESTAMPTZ,
    PRIMARY KEY (uid, key)             -- one key per user per request
);

-- Tracks user progress toward each achievement category (e.g. "level", "poi_visits")
-- One row per user per achievement category, progress updates as the user advances
CREATE TABLE achievement_progress (
    uid TEXT REFERENCES users(uid) ON DELETE CASCADE,
    achievement_id TEXT,               -- category key (e.g. 'level', 'poi_visits', 'food_streak')
    progress INTEGER NOT NULL DEFAULT 0, -- current progress toward the next tier
    PRIMARY KEY (uid, achievement_id)  -- one progress row per user per achievement category
);

-- Records which specific tiers a user has claimed within an achievement category
-- A row here means the reward was already given, preventing double claims
CREATE TABLE achievement_claims (
    uid TEXT,                          -- the user who claimed the reward
    achievement_id TEXT,               -- which achievement category
    tier INTEGER,                      -- the milestone threshold (e.g. 5, 10, 25)
    claimed_at TIMESTAMPTZ NOT NULL,   -- when the user claimed the reward
    PRIMARY KEY (uid, achievement_id, tier), -- one row per user per achievement per tier
    FOREIGN KEY (uid, achievement_id) REFERENCES achievement_progress(uid, achievement_id) ON DELETE CASCADE
);

-- Table to store streaks and highest_streaks for different stats per-user
CREATE TABLE streaks (
    uid TEXT REFERENCES users(uid) ON DELETE CASCADE,
    streak_type TEXT,
    streak INTEGER DEFAULT 0,
    highest_streak INTEGER DEFAULT 0,
    last_date DATE DEFAULT '1970-01-01', -- the most recent date that advanced the streak
    PRIMARY KEY (uid, streak_type) -- one row per user per streak type
);

-- Table to store one snapshot of a user's data in a json file per day
CREATE TABLE daily_snapshots (
    uid TEXT REFERENCES users(uid) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    data JSONB NOT NULL,
    PRIMARY KEY (uid, snapshot_date)
);

-- Table to store a user's nutritional goals
CREATE TABLE goals (
    uid TEXT PRIMARY KEY REFERENCES users(uid) ON DELETE CASCADE,
    calories_goal INTEGER,
    protein_goal INTEGER,
    carbs_goal INTEGER,
    fat_goal INTEGER,
    weight_goal_type TEXT CHECK (weight_goal_type IN ('lose', 'gain', 'maintain')),
    weekly_workouts_goal INTEGER,        -- target number of workouts per week, nullable if not set
    water_ml_goal INTEGER,               -- daily water intake goal in ml, nullable if not set
    weight_kg_goal NUMERIC(5,2),         -- target body weight in kg, nullable if not set
    last_updated TIMESTAMPTZ NOT NULL
);

-- A single workout session logged by a user
CREATE TABLE workouts (
    workout_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
    name TEXT,                              -- optional name (e.g. "Push Day")
    date DATE NOT NULL,
    duration_minutes INTEGER,               -- total session duration
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Links exercises to a workout session, one row per exercise in the session
CREATE TABLE workout_exercises (
    workout_exercise_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_id UUID NOT NULL REFERENCES workouts(workout_id) ON DELETE CASCADE,
    exercise_id INTEGER NOT NULL,           -- Wger API exercise ID
    exercise_name TEXT NOT NULL,            -- cached at log time so it survives API changes
    exercise_order INTEGER NOT NULL         -- display order within the session
);

-- Individual sets within a workout exercise entry
CREATE TABLE workout_sets (
    set_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_exercise_id UUID NOT NULL REFERENCES workout_exercises(workout_exercise_id) ON DELETE CASCADE,
    set_number INTEGER NOT NULL,
    reps INTEGER,                           -- nullable: not used for cardio
    weight_kg NUMERIC(6, 2),               -- nullable: not used for bodyweight or cardio
    duration_seconds INTEGER,              -- nullable: used for timed exercises and cardio
    distance_km NUMERIC(6, 3)              -- nullable: used for cardio
);

-- Saved workout templates (reusable routines a user can start from)
CREATE TABLE workout_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,  -- owner of the template
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Exercises within a saved template, with default values pre-filled when the user starts a workout
CREATE TABLE workout_template_exercises (
    template_exercise_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID NOT NULL REFERENCES workout_templates(template_id) ON DELETE CASCADE,
    exercise_id INTEGER NOT NULL,           -- Wger API exercise ID
    exercise_name TEXT NOT NULL,            -- cached so it survives API changes
    exercise_order INTEGER NOT NULL,        -- display order within the template
    default_sets INTEGER,                   -- pre-filled set count when starting a workout
    default_reps INTEGER,                   -- pre-filled rep count
    default_weight_kg NUMERIC(6, 2)         -- pre-filled weight
);

-- Index to speed up leaderboard rank queries at scale, matches sort order: level DESC, exp_points DESC, uid ASC
CREATE INDEX idx_users_rank ON users (level DESC, exp_points DESC, uid ASC);