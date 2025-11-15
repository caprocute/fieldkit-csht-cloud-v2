-- moderator

CREATE TABLE fieldkit.moderator (
    id SERIAL PRIMARY KEY,
    user_id INT UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_moderator_user_id ON fieldkit.moderator(user_id);
