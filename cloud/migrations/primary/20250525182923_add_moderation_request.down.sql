ALTER TABLE moderation_request DROP CONSTRAINT fk_moderation_request_reported_by;
ALTER TABLE moderation_request DROP CONSTRAINT fk_moderation_request_acknowledged_by;
DROP INDEX IF EXISTS idx_moderation_request_post;
DROP TABLE IF EXISTS moderation_request;
DROP TYPE IF EXISTS post_type_enum CASCADE;
