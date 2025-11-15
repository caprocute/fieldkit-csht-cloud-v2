DROP VIEW IF EXISTS fieldkit.developer_stations;

ALTER TABLE fieldkit.station_module DROP COLUMN configuration_id;
ALTER TABLE fieldkit.station_module DROP COLUMN module_index;
ALTER TABLE fieldkit.station_module DROP COLUMN position;
ALTER TABLE fieldkit.module_sensor DROP COLUMN configuration_id;
