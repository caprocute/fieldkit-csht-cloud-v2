DELETE FROM fieldkit.module_sensor WHERE module_id IN (
    SELECT deleted_id FROM fieldkit.merged_module
);

DELETE FROM fieldkit.aggregated_sensor_updated WHERE module_id IN (
    SELECT deleted_id FROM fieldkit.merged_module
);

DELETE FROM fieldkit.station_module WHERE id IN (
    SELECT deleted_id FROM fieldkit.merged_module
);
