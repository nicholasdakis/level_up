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
    units TEXT NOT NULL DEFAULT 'metric', -- display units preference: 'metric' or 'imperial'
    created_at TIMESTAMPTZ               -- when the user first signed up
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
-- NOTE: being migrated to food_logs_v2, do not add new columns here
CREATE TABLE food_logs (
    uid TEXT REFERENCES users(uid) ON DELETE CASCADE,
    date DATE,                         -- the calendar date for this log
    breakfast JSONB[],                 -- array of food items logged for breakfast
    lunch JSONB[],                     -- array of food items logged for lunch
    dinner JSONB[],                    -- array of food items logged for dinner
    snack JSONB[],                     -- array of food items logged for snacks
    PRIMARY KEY (uid, date)            -- one log per user per day
);

-- Normalized food logs, one row per food item (replacing food_logs after migration)
CREATE TABLE food_logs_v2 (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
    date DATE NOT NULL,
    meal TEXT NOT NULL CHECK (meal IN ('breakfast', 'lunch', 'dinner', 'snacks')),
    food_name TEXT NOT NULL,
    brand_name TEXT,
    food_description TEXT,             -- kept as display string during migration, not for parsing
    calories INTEGER,
    protein NUMERIC(6,2),
    carbs NUMERIC(6,2),
    fat NUMERIC(6,2),
    fiber NUMERIC(6,2),
    sugar NUMERIC(6,2),
    sodium NUMERIC(6,2),               -- in mg
    serving_size TEXT,                 -- e.g. "1 cup", "100g"
    logged_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_food_logs_v2_uid_date ON food_logs_v2 (uid, date);

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

-- Muscle groups used to tag exercises (e.g. chest, biceps, quadriceps)
CREATE TABLE muscle_groups (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,         -- e.g. 'chest', 'biceps brachii'
    body_region TEXT NOT NULL          -- e.g. 'upper body', 'lower body', 'core'
);

-- Seeded exercise library, plus any custom exercises created by users
CREATE TABLE exercises (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT,                     -- strength, cardio, stretching, plyometrics, etc
    force TEXT,                        -- push, pull, static
    level TEXT,                        -- beginner, intermediate, expert
    mechanic TEXT,                     -- compound, isolation
    equipment TEXT,                    -- e.g. barbell, dumbbell, body only, machine
    instructions TEXT[],               -- step-by-step instructions
    is_custom BOOLEAN DEFAULT false,   -- true if created by a user
    is_public BOOLEAN DEFAULT false,   -- true for seeded exercises and approved user submissions
    created_by TEXT REFERENCES users(uid) ON DELETE SET NULL,  -- null for seeded exercises
    CONSTRAINT exercises_name_created_by_unique UNIQUE (name, created_by)  -- one exercise name per user, null created_by rows are unaffected since NULL != NULL in Postgres
);

-- Links exercises to muscle groups, one row per muscle per exercise
CREATE TABLE exercise_muscles (
    exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    muscle_id INTEGER NOT NULL REFERENCES muscle_groups(id) ON DELETE CASCADE,
    muscle_type TEXT NOT NULL CHECK (muscle_type IN ('primary', 'secondary')),
    PRIMARY KEY (exercise_id, muscle_id)
);

-- A single workout session logged by a user
CREATE TABLE workouts (
    workout_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
    name TEXT,                              -- optional name (e.g. "Push Day")
    date DATE NOT NULL,
    duration_seconds INTEGER,               -- total session duration
    notes TEXT,
    completed BOOLEAN DEFAULT true,         -- false if the session was abandoned mid-workout
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Links exercises to a workout session, one row per exercise in the session
CREATE TABLE workout_exercises (
    workout_exercise_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_id UUID NOT NULL REFERENCES workouts(workout_id) ON DELETE CASCADE,
    exercise_id INTEGER REFERENCES exercises(id) ON DELETE SET NULL,
    exercise_name TEXT NOT NULL,            -- cached at log time so name survives exercise deletion
    exercise_order INTEGER NOT NULL         -- display order within the session
);

-- Individual sets within a workout exercise entry
CREATE TABLE workout_sets (
    set_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_exercise_id UUID NOT NULL REFERENCES workout_exercises(workout_exercise_id) ON DELETE CASCADE,
    set_number INTEGER NOT NULL,
    set_type TEXT CHECK (set_type IN ('warmup', 'working', 'failure')), -- warmup sets excluded from volume/PR calculations
    reps INTEGER,                           -- nullable: not used for cardio
    weight_kg NUMERIC(6, 2),               -- nullable: not used for bodyweight or cardio
    duration_seconds INTEGER,              -- nullable: used for timed exercises and cardio
    distance_km NUMERIC(6, 3),             -- nullable: used for cardio
    rpe NUMERIC(3, 1),                     -- rate of perceived exertion 1-10, supports half values (e.g. 7.5)
    is_personal_record BOOLEAN DEFAULT false -- true if this set broke a PR at log time
);

-- Saved workout templates (reusable routines a user can start from)
CREATE TABLE workout_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uid TEXT REFERENCES users(uid) ON DELETE CASCADE,           -- null for built-in featured routines
    name TEXT NOT NULL,
    is_public BOOLEAN DEFAULT false,                            -- true if shared publicly for others to discover and copy
    created_by TEXT REFERENCES users(uid) ON DELETE SET NULL,  -- original creator if this was copied from another user's routine
    estimated_duration_minutes INT,                             -- optional duration hint shown on browse screen
    source_template_id UUID REFERENCES workout_templates(template_id) ON DELETE SET NULL,  -- set when copied from a browse routine, null for originals
    like_count INTEGER NOT NULL DEFAULT 0,                      -- denormalized count kept in sync by the likes trigger
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Polymorphic likes table shared across all likeable content types
CREATE TABLE likes (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uid          TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
    content_type TEXT NOT NULL,  -- e.g. 'routine', 'status_post'
    content_id   TEXT NOT NULL,  -- id of the liked item in its own table
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (uid, content_type, content_id)
);

-- Index for fast like-count lookups and feed queries
CREATE INDEX IF NOT EXISTS idx_likes_content ON likes (content_type, content_id);

-- Exercises within a saved template, with default values pre-filled when the user starts a workout
CREATE TABLE workout_template_exercises (
    template_exercise_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID NOT NULL REFERENCES workout_templates(template_id) ON DELETE CASCADE,
    exercise_id INTEGER REFERENCES exercises(id) ON DELETE SET NULL,
    exercise_name TEXT NOT NULL,            -- cached so name survives exercise deletion
    exercise_order INTEGER NOT NULL,        -- display order within the template
    default_sets INTEGER,                   -- pre-filled set count when starting a workout
    default_reps INTEGER,                   -- pre-filled rep count
    default_weight_kg NUMERIC(6, 2)         -- pre-filled weight
);

-- Tracks per-user per-exercise stats: PRs, last session values, updated after each workout
CREATE TABLE user_exercise_stats (
    uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
    exercise_name TEXT NOT NULL,
    pr_weight_kg NUMERIC(6,2),               -- heaviest single weight ever lifted
    pr_reps INT,                             -- most reps in a single set
    pr_volume_kg NUMERIC(10,2),              -- best single-session volume for this exercise
    estimated_1rm NUMERIC(6,2),             -- best estimated 1RM: weight * (1 + reps/30)
    last_weight_kg NUMERIC(6,2),            -- weight from the most recent set
    last_reps INT,                           -- reps from the most recent set
    last_logged_at TIMESTAMPTZ,              -- when the exercise was last logged
    total_sets INT NOT NULL DEFAULT 0,       -- lifetime set count
    PRIMARY KEY (uid, exercise_name)
);

-- Index to speed up leaderboard rank queries at scale, matches sort order: level DESC, exp_points DESC, uid ASC
CREATE INDEX IF NOT EXISTS idx_users_rank ON users (level DESC, exp_points DESC, uid ASC);

-- Index to speed up per-user workout history queries filtered by date
CREATE INDEX IF NOT EXISTS idx_workouts_uid_date ON workouts (uid, date DESC);