-- The queries to migrate rate_limits to Postgres from Firestore
CREATE TABLE rate_limits (
    id TEXT PRIMARY KEY,
    current_tokens INTEGER,
    last_refill_time TIMESTAMPTZ
);

INSERT INTO rate_limits (id, current_tokens, last_refill_time)
VALUES ('food_logging', 5000, NOW());

-- citext extension so that usernames are case-insensitive
CREATE EXTENSION IF NOT EXISTS citext;

-- The queries to migrate users-private and users-public into a unified users to Postgres from Firestore
CREATE TABLE users (
    uid TEXT PRIMARY KEY,
    exp_points INTEGER,
    level INTEGER,
    pfp_base64 TEXT,
    username CITEXT UNIQUE,
    app_color BIGINT,
    can_claim_daily_reward BOOLEAN,
    fcm_tokens TEXT[],
    last_daily_claim TIMESTAMPTZ,
    notifications_enabled BOOLEAN
);

-- The nested parts of users become their own tables
CREATE TABLE food_logs (
    uid TEXT REFERENCES users(uid),
    date DATE,
    breakfast JSONB[],
    lunch JSONB[],
    dinner JSONB[],
    snack JSONB[],
    PRIMARY KEY (uid, date)
);

CREATE TABLE reminders (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    uid TEXT REFERENCES users(uid),
    scheduled_at TIMESTAMPTZ,
    message TEXT,
    notification_id BIGINT,
    claimed BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE poi_visits (
    uid TEXT REFERENCES users(uid),
    poi_name TEXT,
    last_visit TIMESTAMPTZ,
    PRIMARY KEY (uid, poi_name)
);

-- Stores processed responses so retried requests return the same result instead of re-executing
CREATE TABLE idempotency_keys (
    key TEXT,                          -- client-generated unique key (e.g. UUID) per request
    uid TEXT REFERENCES users(uid),    -- scoped to the user so keys can't cross accounts
    endpoint TEXT,                     -- which route was called (e.g. "claim_daily_reward")
    response JSONB,                    -- the exact JSON response returned the first time
    created_at TIMESTAMPTZ DEFAULT now(),
    expires_at TIMESTAMPTZ,
    PRIMARY KEY (uid, key)
);