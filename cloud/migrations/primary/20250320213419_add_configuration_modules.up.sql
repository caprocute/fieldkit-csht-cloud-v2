CREATE TABLE fieldkit.configuration_module (
	configuration_id INTEGER REFERENCES fieldkit.station_configuration(id) NOT NULL,
	module_id INTEGER NOT NULL REFERENCES fieldkit.station_module(id),
	position INTEGER NOT NULL,
	module_index INTEGER NOT NULL,
    label TEXT
);

CREATE UNIQUE INDEX configuration_module_idx ON fieldkit.configuration_module (configuration_id, module_id);

ALTER TABLE fieldkit.station_module ALTER COLUMN configuration_id DROP NOT NULL;
ALTER TABLE fieldkit.station_module ALTER COLUMN module_index DROP NOT NULL;
ALTER TABLE fieldkit.station_module ALTER COLUMN position DROP NOT NULL;
ALTER TABLE fieldkit.station_module DROP CONSTRAINT station_module_configuration_id_fkey;

ALTER TABLE fieldkit.module_sensor ALTER COLUMN configuration_id DROP NOT NULL;
ALTER TABLE fieldkit.module_sensor DROP CONSTRAINT module_sensor_configuration_id_fkey;

/*
DROP VIEW IF EXISTS developer_stations;
ALTER TABLE fieldkit.station_module DROP COLUMN configuration_id;
ALTER TABLE fieldkit.station_module DROP COLUMN module_index;
ALTER TABLE fieldkit.station_module DROP COLUMN position;
ALTER TABLE fieldkit.station_module DROP COLUMN label;
ALTER TABLE fieldkit.module_sensor DROP COLUMN configuration_id;
CREATE UNIQUE INDEX station_module_hardware_id_idx ON fieldkit.station_module (hardware_id);
*/
