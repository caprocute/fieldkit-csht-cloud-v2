CREATE TABLE fieldkit.merged_module (
    configuration_id INTEGER NOT NULL REFERENCES station_configuration(id),
    deleted_id INTEGER NOT NULL /* REFERENCES station_module(id) Easier to delete modules in final migration. */,
    keeping_id INTEGER NOT NULL REFERENCES station_module(id),
    merged BOOL DEFAULT false,
    tried TIMESTAMP
);


CREATE UNIQUE INDEX merged_module_idx ON merged_module (deleted_id, keeping_id);
