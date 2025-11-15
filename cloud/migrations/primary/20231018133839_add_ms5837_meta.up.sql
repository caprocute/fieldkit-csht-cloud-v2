INSERT INTO fieldkit.module_meta (key, manufacturer, kinds, version, internal) values ('fk.water.ms5837', 1, ARRAY[10], ARRAY[1], false);

INSERT INTO fieldkit.sensor_meta (module_id, ordering, sensor_key, firmware_key, full_key, internal, uom, strings, viz, ranges, aggregation_function, aliases)
VALUES ((SELECT currval('module_meta_id_seq')), 0, 'temp', 'temp', 'fk.water.ms5837.temp', false, '°C', '{ "en-US": { "label": "Water Temperature" } }', '[]', '[]', 'avg', NULL);

INSERT INTO fieldkit.sensor_meta (module_id, ordering, sensor_key, firmware_key, full_key, internal, uom, strings, viz, ranges, aggregation_function, aliases)
VALUES ((SELECT currval('module_meta_id_seq')), 1, 'depth', 'depth', 'fk.water.ms5837.depth', false, 'kPa', '{ "en-US": { "label": "Water Depth" } }', '[]', '[]', 'avg', NULL);

INSERT INTO fieldkit.aggregated_sensor (key) VALUES ('fk.water.ms5837.temp');

INSERT INTO fieldkit.aggregated_sensor (key) VALUES ('fk.water.ms5837.depth');