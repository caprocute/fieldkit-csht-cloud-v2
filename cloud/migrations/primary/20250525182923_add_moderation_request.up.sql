-- moderation_request

CREATE TYPE post_type_enum AS ENUM ('discussion_post', 'data_event');

CREATE TABLE moderation_request (
    id SERIAL PRIMARY KEY,
    post_id INT NOT NULL,
    post_type post_type_enum NOT NULL,
    reported_by INT NOT NULL,
    acknowledged_by INT NULL,
    reported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acknowledged_at TIMESTAMP NULL
);

CREATE INDEX idx_moderation_request_post ON moderation_request(post_id, post_type);

ALTER TABLE moderation_request
ADD CONSTRAINT fk_moderation_request_reported_by FOREIGN KEY (reported_by) REFERENCES "user"(id) ON DELETE CASCADE;

ALTER TABLE moderation_request
ADD CONSTRAINT fk_moderation_request_acknowledged_by FOREIGN KEY (acknowledged_by) REFERENCES "user"(id) ON DELETE SET NULL;
