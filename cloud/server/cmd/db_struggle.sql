-- fieldkit.aggregated_sensor definition

-- Drop table

-- DROP TABLE fieldkit.aggregated_sensor;

CREATE TABLE fieldkit.aggregated_sensor ( id serial4 NOT NULL, "key" text NOT NULL, interestingness_priority int4 NULL, CONSTRAINT aggregated_sensor_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX aggregated_sensor_key_idx ON fieldkit.aggregated_sensor USING btree (key);


-- fieldkit.archive_history definition

-- Drop table

-- DROP TABLE fieldkit.archive_history;

CREATE TABLE fieldkit.archive_history ( id serial4 NOT NULL, archived timestamp DEFAULT now() NOT NULL, old_device_id bytea NOT NULL, new_device_id bytea NOT NULL, CONSTRAINT archive_history_pkey PRIMARY KEY (id));


-- fieldkit.counties definition

-- Drop table

-- DROP TABLE fieldkit.counties;

CREATE TABLE fieldkit.counties ( gid serial4 NOT NULL, statefp varchar(2) NULL, countyfp varchar(3) NULL, countyns varchar(8) NULL, geoid varchar(5) NULL, "name" varchar(100) NULL, namelsad varchar(100) NULL, lsad varchar(2) NULL, classfp varchar(2) NULL, mtfcc varchar(5) NULL, csafp varchar(3) NULL, cbsafp varchar(5) NULL, metdivfp varchar(5) NULL, funcstat varchar(1) NULL, aland float8 NULL, awater float8 NULL, intptlat varchar(11) NULL, intptlon varchar(12) NULL, geom public.geometry(multipolygon) NULL, CONSTRAINT counties_pkey PRIMARY KEY (gid));


-- fieldkit.countries definition

-- Drop table

-- DROP TABLE fieldkit.countries;

CREATE TABLE fieldkit.countries ( gid serial4 NOT NULL, fips varchar(2) NULL, iso2 varchar(2) NULL, iso3 varchar(3) NULL, un int2 NULL, "name" varchar(50) NULL, area int4 NULL, pop2005 int8 NULL, region int2 NULL, subregion int2 NULL, lon float8 NULL, lat float8 NULL, geom public.geometry(multipolygon, 4326) NULL, CONSTRAINT countries_pkey PRIMARY KEY (gid));
CREATE INDEX countries_geom_idx ON fieldkit.countries USING gist (geom);


-- fieldkit.firmware definition

-- Drop table

-- DROP TABLE fieldkit.firmware;

CREATE TABLE fieldkit.firmware ( id serial4 NOT NULL, "time" timestamp NOT NULL, "module" varchar(64) NOT NULL, profile varchar(64) NOT NULL, etag varchar(64) NOT NULL, url varchar NOT NULL, meta json NOT NULL, available bool DEFAULT false NOT NULL, logical_address int4 NULL, hidden bool DEFAULT false NULL, "version" text NULL, "timestamp" int4 NULL, CONSTRAINT firmware_pkey PRIMARY KEY (id));


-- fieldkit.gue_jobs definition

-- Drop table

-- DROP TABLE fieldkit.gue_jobs;

CREATE TABLE fieldkit.gue_jobs ( job_id bigserial NOT NULL, priority int2 NOT NULL, run_at timestamptz NOT NULL, job_type text NOT NULL, args json NOT NULL, error_count int4 DEFAULT 0 NOT NULL, last_error text NULL, queue text NOT NULL, created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL, CONSTRAINT gue_jobs_pkey PRIMARY KEY (job_id));
CREATE INDEX idx_gue_jobs_selector ON fieldkit.gue_jobs USING btree (queue, run_at, priority);


-- fieldkit.ingestion definition

-- Drop table

-- DROP TABLE fieldkit.ingestion;

CREATE TABLE fieldkit.ingestion ( id serial4 NOT NULL, "time" timestamp NOT NULL, upload_id varchar(64) NOT NULL, user_id int4 NOT NULL, device_id bytea NOT NULL, generation bytea NOT NULL, "type" varchar NOT NULL, "size" int4 NOT NULL, url varchar NOT NULL, blocks int8range NOT NULL, flags _int4 DEFAULT '{}'::integer[] NOT NULL, attempted timestamp NULL, completed timestamp NULL, errors bool NULL, other_errors int4 NULL, meta_errors int4 NULL, data_errors int4 NULL, total_records int4 NULL, CONSTRAINT ingestion_pkey PRIMARY KEY (id));
CREATE INDEX ingestion_time_user_id_idx ON fieldkit.ingestion USING btree ("time", user_id);


-- fieldkit.invite_token definition

-- Drop table

-- DROP TABLE fieldkit.invite_token;

CREATE TABLE fieldkit.invite_token ( "token" bytea NOT NULL, CONSTRAINT invite_token_pkey PRIMARY KEY (token));


-- fieldkit.migration_lock definition

-- Drop table

-- DROP TABLE fieldkit.migration_lock;

CREATE TABLE fieldkit.migration_lock ( id text NOT NULL, is_locked bool NOT NULL, CONSTRAINT migration_lock_pkey PRIMARY KEY (id));


-- fieldkit.migrations definition

-- Drop table

-- DROP TABLE fieldkit.migrations;

CREATE TABLE fieldkit.migrations ( id serial4 NOT NULL, "name" text NULL, batch int4 NULL, completed_at timestamptz NULL, CONSTRAINT migrations_pkey PRIMARY KEY (id));


-- fieldkit.moderator definition

-- Drop table

-- DROP TABLE fieldkit.moderator;

CREATE TABLE fieldkit.moderator ( id serial4 NOT NULL, user_id int4 NOT NULL, created_at timestamp DEFAULT CURRENT_TIMESTAMP NULL, CONSTRAINT moderator_pkey PRIMARY KEY (id), CONSTRAINT moderator_user_id_key UNIQUE (user_id));
CREATE INDEX idx_moderator_user_id ON fieldkit.moderator USING btree (user_id);


-- fieldkit.module_meta definition

-- Drop table

-- DROP TABLE fieldkit.module_meta;

CREATE TABLE fieldkit.module_meta ( id serial4 NOT NULL, "key" text NOT NULL, manufacturer int4 NOT NULL, kinds _int4 NOT NULL, "version" _int4 NOT NULL, internal bool NOT NULL, "ordering" int4 NOT NULL, CONSTRAINT module_meta_pkey PRIMARY KEY (id));


-- fieldkit.project definition

-- Drop table

-- DROP TABLE fieldkit.project;

CREATE TABLE fieldkit.project ( id serial4 NOT NULL, "name" varchar(100) NOT NULL, description text DEFAULT ''::text NOT NULL, goal varchar(100) DEFAULT ''::character varying NOT NULL, "location" varchar(100) DEFAULT ''::character varying NOT NULL, tags varchar(100) DEFAULT ''::character varying NOT NULL, start_time timestamp NULL, end_time timestamp NULL, media_url varchar(255) NULL, media_content_type varchar(255) NULL, privacy int4 NOT NULL, bounds json NULL, show_stations bool DEFAULT false NOT NULL, community_ranking int4 NOT NULL, CONSTRAINT project_pkey PRIMARY KEY (id));


-- fieldkit.provision definition

-- Drop table

-- DROP TABLE fieldkit.provision;

CREATE TABLE fieldkit.provision ( id serial4 NOT NULL, created timestamp NOT NULL, updated timestamp NOT NULL, generation bytea NOT NULL, device_id bytea NOT NULL, CONSTRAINT provision_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX provision_device_id_generation_idx ON fieldkit.provision USING btree (device_id, generation);


-- fieldkit.sagas definition

-- Drop table

-- DROP TABLE fieldkit.sagas;

CREATE TABLE fieldkit.sagas ( id text NOT NULL, created_at timestamp NOT NULL, updated_at timestamp NOT NULL, "version" int4 NOT NULL, scheduled_at timestamp NULL, tags jsonb NOT NULL, "type" text NOT NULL, body jsonb NOT NULL, CONSTRAINT sagas_pkey PRIMARY KEY (id));


-- fieldkit.sensor_data definition

-- Drop table

-- DROP TABLE fieldkit.sensor_data;

CREATE TABLE fieldkit.sensor_data ( "time" timestamptz NOT NULL, station_id int4 NOT NULL, module_id int4 NOT NULL, sensor_id int4 NOT NULL, value float8 NOT NULL)
WITH (
	fillfactor=90
);
CREATE INDEX sensor_data_idx ON fieldkit.sensor_data USING btree (station_id, module_id, sensor_id, "time" DESC);
CREATE INDEX sensor_data_module_id_idx ON fieldkit.sensor_data USING btree (module_id);
CREATE INDEX sensor_data_time_idx ON fieldkit.sensor_data USING btree ("time" DESC);
CREATE UNIQUE INDEX sensor_index_idx ON fieldkit.sensor_data USING btree ("time", station_id, module_id, sensor_id);

-- Table Triggers

create trigger ts_cagg_invalidation_trigger after
insert
    or
delete
    or
update
    on
    fieldkit.sensor_data for each row execute function _timescaledb_functions.continuous_agg_invalidation_trigger('1');
create trigger ts_insert_blocker before
insert
    on
    fieldkit.sensor_data for each row execute function _timescaledb_functions.insert_blocker();


-- fieldkit.sensor_data_dirty definition

-- Drop table

-- DROP TABLE fieldkit.sensor_data_dirty;

CREATE TABLE fieldkit.sensor_data_dirty ( id serial4 NOT NULL, modified timestamptz NOT NULL, data_start timestamptz NOT NULL, data_end timestamptz NOT NULL, CONSTRAINT sensor_data_dirty_pkey PRIMARY KEY (id));


-- fieldkit.station_module definition

-- Drop table

-- DROP TABLE fieldkit.station_module;

CREATE TABLE fieldkit.station_module ( id serial4 NOT NULL, hardware_id bytea NOT NULL, flags int4 NOT NULL, manufacturer int4 NOT NULL, kind int4 NOT NULL, "version" int4 NOT NULL, "name" varchar NOT NULL, "label" text NULL, CONSTRAINT station_module_pkey PRIMARY KEY (id));


-- fieldkit.twitter_account definition

-- Drop table

-- DROP TABLE fieldkit.twitter_account;

CREATE TABLE fieldkit.twitter_account ( id int8 NOT NULL, screen_name varchar(15) NOT NULL, access_token varchar NOT NULL, access_secret varchar NOT NULL, CONSTRAINT twitter_account_pkey PRIMARY KEY (id));


-- fieldkit.twitter_oauth definition

-- Drop table

-- DROP TABLE fieldkit.twitter_oauth;

CREATE TABLE fieldkit.twitter_oauth ( request_token varchar NOT NULL, request_secret varchar NOT NULL, CONSTRAINT twitter_oauth_request_token_key UNIQUE (request_token));


-- fieldkit."user" definition

-- Drop table

-- DROP TABLE fieldkit."user";

CREATE TABLE fieldkit."user" ( id serial4 NOT NULL, "name" varchar(256) NOT NULL, username varchar(40) NOT NULL, email varchar(254) NOT NULL, "password" bytea NOT NULL, "valid" bool DEFAULT false NOT NULL, bio varchar NOT NULL, media_url varchar(255) NULL, media_content_type varchar(255) NULL, "admin" bool DEFAULT false NULL, firmware_tester bool DEFAULT false NOT NULL, created_at timestamp DEFAULT now() NULL, updated_at timestamp DEFAULT now() NULL, firmware_pattern text NULL, tnc_date timestamp DEFAULT '0001-01-01 00:00:00'::timestamp without time zone NULL, taggable bool DEFAULT false NULL, CONSTRAINT user_email_key UNIQUE (email), CONSTRAINT user_pkey PRIMARY KEY (id), CONSTRAINT user_username_key UNIQUE (username));


-- fieldkit.bookmarks definition

-- Drop table

-- DROP TABLE fieldkit.bookmarks;

CREATE TABLE fieldkit.bookmarks ( id serial4 NOT NULL, user_id int4 NULL, "token" text NOT NULL, bookmark text NOT NULL, created_at timestamp NOT NULL, referenced_at timestamp NOT NULL, CONSTRAINT bookmarks_pkey PRIMARY KEY (id), CONSTRAINT bookmarks_user_id_fkey FOREIGN KEY (user_id) REFERENCES fieldkit."user"(id));
CREATE UNIQUE INDEX bookmarks_token_idx ON fieldkit.bookmarks USING btree (token);


-- fieldkit.data_event definition

-- Drop table

-- DROP TABLE fieldkit.data_event;

CREATE TABLE fieldkit.data_event ( id serial4 NOT NULL, user_id int4 NOT NULL, project_ids _int4 DEFAULT '{}'::integer[] NOT NULL, station_ids _int4 DEFAULT '{}'::integer[] NOT NULL, created_at timestamp NOT NULL, updated_at timestamp NOT NULL, start_time timestamp NOT NULL, end_time timestamp NOT NULL, title text NOT NULL, description text NOT NULL, context json NULL, CONSTRAINT data_event_pkey PRIMARY KEY (id), CONSTRAINT data_event_user_id_fkey FOREIGN KEY (user_id) REFERENCES fieldkit."user"(id));
CREATE INDEX data_event_start_time_end_time_idx ON fieldkit.data_event USING btree (start_time, end_time);


-- fieldkit.data_export definition

-- Drop table

-- DROP TABLE fieldkit.data_export;

CREATE TABLE fieldkit.data_export ( id serial4 NOT NULL, "token" bytea NOT NULL, user_id int4 NOT NULL, format text NOT NULL, created_at timestamp NOT NULL, completed_at timestamp NULL, progress float8 NOT NULL, download_url text NULL, args json NOT NULL, "size" int4 NULL, message text NULL, CONSTRAINT data_export_pkey PRIMARY KEY (id), CONSTRAINT data_export_user_id_fkey FOREIGN KEY (user_id) REFERENCES fieldkit."user"(id));
CREATE UNIQUE INDEX data_export_token_idx ON fieldkit.data_export USING btree (token);


-- fieldkit.discussion_post definition

-- Drop table

-- DROP TABLE fieldkit.discussion_post;

CREATE TABLE fieldkit.discussion_post ( id serial4 NOT NULL, user_id int4 NOT NULL, thread_id int4 NULL, project_id int4 NULL, station_ids _int4 DEFAULT '{}'::integer[] NOT NULL, created_at timestamp NOT NULL, updated_at timestamp NOT NULL, body text NOT NULL, context json NULL, CONSTRAINT discussion_post_pkey PRIMARY KEY (id), CONSTRAINT discussion_post_project_id_fkey FOREIGN KEY (project_id) REFERENCES fieldkit.project(id), CONSTRAINT discussion_post_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES fieldkit.discussion_post(id), CONSTRAINT discussion_post_user_id_fkey FOREIGN KEY (user_id) REFERENCES fieldkit."user"(id));


-- fieldkit.ingestion_queue definition

-- Drop table

-- DROP TABLE fieldkit.ingestion_queue;

CREATE TABLE fieldkit.ingestion_queue ( id serial4 NOT NULL, ingestion_id int4 NOT NULL, queued timestamp NOT NULL, attempted timestamp NULL, completed timestamp NULL, total_records int4 NULL, other_errors int4 NULL, meta_errors int4 NULL, data_errors int4 NULL, CONSTRAINT ingestion_queue_pkey PRIMARY KEY (id), CONSTRAINT ingestion_queue_ingestion_id_fkey FOREIGN KEY (ingestion_id) REFERENCES fieldkit.ingestion(id));
CREATE INDEX ingestion_queue_queued_completed_idx ON fieldkit.ingestion_queue USING btree (queued, completed);


-- fieldkit.meta_record definition

-- Drop table

-- DROP TABLE fieldkit.meta_record;

CREATE TABLE fieldkit.meta_record ( id serial4 NOT NULL, provision_id int4 NOT NULL, "time" timestamp NOT NULL, "number" int4 NOT NULL, raw json NOT NULL, pb bytea NULL, CONSTRAINT meta_record_pkey PRIMARY KEY (id), CONSTRAINT meta_record_provision_id_fkey FOREIGN KEY (provision_id) REFERENCES fieldkit.provision(id));
CREATE UNIQUE INDEX meta_record_provision_id_number_idx ON fieldkit.meta_record USING btree (provision_id, number);
CREATE INDEX meta_record_time_provision_id_number_idx ON fieldkit.meta_record USING btree ("time", provision_id, number);


-- fieldkit.moderation_request definition

-- Drop table

-- DROP TABLE fieldkit.moderation_request;

CREATE TABLE fieldkit.moderation_request ( id serial4 NOT NULL, post_id int4 NOT NULL, post_type fieldkit."post_type_enum" NOT NULL, reported_by int4 NOT NULL, acknowledged_by int4 NULL, reported_at timestamp DEFAULT CURRENT_TIMESTAMP NULL, acknowledged_at timestamp NULL, CONSTRAINT moderation_request_pkey PRIMARY KEY (id), CONSTRAINT fk_moderation_request_acknowledged_by FOREIGN KEY (acknowledged_by) REFERENCES fieldkit."user"(id) ON DELETE SET NULL, CONSTRAINT fk_moderation_request_reported_by FOREIGN KEY (reported_by) REFERENCES fieldkit."user"(id) ON DELETE CASCADE);
CREATE INDEX idx_moderation_request_post ON fieldkit.moderation_request USING btree (post_id, post_type);


-- fieldkit.module_sensor definition

-- Drop table

-- DROP TABLE fieldkit.module_sensor;

CREATE TABLE fieldkit.module_sensor ( id serial4 NOT NULL, module_id int4 NOT NULL, sensor_index int4 NOT NULL, unit_of_measure varchar NOT NULL, "name" varchar NOT NULL, reading_last float8 NULL, reading_time timestamp NULL, CONSTRAINT module_sensor_pkey PRIMARY KEY (id), CONSTRAINT module_sensor_module_id_fkey FOREIGN KEY (module_id) REFERENCES fieldkit.station_module(id));
CREATE UNIQUE INDEX module_sensor_module_id_sensor_index_idx ON fieldkit.module_sensor USING btree (module_id, sensor_index);


-- fieldkit.notification definition

-- Drop table

-- DROP TABLE fieldkit.notification;

CREATE TABLE fieldkit.notification ( id serial4 NOT NULL, created_at timestamp DEFAULT now() NOT NULL, user_id int4 NOT NULL, post_id int4 NULL, "key" text NOT NULL, kind text NOT NULL, body bytea NULL, seen bool NOT NULL, CONSTRAINT notification_pkey PRIMARY KEY (id), CONSTRAINT notification_post_id_fkey FOREIGN KEY (post_id) REFERENCES fieldkit.discussion_post(id), CONSTRAINT notification_user_id_fkey FOREIGN KEY (user_id) REFERENCES fieldkit."user"(id));


-- fieldkit.project_activity definition

-- Drop table

-- DROP TABLE fieldkit.project_activity;

CREATE TABLE fieldkit.project_activity ( id serial4 NOT NULL, created_at timestamp NOT NULL, project_id int4 NOT NULL, CONSTRAINT project_activity_pkey PRIMARY KEY (id), CONSTRAINT project_activity_project_id_fkey FOREIGN KEY (project_id) REFERENCES fieldkit.project(id));
CREATE INDEX project_activity_project_id_created_at_idx ON fieldkit.project_activity USING btree (project_id, created_at);


-- fieldkit.project_attribute definition

-- Drop table

-- DROP TABLE fieldkit.project_attribute;

CREATE TABLE fieldkit.project_attribute ( id serial4 NOT NULL, project_id int4 NOT NULL, "name" text NOT NULL, priority int4 NOT NULL, CONSTRAINT project_attribute_pkey PRIMARY KEY (id), CONSTRAINT project_attribute_project_id_fkey FOREIGN KEY (project_id) REFERENCES fieldkit.project(id));
CREATE UNIQUE INDEX project_attribute_idx ON fieldkit.project_attribute USING btree (project_id, name);


-- fieldkit.project_follower definition

-- Drop table

-- DROP TABLE fieldkit.project_follower;

CREATE TABLE fieldkit.project_follower ( id serial4 NOT NULL, created_at timestamp DEFAULT now() NOT NULL, project_id int4 NOT NULL, follower_id int4 NOT NULL, CONSTRAINT project_follower_pkey PRIMARY KEY (id), CONSTRAINT project_follower_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES fieldkit."user"(id), CONSTRAINT project_follower_project_id_fkey FOREIGN KEY (project_id) REFERENCES fieldkit.project(id));
CREATE INDEX project_follower_created_at_idx ON fieldkit.project_follower USING btree (created_at);
CREATE UNIQUE INDEX project_follower_project_id_follower_id_idx ON fieldkit.project_follower USING btree (project_id, follower_id);


-- fieldkit.project_invite definition

-- Drop table

-- DROP TABLE fieldkit.project_invite;

CREATE TABLE fieldkit.project_invite ( id serial4 NOT NULL, project_id int4 NOT NULL, user_id int4 NOT NULL, invited_email varchar(255) NOT NULL, invited_time timestamp NOT NULL, accepted_time timestamp NULL, rejected_time timestamp NULL, "token" bytea NULL, role_id int4 NOT NULL, CONSTRAINT project_invite_pkey PRIMARY KEY (id), CONSTRAINT project_invite_project_id_fkey FOREIGN KEY (project_id) REFERENCES fieldkit.project(id), CONSTRAINT project_invite_user_id_fkey FOREIGN KEY (user_id) REFERENCES fieldkit."user"(id));


-- fieldkit.project_update definition

-- Drop table

-- DROP TABLE fieldkit.project_update;

CREATE TABLE fieldkit.project_update ( author_id int4 NOT NULL, body text NULL, CONSTRAINT project_update_author_id_fkey FOREIGN KEY (author_id) REFERENCES fieldkit."user"(id)) INHERITS (fieldkit.project_activity);


-- fieldkit.project_user definition

-- Drop table

-- DROP TABLE fieldkit.project_user;

CREATE TABLE fieldkit.project_user ( project_id int4 NOT NULL, user_id int4 NOT NULL, "role" int4 DEFAULT 0 NOT NULL, CONSTRAINT project_user_pkey PRIMARY KEY (project_id, user_id), CONSTRAINT project_user_project_id_fkey FOREIGN KEY (project_id) REFERENCES fieldkit.project(id), CONSTRAINT project_user_user_id_fkey FOREIGN KEY (user_id) REFERENCES fieldkit."user"(id));


-- fieldkit.recovery_token definition

-- Drop table

-- DROP TABLE fieldkit.recovery_token;

CREATE TABLE fieldkit.recovery_token ( "token" bytea NOT NULL, user_id int4 NOT NULL, expires timestamp NOT NULL, CONSTRAINT recovery_token_pkey PRIMARY KEY (token), CONSTRAINT recovery_token_user_id_fkey FOREIGN KEY (user_id) REFERENCES fieldkit."user"(id) ON DELETE CASCADE);
CREATE UNIQUE INDEX recovery_token_user_id_idx ON fieldkit.recovery_token USING btree (user_id);


-- fieldkit.refresh_token definition

-- Drop table

-- DROP TABLE fieldkit.refresh_token;

CREATE TABLE fieldkit.refresh_token ( "token" bytea NOT NULL, user_id int4 NOT NULL, expires timestamp NOT NULL, CONSTRAINT refresh_token_pkey PRIMARY KEY (token), CONSTRAINT refresh_token_user_id_fkey FOREIGN KEY (user_id) REFERENCES fieldkit."user"(id) ON DELETE CASCADE);


-- fieldkit.sensor_meta definition

-- Drop table

-- DROP TABLE fieldkit.sensor_meta;

CREATE TABLE fieldkit.sensor_meta ( id serial4 NOT NULL, module_id int4 NOT NULL, "ordering" int4 NOT NULL, sensor_key text NOT NULL, firmware_key text NOT NULL, full_key text NOT NULL, internal bool NOT NULL, uom text NOT NULL, strings json NOT NULL, viz json NOT NULL, ranges json NOT NULL, aggregation_function text NULL, aliases _text NULL, CONSTRAINT sensor_meta_pkey PRIMARY KEY (id), CONSTRAINT sensor_meta_module_id_fkey FOREIGN KEY (module_id) REFERENCES fieldkit.module_meta(id));


-- fieldkit.station_configuration definition

-- Drop table

-- DROP TABLE fieldkit.station_configuration;

CREATE TABLE fieldkit.station_configuration ( id serial4 NOT NULL, provision_id int4 NOT NULL, meta_record_id int4 NULL, source_id int4 NULL, updated_at timestamp NOT NULL, CONSTRAINT station_configuration_pkey PRIMARY KEY (id), CONSTRAINT station_configuration_meta_record_id_fkey FOREIGN KEY (meta_record_id) REFERENCES fieldkit.meta_record(id), CONSTRAINT station_configuration_provision_id_fkey FOREIGN KEY (provision_id) REFERENCES fieldkit.provision(id));
CREATE UNIQUE INDEX station_configuration_provision_id_meta_record_id_idx ON fieldkit.station_configuration USING btree (provision_id, meta_record_id);
CREATE UNIQUE INDEX station_configuration_provision_id_source_id_idx ON fieldkit.station_configuration USING btree (provision_id, source_id);


-- fieldkit.ttn_schema definition

-- Drop table

-- DROP TABLE fieldkit.ttn_schema;

CREATE TABLE fieldkit.ttn_schema ( id serial4 NOT NULL, owner_id int4 NOT NULL, "token" bytea NOT NULL, "name" text NOT NULL, body json NOT NULL, received_at timestamp NULL, processed_at timestamp NULL, process_interval int4 NULL, project_id int4 NULL, CONSTRAINT ttn_schema_pkey PRIMARY KEY (id), CONSTRAINT ttn_schema_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES fieldkit."user"(id), CONSTRAINT ttn_schema_project_id_fkey FOREIGN KEY (project_id) REFERENCES fieldkit.project(id));


-- fieldkit.validation_token definition

-- Drop table

-- DROP TABLE fieldkit.validation_token;

CREATE TABLE fieldkit.validation_token ( "token" bytea NOT NULL, user_id int4 NOT NULL, expires timestamp NOT NULL, CONSTRAINT validation_token_pkey PRIMARY KEY (token), CONSTRAINT validation_token_user_id_fkey FOREIGN KEY (user_id) REFERENCES fieldkit."user"(id) ON DELETE CASCADE);


-- fieldkit.configuration_module definition

-- Drop table

-- DROP TABLE fieldkit.configuration_module;

CREATE TABLE fieldkit.configuration_module ( configuration_id int4 NOT NULL, module_id int4 NOT NULL, "position" int4 NOT NULL, module_index int4 NOT NULL, "label" text NULL, CONSTRAINT configuration_module_configuration_id_fkey FOREIGN KEY (configuration_id) REFERENCES fieldkit.station_configuration(id), CONSTRAINT configuration_module_module_id_fkey FOREIGN KEY (module_id) REFERENCES fieldkit.station_module(id));
CREATE UNIQUE INDEX configuration_module_idx ON fieldkit.configuration_module USING btree (configuration_id, module_id);


-- fieldkit.data_record definition

-- Drop table

-- DROP TABLE fieldkit.data_record;

CREATE TABLE fieldkit.data_record ( id serial4 NOT NULL, provision_id int4 NOT NULL, "time" timestamp NOT NULL, "number" int4 NOT NULL, meta_record_id int4 NOT NULL, "location" public.geometry(point, 4326) NULL, raw json NOT NULL, pb bytea NULL, CONSTRAINT data_record_pkey PRIMARY KEY (id), CONSTRAINT data_record_meta_fkey FOREIGN KEY (meta_record_id) REFERENCES fieldkit.meta_record(id), CONSTRAINT data_record_provision_id_fkey FOREIGN KEY (provision_id) REFERENCES fieldkit.provision(id));
CREATE INDEX data_record_provision_id_idx ON fieldkit.data_record USING btree (provision_id);
CREATE UNIQUE INDEX data_record_provision_id_number_idx ON fieldkit.data_record USING btree (provision_id, number);
CREATE INDEX data_record_provision_id_time_idx ON fieldkit.data_record USING btree (provision_id, "time");
CREATE INDEX data_record_time_provision_id_number_idx ON fieldkit.data_record USING btree ("time", provision_id, number);


-- fieldkit.merged_module definition

-- Drop table

-- DROP TABLE fieldkit.merged_module;

CREATE TABLE fieldkit.merged_module ( configuration_id int4 NOT NULL, deleted_id int4 NOT NULL, keeping_id int4 NOT NULL, merged bool DEFAULT false NULL, tried timestamp NULL, CONSTRAINT merged_module_configuration_id_fkey FOREIGN KEY (configuration_id) REFERENCES fieldkit.station_configuration(id), CONSTRAINT merged_module_keeping_id_fkey FOREIGN KEY (keeping_id) REFERENCES fieldkit.station_module(id));
CREATE UNIQUE INDEX merged_module_idx ON fieldkit.merged_module USING btree (deleted_id, keeping_id);


-- fieldkit.station_model definition

-- Drop table

-- DROP TABLE fieldkit.station_model;

CREATE TABLE fieldkit.station_model ( id serial4 NOT NULL, ttn_schema_id int4 NULL, "name" text NOT NULL, only_visible_via_association bool NOT NULL, CONSTRAINT station_model_pkey PRIMARY KEY (id), CONSTRAINT station_model_ttn_schema_id_fkey FOREIGN KEY (ttn_schema_id) REFERENCES fieldkit.ttn_schema(id));


-- fieldkit.ttn_messages definition

-- Drop table

-- DROP TABLE fieldkit.ttn_messages;

CREATE TABLE fieldkit.ttn_messages ( id serial4 NOT NULL, created_at timestamp DEFAULT now() NOT NULL, headers text NULL, body bytea NOT NULL, schema_id int4 NULL, ignored bool DEFAULT false NULL, CONSTRAINT ttn_messages_pkey PRIMARY KEY (id), CONSTRAINT ttn_messages_schema_id_fkey FOREIGN KEY (schema_id) REFERENCES fieldkit.ttn_schema(id));


-- fieldkit.aggregated_old_10m definition

-- Drop table

-- DROP TABLE fieldkit.aggregated_old_10m;

CREATE TABLE fieldkit.aggregated_old_10m ( id int4 DEFAULT nextval('aggregated_10m_id_seq'::regclass) NOT NULL, "time" timestamp NOT NULL, station_id int4 NOT NULL, sensor_id int4 NOT NULL, "location" public.geometry(point, 4326) NULL, value float8 NOT NULL, nsamples int4 NULL, CONSTRAINT aggregated_10m_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX aggregated_10m_time_station_id_sensor_id_idx ON fieldkit.aggregated_old_10m USING btree ("time", station_id, sensor_id);


-- fieldkit.aggregated_old_10s definition

-- Drop table

-- DROP TABLE fieldkit.aggregated_old_10s;

CREATE TABLE fieldkit.aggregated_old_10s ( id int4 DEFAULT nextval('aggregated_10s_id_seq'::regclass) NOT NULL, "time" timestamp NOT NULL, station_id int4 NOT NULL, sensor_id int4 NOT NULL, nsamples int4 NOT NULL, "location" public.geometry(point, 4326) NULL, value float8 NOT NULL, CONSTRAINT aggregated_10s_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX aggregated_10s_time_station_id_sensor_id_idx ON fieldkit.aggregated_old_10s USING btree ("time", station_id, sensor_id);


-- fieldkit.aggregated_old_12h definition

-- Drop table

-- DROP TABLE fieldkit.aggregated_old_12h;

CREATE TABLE fieldkit.aggregated_old_12h ( id int4 DEFAULT nextval('aggregated_12h_id_seq'::regclass) NOT NULL, "time" timestamp NOT NULL, station_id int4 NOT NULL, sensor_id int4 NOT NULL, "location" public.geometry(point, 4326) NULL, value float8 NOT NULL, nsamples int4 NULL, CONSTRAINT aggregated_12h_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX aggregated_12h_time_station_id_sensor_id_idx ON fieldkit.aggregated_old_12h USING btree ("time", station_id, sensor_id);


-- fieldkit.aggregated_old_1h definition

-- Drop table

-- DROP TABLE fieldkit.aggregated_old_1h;

CREATE TABLE fieldkit.aggregated_old_1h ( id int4 DEFAULT nextval('aggregated_1h_id_seq'::regclass) NOT NULL, "time" timestamp NOT NULL, station_id int4 NOT NULL, sensor_id int4 NOT NULL, "location" public.geometry(point, 4326) NULL, value float8 NOT NULL, nsamples int4 NULL, CONSTRAINT aggregated_1h_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX aggregated_1h_time_station_id_sensor_id_idx ON fieldkit.aggregated_old_1h USING btree ("time", station_id, sensor_id);


-- fieldkit.aggregated_old_1m definition

-- Drop table

-- DROP TABLE fieldkit.aggregated_old_1m;

CREATE TABLE fieldkit.aggregated_old_1m ( id int4 DEFAULT nextval('aggregated_1m_id_seq'::regclass) NOT NULL, "time" timestamp NOT NULL, station_id int4 NOT NULL, sensor_id int4 NOT NULL, "location" public.geometry(point, 4326) NULL, value float8 NOT NULL, nsamples int4 NULL, CONSTRAINT aggregated_1m_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX aggregated_1m_time_station_id_sensor_id_idx ON fieldkit.aggregated_old_1m USING btree ("time", station_id, sensor_id);


-- fieldkit.aggregated_old_24h definition

-- Drop table

-- DROP TABLE fieldkit.aggregated_old_24h;

CREATE TABLE fieldkit.aggregated_old_24h ( id int4 DEFAULT nextval('aggregated_24h_id_seq'::regclass) NOT NULL, "time" timestamp NOT NULL, station_id int4 NOT NULL, sensor_id int4 NOT NULL, "location" public.geometry(point, 4326) NULL, value float8 NOT NULL, nsamples int4 NULL, CONSTRAINT aggregated_24h_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX aggregated_24h_time_station_id_sensor_id_idx ON fieldkit.aggregated_old_24h USING btree ("time", station_id, sensor_id);


-- fieldkit.aggregated_old_30m definition

-- Drop table

-- DROP TABLE fieldkit.aggregated_old_30m;

CREATE TABLE fieldkit.aggregated_old_30m ( id int4 DEFAULT nextval('aggregated_30m_id_seq'::regclass) NOT NULL, "time" timestamp NOT NULL, station_id int4 NOT NULL, sensor_id int4 NOT NULL, "location" public.geometry(point, 4326) NULL, value float8 NOT NULL, nsamples int4 NULL, CONSTRAINT aggregated_30m_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX aggregated_30m_time_station_id_sensor_id_idx ON fieldkit.aggregated_old_30m USING btree ("time", station_id, sensor_id);


-- fieldkit.aggregated_old_6h definition

-- Drop table

-- DROP TABLE fieldkit.aggregated_old_6h;

CREATE TABLE fieldkit.aggregated_old_6h ( id int4 DEFAULT nextval('aggregated_6h_id_seq'::regclass) NOT NULL, "time" timestamp NOT NULL, station_id int4 NOT NULL, sensor_id int4 NOT NULL, "location" public.geometry(point, 4326) NULL, value float8 NOT NULL, nsamples int4 NULL, CONSTRAINT aggregated_6h_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX aggregated_6h_time_station_id_sensor_id_idx ON fieldkit.aggregated_old_6h USING btree ("time", station_id, sensor_id);


-- fieldkit.associated_station definition

-- Drop table

-- DROP TABLE fieldkit.associated_station;

CREATE TABLE fieldkit.associated_station ( station_id int4 NOT NULL, associated_station_id int4 NOT NULL, priority int4 NOT NULL);
CREATE UNIQUE INDEX associated_station_idx ON fieldkit.associated_station USING btree (station_id, associated_station_id);


-- fieldkit.notes definition

-- Drop table

-- DROP TABLE fieldkit.notes;

CREATE TABLE fieldkit.notes ( id serial4 NOT NULL, created_at timestamp NOT NULL, station_id int4 NOT NULL, author_id int4 NOT NULL, "key" text NULL, body text NULL, "version" int4 DEFAULT 0 NOT NULL, updated_at timestamp NOT NULL, title text NULL, CONSTRAINT notes_pkey PRIMARY KEY (id));


-- fieldkit.notes_media definition

-- Drop table

-- DROP TABLE fieldkit.notes_media;

CREATE TABLE fieldkit.notes_media ( id serial4 NOT NULL, user_id int4 NOT NULL, content_type varchar(100) NOT NULL, created_at timestamp NOT NULL, url varchar(255) NOT NULL, "key" text NOT NULL, station_id int4 NOT NULL, CONSTRAINT notes_media_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX notes_media_station_id_key_idx ON fieldkit.notes_media USING btree (station_id, key);


-- fieldkit.notes_media_link definition

-- Drop table

-- DROP TABLE fieldkit.notes_media_link;

CREATE TABLE fieldkit.notes_media_link ( note_id int4 NOT NULL, media_id int4 NOT NULL);
CREATE UNIQUE INDEX notes_media_link_note_id_media_id_idx ON fieldkit.notes_media_link USING btree (note_id, media_id);


-- fieldkit.project_station definition

-- Drop table

-- DROP TABLE fieldkit.project_station;

CREATE TABLE fieldkit.project_station ( id serial4 NOT NULL, station_id int4 NOT NULL, project_id int4 NOT NULL, CONSTRAINT project_station_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX project_station_station_id_project_id_idx ON fieldkit.project_station USING btree (station_id, project_id);


-- fieldkit.record_range_meta definition

-- Drop table

-- DROP TABLE fieldkit.record_range_meta;

CREATE TABLE fieldkit.record_range_meta ( id serial4 NOT NULL, station_id int4 NOT NULL, start_time timestamp NOT NULL, end_time timestamp NOT NULL, flags int4 NOT NULL, CONSTRAINT record_range_meta_pkey PRIMARY KEY (id), CONSTRAINT record_range_meta_station_id_tsrange_excl EXCLUDE USING gist (station_id WITH =, tsrange(start_time, end_time) WITH &&));
CREATE INDEX record_range_meta_station_id_tsrange_excl ON fieldkit.record_range_meta USING gist (station_id, tsrange(start_time, end_time));


-- fieldkit.station definition

-- Drop table

-- DROP TABLE fieldkit.station;

CREATE TABLE fieldkit.station ( id serial4 NOT NULL, owner_id int4 NOT NULL, device_id bytea NOT NULL, created_at timestamp DEFAULT now() NOT NULL, "name" text NOT NULL, battery float8 NULL, recording_started_at timestamp NULL, memory_used int4 NULL, memory_available int4 NULL, firmware_number int4 NULL, firmware_time int4 NULL, "location" public.geometry(point, 4326) NULL, location_name text NULL, updated_at timestamp NOT NULL, place_other text NULL, place_native text NULL, photo_id int4 NULL, synced_at timestamp NULL, ingestion_at timestamp NULL, model_id int4 NOT NULL, hidden bool NULL, status text NULL, description text NULL, CONSTRAINT station_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX station_device_id_idx ON fieldkit.station USING btree (device_id);


-- fieldkit.station_activity definition

-- Drop table

-- DROP TABLE fieldkit.station_activity;

CREATE TABLE fieldkit.station_activity ( id serial4 NOT NULL, created_at timestamp NOT NULL, station_id int4 NOT NULL, CONSTRAINT station_activity_pkey PRIMARY KEY (id));
CREATE INDEX station_activity_station_id_created_at_idx ON fieldkit.station_activity USING btree (station_id, created_at);


-- fieldkit.station_deployed definition

-- Drop table

-- DROP TABLE fieldkit.station_deployed;

CREATE TABLE fieldkit.station_deployed ( deployed_at timestamp NOT NULL, "location" public.geometry(point, 4326) NOT NULL) INHERITS (fieldkit.station_activity);
CREATE UNIQUE INDEX station_deployed_station_id_deployed_at_idx ON fieldkit.station_deployed USING btree (station_id, deployed_at);


-- fieldkit.station_dev_eui definition

-- Drop table

-- DROP TABLE fieldkit.station_dev_eui;

CREATE TABLE fieldkit.station_dev_eui ( dev_eui bytea NOT NULL, station_id int4 NOT NULL, CONSTRAINT station_dev_eui_pkey PRIMARY KEY (dev_eui));


-- fieldkit.station_ingestion definition

-- Drop table

-- DROP TABLE fieldkit.station_ingestion;

CREATE TABLE fieldkit.station_ingestion ( uploader_id int4 NOT NULL, data_ingestion_id int4 NOT NULL, data_records int4 NOT NULL, errors bool NOT NULL) INHERITS (fieldkit.station_activity);
CREATE UNIQUE INDEX station_ingestion_data_ingestion_id_idx ON fieldkit.station_ingestion USING btree (data_ingestion_id);


-- fieldkit.station_interestingness definition

-- Drop table

-- DROP TABLE fieldkit.station_interestingness;

CREATE TABLE fieldkit.station_interestingness ( id serial4 NOT NULL, station_id int4 NOT NULL, window_seconds int4 NOT NULL, interestingness float8 NOT NULL, reading_sensor_id int4 NOT NULL, reading_module_id int4 NOT NULL, reading_value float8 NOT NULL, reading_time timestamp NOT NULL, CONSTRAINT station_interestingness_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX station_interestingness_idx ON fieldkit.station_interestingness USING btree (station_id, window_seconds);


-- fieldkit.station_log definition

-- Drop table

-- DROP TABLE fieldkit.station_log;

CREATE TABLE fieldkit.station_log ( id serial4 NOT NULL, station_id int4 NOT NULL, "timestamp" timestamp NOT NULL, body text NULL, CONSTRAINT station_log_pkey PRIMARY KEY (id));


-- fieldkit.station_note definition

-- Drop table

-- DROP TABLE fieldkit.station_note;

CREATE TABLE fieldkit.station_note ( id serial4 NOT NULL, station_id int4 NOT NULL, user_id int4 NOT NULL, created_at timestamp NOT NULL, updated_at timestamp NOT NULL, body text NOT NULL, CONSTRAINT station_note_pkey PRIMARY KEY (id));


-- fieldkit.station_project_attribute definition

-- Drop table

-- DROP TABLE fieldkit.station_project_attribute;

CREATE TABLE fieldkit.station_project_attribute ( id serial4 NOT NULL, station_id int4 NOT NULL, attribute_id int4 NOT NULL, string_value text NOT NULL, CONSTRAINT station_project_attribute_pkey PRIMARY KEY (id));
CREATE UNIQUE INDEX station_project_attribute_idx ON fieldkit.station_project_attribute USING btree (station_id, attribute_id);


-- fieldkit.visible_configuration definition

-- Drop table

-- DROP TABLE fieldkit.visible_configuration;

CREATE TABLE fieldkit.visible_configuration ( station_id int4 NOT NULL, configuration_id int4 NOT NULL, CONSTRAINT visible_configuration_pkey PRIMARY KEY (station_id));


-- fieldkit.aggregated_old_10m foreign keys

ALTER TABLE fieldkit.aggregated_old_10m ADD CONSTRAINT aggregated_10m_sensor_id_fkey FOREIGN KEY (sensor_id) REFERENCES fieldkit.aggregated_sensor(id);
ALTER TABLE fieldkit.aggregated_old_10m ADD CONSTRAINT aggregated_10m_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.aggregated_old_10s foreign keys

ALTER TABLE fieldkit.aggregated_old_10s ADD CONSTRAINT aggregated_10s_sensor_id_fkey FOREIGN KEY (sensor_id) REFERENCES fieldkit.aggregated_sensor(id);
ALTER TABLE fieldkit.aggregated_old_10s ADD CONSTRAINT aggregated_10s_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.aggregated_old_12h foreign keys

ALTER TABLE fieldkit.aggregated_old_12h ADD CONSTRAINT aggregated_12h_sensor_id_fkey FOREIGN KEY (sensor_id) REFERENCES fieldkit.aggregated_sensor(id);
ALTER TABLE fieldkit.aggregated_old_12h ADD CONSTRAINT aggregated_12h_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.aggregated_old_1h foreign keys

ALTER TABLE fieldkit.aggregated_old_1h ADD CONSTRAINT aggregated_1h_sensor_id_fkey FOREIGN KEY (sensor_id) REFERENCES fieldkit.aggregated_sensor(id);
ALTER TABLE fieldkit.aggregated_old_1h ADD CONSTRAINT aggregated_1h_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.aggregated_old_1m foreign keys

ALTER TABLE fieldkit.aggregated_old_1m ADD CONSTRAINT aggregated_1m_sensor_id_fkey FOREIGN KEY (sensor_id) REFERENCES fieldkit.aggregated_sensor(id);
ALTER TABLE fieldkit.aggregated_old_1m ADD CONSTRAINT aggregated_1m_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.aggregated_old_24h foreign keys

ALTER TABLE fieldkit.aggregated_old_24h ADD CONSTRAINT aggregated_24h_sensor_id_fkey FOREIGN KEY (sensor_id) REFERENCES fieldkit.aggregated_sensor(id);
ALTER TABLE fieldkit.aggregated_old_24h ADD CONSTRAINT aggregated_24h_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.aggregated_old_30m foreign keys

ALTER TABLE fieldkit.aggregated_old_30m ADD CONSTRAINT aggregated_30m_sensor_id_fkey FOREIGN KEY (sensor_id) REFERENCES fieldkit.aggregated_sensor(id);
ALTER TABLE fieldkit.aggregated_old_30m ADD CONSTRAINT aggregated_30m_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.aggregated_old_6h foreign keys

ALTER TABLE fieldkit.aggregated_old_6h ADD CONSTRAINT aggregated_6h_sensor_id_fkey FOREIGN KEY (sensor_id) REFERENCES fieldkit.aggregated_sensor(id);
ALTER TABLE fieldkit.aggregated_old_6h ADD CONSTRAINT aggregated_6h_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.associated_station foreign keys

ALTER TABLE fieldkit.associated_station ADD CONSTRAINT associated_station_associated_station_id_fkey FOREIGN KEY (associated_station_id) REFERENCES fieldkit.station(id);
ALTER TABLE fieldkit.associated_station ADD CONSTRAINT associated_station_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.notes foreign keys

ALTER TABLE fieldkit.notes ADD CONSTRAINT notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES fieldkit."user"(id);
ALTER TABLE fieldkit.notes ADD CONSTRAINT notes_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.notes_media foreign keys

ALTER TABLE fieldkit.notes_media ADD CONSTRAINT notes_media_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);
ALTER TABLE fieldkit.notes_media ADD CONSTRAINT notes_media_user_id_fkey FOREIGN KEY (user_id) REFERENCES fieldkit."user"(id);


-- fieldkit.notes_media_link foreign keys

ALTER TABLE fieldkit.notes_media_link ADD CONSTRAINT notes_media_link_media_id_fkey FOREIGN KEY (media_id) REFERENCES fieldkit.notes_media(id);
ALTER TABLE fieldkit.notes_media_link ADD CONSTRAINT notes_media_link_note_id_fkey FOREIGN KEY (note_id) REFERENCES fieldkit.notes(id);


-- fieldkit.project_station foreign keys

ALTER TABLE fieldkit.project_station ADD CONSTRAINT project_station_project_id_fkey FOREIGN KEY (project_id) REFERENCES fieldkit.project(id);
ALTER TABLE fieldkit.project_station ADD CONSTRAINT project_station_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.record_range_meta foreign keys

ALTER TABLE fieldkit.record_range_meta ADD CONSTRAINT record_range_meta_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.station foreign keys

ALTER TABLE fieldkit.station ADD CONSTRAINT station_model_id_fkey FOREIGN KEY (model_id) REFERENCES fieldkit.station_model(id);
ALTER TABLE fieldkit.station ADD CONSTRAINT station_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES fieldkit."user"(id);
ALTER TABLE fieldkit.station ADD CONSTRAINT station_photo_id_fkey FOREIGN KEY (photo_id) REFERENCES fieldkit.notes_media(id);


-- fieldkit.station_activity foreign keys

ALTER TABLE fieldkit.station_activity ADD CONSTRAINT station_activity_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.station_deployed foreign keys

-- fieldkit.station_dev_eui foreign keys

ALTER TABLE fieldkit.station_dev_eui ADD CONSTRAINT station_dev_eui_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.station_ingestion foreign keys

ALTER TABLE fieldkit.station_ingestion ADD CONSTRAINT station_ingestion_data_ingestion_id_fkey FOREIGN KEY (data_ingestion_id) REFERENCES fieldkit.ingestion(id);
ALTER TABLE fieldkit.station_ingestion ADD CONSTRAINT station_ingestion_uploader_id_fkey FOREIGN KEY (uploader_id) REFERENCES fieldkit."user"(id);


-- fieldkit.station_interestingness foreign keys

ALTER TABLE fieldkit.station_interestingness ADD CONSTRAINT station_interestingness_reading_module_id_fkey FOREIGN KEY (reading_module_id) REFERENCES fieldkit.station_module(id);
ALTER TABLE fieldkit.station_interestingness ADD CONSTRAINT station_interestingness_reading_sensor_id_fkey FOREIGN KEY (reading_sensor_id) REFERENCES fieldkit.aggregated_sensor(id);
ALTER TABLE fieldkit.station_interestingness ADD CONSTRAINT station_interestingness_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.station_log foreign keys

ALTER TABLE fieldkit.station_log ADD CONSTRAINT station_log_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.station_note foreign keys

ALTER TABLE fieldkit.station_note ADD CONSTRAINT station_note_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);
ALTER TABLE fieldkit.station_note ADD CONSTRAINT station_note_user_id_fkey FOREIGN KEY (user_id) REFERENCES fieldkit."user"(id);


-- fieldkit.station_project_attribute foreign keys

ALTER TABLE fieldkit.station_project_attribute ADD CONSTRAINT station_project_attribute_attribute_id_fkey FOREIGN KEY (attribute_id) REFERENCES fieldkit.project_attribute(id);
ALTER TABLE fieldkit.station_project_attribute ADD CONSTRAINT station_project_attribute_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);


-- fieldkit.visible_configuration foreign keys

ALTER TABLE fieldkit.visible_configuration ADD CONSTRAINT visible_configuration_configuration_id_fkey FOREIGN KEY (configuration_id) REFERENCES fieldkit.station_configuration(id);
ALTER TABLE fieldkit.visible_configuration ADD CONSTRAINT visible_configuration_station_id_fkey FOREIGN KEY (station_id) REFERENCES fieldkit.station(id);