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
    notifications_enabled BOOLEAN NOT NULL DEFAULT true   -- whether the user has push notifications turned on
    utc_offset_minutes SMALLINT DEFAULT NULL  -- user's UTC offset in minutes for snapshot scheduling
);

-- Daily food logs per user, one row per day with meals stored as JSONB arrays
CREATE TABLE food_logs (
    uid TEXT REFERENCES users(uid),    -- the user who logged the food
    date DATE,                         -- the calendar date for this log
    breakfast JSONB[],                 -- array of food items logged for breakfast
    lunch JSONB[],                     -- array of food items logged for lunch
    dinner JSONB[],                    -- array of food items logged for dinner
    snack JSONB[],                     -- array of food items logged for snacks
    PRIMARY KEY (uid, date)            -- one log per user per day
);

-- Scheduled push notification reminders set by the user
CREATE TABLE reminders (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, -- auto-generated unique ID
    uid TEXT REFERENCES users(uid),    -- the user who created the reminder
    scheduled_at TIMESTAMPTZ,          -- when the notification should be sent
    message TEXT,                      -- the notification message body
    notification_id BIGINT             -- client-side notification ID for cancellation
);

-- Tracks the last time a user visited each point of interest for the 24-hour cooldown
CREATE TABLE poi_visits (
    uid TEXT REFERENCES users(uid),    -- the user who visited the POI
    poi_name TEXT,                     -- name of the point of interest
    last_visit TIMESTAMPTZ,            -- when the user last checked in
    PRIMARY KEY (uid, poi_name)        -- one row per user per POI
);

-- Stores processed responses so retried requests return the same result instead of re-executing
CREATE TABLE idempotency_keys (
    key TEXT,                          -- client-generated unique key (e.g. UUID) per request
    uid TEXT REFERENCES users(uid),    -- scoped to the user so keys can't cross accounts
    endpoint TEXT,                     -- which route was called (e.g. "claim_daily_reward")
    response JSONB,                    -- the exact JSON response returned the first time
    created_at TIMESTAMPTZ DEFAULT now(),
    expires_at TIMESTAMPTZ,
    PRIMARY KEY (uid, key)             -- one key per user per request
);

-- Tracks user progress toward each achievement category (e.g. "level", "poi_visits")
-- One row per user per achievement category, progress updates as the user advances
CREATE TABLE achievement_progress (
    uid TEXT REFERENCES users(uid),    -- the user being tracked
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
    FOREIGN KEY (uid, achievement_id) REFERENCES achievement_progress(uid, achievement_id) -- must have a progress row first
);

-- Table to store streaks and highest_streaks for different stats per-user
CREATE TABLE streaks (
    uid TEXT REFERENCES users(uid),
    streak_type TEXT,
    streak INTEGER DEFAULT 0,
    highest_streak INTEGER DEFAULT 0,
    last_date DATE DEFAULT '1970-01-01', -- the most recent date that advanced the streak
    PRIMARY KEY (uid, streak_type) -- one row per user per streak type
);

-- Table to store one snapshot of a user's data in a json file per day
CREATE TABLE daily_snapshots (
    uid TEXT REFERENCES users(uid),
    snapshot_date DATE NOT NULL,
    data JSONB NOT NULL,
    PRIMARY KEY (uid, snapshot_date)
);
