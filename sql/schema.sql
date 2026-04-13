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
    id TEXT PRIMARY KEY,
    uid TEXT REFERENCES users(uid),
    time TIMESTAMPTZ,
    message TEXT,
    notification_id BIGINT
);

CREATE TABLE poi_visits (
    uid TEXT REFERENCES users(uid),
    poi_name TEXT,
    last_visit TIMESTAMPTZ,
    PRIMARY KEY (uid, poi_name)
);