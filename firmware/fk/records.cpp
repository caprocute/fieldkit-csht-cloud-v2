#include "records.h"

namespace fk {

static bool pb_decode_float_array(pb_istream_t *stream, const pb_field_t *field, void **arg);
static bool pb_data_network_info_item_decode(pb_istream_t *stream, pb_array_t *array);

void prepare_decode_data(pb_callback_s *callbacks, Pool *pool) {
    callbacks->funcs.decode = pb_decode_data;
    callbacks->arg = (void *)pool;
}

void prepare_encode_data(pb_callback_s *callbacks, Pool *pool) {
    callbacks->funcs.encode = pb_encode_data;
    if (callbacks->arg == pool) {
        callbacks->arg = nullptr;
    }
}

void prepare_encode_buffer_ptr(pb_callback_s *callbacks, Pool *pool) {
    callbacks->funcs.encode = pb_encode_buffer_ptr;
    if (callbacks->arg == pool) {
        callbacks->arg = nullptr;
    }
}

void prepare_decode_string(pb_callback_s *callbacks, Pool *pool) {
    callbacks->funcs.decode = pb_decode_string;
    callbacks->arg = (void *)pool;
}

void prepare_encode_string(pb_callback_s *callbacks, Pool *pool) {
    callbacks->funcs.encode = pb_encode_string;
}

void prepare_encode_array(pb_callback_s *callbacks, Pool *pool) {
    callbacks->funcs.encode = pb_encode_array;
}

void prepare_decode_float_array(pb_callback_s *callbacks, Pool *pool) {
    callbacks->funcs.decode = pb_decode_float_array;
    callbacks->arg = (void *)pool->malloc_with<pb_array_t>({
        .length = 0,
        .allocated = 0,
        .item_size = sizeof(float),
        .buffer = nullptr,
        .fields = nullptr,
        .decode_item_fn = nullptr,
        .pool = pool,
    });
}

void prepare_decode_array(pb_callback_s *callbacks, pb_array_t *array) {
    callbacks->funcs.decode = pb_decode_array;
    callbacks->arg = (void *)array;
}

static bool pb_data_network_info_item_decode(pb_istream_t *stream, pb_array_t *array) {
    auto pool = array->pool;

    fk_data_NetworkInfo info;
    prepare_decode_string(&info.ssid, pool);
    prepare_decode_string(&info.password, pool);

    if (!pb_decode(stream, fk_data_NetworkInfo_fields, &info)) {
        return false;
    }

    pb_append_array(array, &info);

    return true;
}

static inline bool pb_data_sensor_and_value_item_decode(pb_istream_t *stream, pb_array_t *array) {
    fk_data_SensorAndValue sensor_value = fk_data_SensorAndValue_init_default;

    if (!pb_decode(stream, fk_data_SensorAndValue_fields, &sensor_value)) {
        return false;
    }

    pb_append_array(array, &sensor_value);

    return true;
}

static bool pb_data_sensor_group_item_decode(pb_istream_t *stream, pb_array_t *array) {
    auto pool = array->pool;

    fk_data_SensorGroup sensor_group = fk_data_SensorGroup_init_default;
    prepare_decode_array(&sensor_group.readings, pool->malloc_with<pb_array_t>({
                                                     .length = 0,
                                                     .allocated = 0,
                                                     .item_size = sizeof(fk_data_SensorAndValue),
                                                     .buffer = nullptr,
                                                     .fields = fk_data_SensorAndValue_fields,
                                                     .decode_item_fn = pb_data_sensor_and_value_item_decode,
                                                     .pool = pool,
                                                 }));

    if (!pb_decode(stream, fk_data_SensorGroup_fields, &sensor_group)) {
        return false;
    }

    pb_append_array(array, &sensor_group);

    return true;
}

static bool pb_data_sensor_info_item_decode(pb_istream_t *stream, pb_array_t *array) {
    auto pool = array->pool;

    fk_data_SensorInfo sensor_info = fk_data_SensorInfo_init_default;
    prepare_decode_string(&sensor_info.name, pool);
    prepare_decode_string(&sensor_info.unitOfMeasure, pool);

    if (!pb_decode(stream, fk_data_SensorInfo_fields, &sensor_info)) {
        return false;
    }

    pb_append_array(array, &sensor_info);

    return true;
}

static bool pb_data_module_info_item_decode(pb_istream_t *stream, pb_array_t *array) {
    auto pool = array->pool;

    fk_data_ModuleInfo module_info = fk_data_ModuleInfo_init_default;
    prepare_decode_string(&module_info.name, pool);
    prepare_decode_data(&module_info.id, pool);
    prepare_decode_array(&module_info.sensors, pool->malloc_with<pb_array_t>({
                                                   .length = 0,
                                                   .allocated = 0,
                                                   .item_size = sizeof(fk_data_SensorInfo),
                                                   .buffer = nullptr,
                                                   .fields = fk_data_SensorInfo_fields,
                                                   .decode_item_fn = pb_data_sensor_info_item_decode,
                                                   .pool = pool,
                                               }));

    if (!pb_decode(stream, fk_data_ModuleInfo_fields, &module_info)) {
        return false;
    }

    pb_append_array(array, &module_info);

    return true;
}

static bool pb_app_network_info_item_decode(pb_istream_t *stream, pb_array_t *array) {
    auto pool = array->pool;

    fk_app_NetworkInfo info;
    prepare_decode_string(&info.ssid, pool);
    prepare_decode_string(&info.password, pool);

    if (!pb_decode(stream, fk_app_NetworkInfo_fields, &info)) {
        return false;
    }

    pb_append_array(array, &info);

    return true;
}

static bool fk_array_interval_decode(pb_istream_t *stream, pb_array_t *array) {
    fk_app_Interval interval;
    if (!pb_decode(stream, fk_app_Interval_fields, &interval)) {
        return false;
    }

    pb_append_array(array, &interval);

    return true;
}

static bool pb_data_event_item_decode(pb_istream_t *stream, pb_array_t *array) {
    auto pool = array->pool;

    fk_data_Event event = fk_data_Event_init_default;
    prepare_decode_data(&event.details.data, pool);
    prepare_decode_data(&event.debug, pool);

    if (!pb_decode(stream, fk_data_Event_fields, &event)) {
        return false;
    }

    pb_append_array(array, &event);

    return true;
}

void prepare_data_event_item_encode(fk_data_Event *event, Pool *pool) {
    prepare_encode_data(&event->details.data, pool);
    prepare_encode_data(&event->debug, pool);
}

void prepare_decode_data_schedule(fk_data_JobSchedule *item, Pool *pool) {
    prepare_decode_data(&item->cron, pool);
    prepare_decode_array(&item->intervals, pool->malloc_with<pb_array_t>({
                                               .length = 0,
                                               .allocated = 0,
                                               .item_size = sizeof(fk_app_Interval),
                                               .buffer = nullptr,
                                               .fields = fk_app_Interval_fields,
                                               .decode_item_fn = fk_array_interval_decode,
                                               .pool = pool,
                                           }));
}

void prepare_decode_app_schedule(fk_app_Schedule *item, Pool *pool) {
    prepare_decode_data(&item->cron, pool);
    prepare_decode_array(&item->intervals, pool->malloc_with<pb_array_t>({
                                               .length = 0,
                                               .allocated = 0,
                                               .item_size = sizeof(fk_app_Interval),
                                               .buffer = nullptr,
                                               .fields = fk_app_Interval_fields,
                                               .decode_item_fn = fk_array_interval_decode,
                                               .pool = pool,
                                           }));
}

void fk_data_record_decoding_new(fk_data_DataRecord *record, Pool *pool) {
    *record = fk_data_DataRecord_init_default;
    prepare_decode_string(&record->metadata.firmware.version, pool);
    prepare_decode_string(&record->metadata.firmware.build, pool);
    prepare_decode_string(&record->metadata.firmware.hash, pool);
    prepare_decode_string(&record->metadata.firmware.number, pool);
    prepare_decode_data(&record->metadata.deviceId, pool);
    prepare_decode_data(&record->metadata.generation, pool);
    prepare_decode_string(&record->identity.name, pool);
    prepare_decode_data(&record->lora.joinEui, pool);
    prepare_decode_data(&record->lora.appKey, pool);
    prepare_decode_data(&record->lora.deviceEui, pool);
    prepare_decode_data(&record->lora.appSessionKey, pool);
    prepare_decode_data(&record->lora.networkSessionKey, pool);
    prepare_decode_data(&record->lora.deviceAddress, pool);
    prepare_decode_data_schedule(&record->schedule.readings, pool);
    prepare_decode_data_schedule(&record->schedule.network, pool);
    prepare_decode_data_schedule(&record->schedule.gps, pool);
    prepare_decode_data_schedule(&record->schedule.lora, pool);
    prepare_decode_string(&record->transmission.wifi.url, pool);
    prepare_decode_string(&record->transmission.wifi.token, pool);
    prepare_decode_array(&record->network.networks, pool->malloc_with<pb_array_t>({
                                                        .length = 0,
                                                        .allocated = 0,
                                                        .item_size = sizeof(fk_data_NetworkInfo),
                                                        .buffer = nullptr,
                                                        .fields = fk_data_NetworkInfo_fields,
                                                        .decode_item_fn = pb_data_network_info_item_decode,
                                                        .pool = pool,
                                                    }));
    prepare_decode_array(&record->modules, pool->malloc_with<pb_array_t>({
                                               .length = 0,
                                               .allocated = 0,
                                               .item_size = sizeof(fk_data_ModuleInfo),
                                               .buffer = nullptr,
                                               .fields = fk_data_ModuleInfo_fields,
                                               .decode_item_fn = pb_data_module_info_item_decode,
                                               .pool = pool,
                                           }));
    prepare_decode_array(&record->readings.sensorGroups, pool->malloc_with<pb_array_t>({
                                                             .length = 0,
                                                             .allocated = 0,
                                                             .item_size = sizeof(fk_data_SensorGroup),
                                                             .buffer = nullptr,
                                                             .fields = fk_data_SensorGroup_fields,
                                                             .decode_item_fn = pb_data_sensor_group_item_decode,
                                                             .pool = pool,
                                                         }));
    prepare_decode_array(&record->events, pool->malloc_with<pb_array_t>({
                                              .length = 0,
                                              .allocated = 0,
                                              .item_size = sizeof(fk_data_Event),
                                              .buffer = nullptr,
                                              .fields = fk_data_Event_fields,
                                              .decode_item_fn = pb_data_event_item_decode,
                                              .pool = pool,
                                          }));
}

void fk_data_record_encoding_new(fk_data_DataRecord *record, Pool *pool) {
    *record = fk_data_DataRecord_init_default;

    prepare_encode_string(&record->metadata.firmware.version, pool);
    prepare_encode_string(&record->metadata.firmware.build, pool);
    prepare_encode_string(&record->metadata.firmware.number, pool);
    prepare_encode_string(&record->metadata.firmware.hash, pool);
    prepare_encode_data(&record->metadata.deviceId, pool);
    prepare_encode_data(&record->metadata.generation, pool);
    prepare_encode_string(&record->identity.name, pool);
    prepare_encode_array(&record->readings.sensorGroups, pool);
    prepare_encode_array(&record->modules, pool);
    prepare_encode_data(&record->lora.joinEui, pool);
    prepare_encode_data(&record->lora.appKey, pool);
    prepare_encode_data(&record->lora.appSessionKey, pool);
    prepare_encode_data(&record->lora.networkSessionKey, pool);
    prepare_encode_data(&record->lora.deviceAddress, pool);
    prepare_encode_data(&record->lora.deviceEui, pool);
    prepare_encode_array(&record->network.networks, pool);
    prepare_encode_data(&record->schedule.readings.cron, pool);
    prepare_encode_array(&record->schedule.readings.intervals, pool);
    prepare_encode_data(&record->schedule.network.cron, pool);
    prepare_encode_array(&record->schedule.network.intervals, pool);
    prepare_encode_data(&record->schedule.gps.cron, pool);
    prepare_encode_array(&record->schedule.gps.intervals, pool);
    prepare_encode_data(&record->schedule.lora.cron, pool);
    prepare_encode_array(&record->schedule.lora.intervals, pool);
    prepare_encode_string(&record->transmission.wifi.url, pool);
    prepare_encode_string(&record->transmission.wifi.token, pool);
    prepare_encode_array(&record->events, pool);
}

fk_app_HttpQuery *fk_http_query_prepare_decoding(fk_app_HttpQuery *query, Pool *pool) {
    *query = fk_app_HttpQuery_init_default;

    prepare_decode_string(&query->identity.name, pool);
    prepare_decode_string(&query->directory.path, pool);
    prepare_decode_app_schedule(&query->schedules.readings, pool);
    prepare_decode_app_schedule(&query->schedules.network, pool);
    prepare_decode_app_schedule(&query->schedules.gps, pool);
    prepare_decode_app_schedule(&query->schedules.lora, pool);
    prepare_decode_data(&query->loraSettings.deviceEui, pool);
    prepare_decode_data(&query->loraSettings.joinEui, pool);
    prepare_decode_data(&query->loraSettings.appKey, pool);
    prepare_decode_data(&query->loraSettings.appSessionKey, pool);
    prepare_decode_data(&query->loraSettings.networkSessionKey, pool);
    prepare_decode_data(&query->loraSettings.deviceAddress, pool);
    prepare_decode_string(&query->transmission.wifi.url, pool);
    prepare_decode_string(&query->transmission.wifi.token, pool);
    prepare_decode_array(&query->networkSettings.networks, pool->malloc_with<pb_array_t>({
                                                               .length = 0,
                                                               .allocated = 0,
                                                               .item_size = sizeof(fk_app_NetworkInfo),
                                                               .buffer = nullptr,
                                                               .fields = fk_app_NetworkInfo_fields,
                                                               .decode_item_fn = pb_app_network_info_item_decode,
                                                               .pool = pool,
                                                           }));

    return query;
}

fk_app_HttpReply *fk_http_reply_encoding_initialize(fk_app_HttpReply *reply, Pool *pool) {
    if (reply->errors.arg != nullptr) {
        prepare_encode_array(&reply->errors, pool);
        auto array = reinterpret_cast<pb_array_t *>(reply->errors.arg);
        for (size_t i = 0; i < array->length; ++i) {
            auto error = &((fk_app_Error *)array->buffer)[i];
            prepare_encode_string(&error->message, pool);
        }
    }

    if (reply->status.identity.device.arg != nullptr)
        prepare_encode_string(&reply->status.identity.device, pool);
    if (reply->status.identity.stream.arg != nullptr)
        prepare_encode_string(&reply->status.identity.stream, pool);
    if (reply->status.identity.deviceId.arg != nullptr)
        prepare_encode_data(&reply->status.identity.deviceId, pool);
    if (reply->status.identity.firmware.arg != nullptr)
        prepare_encode_string(&reply->status.identity.firmware, pool);
    if (reply->status.identity.build.arg != nullptr)
        prepare_encode_string(&reply->status.identity.build, pool);
    if (reply->status.identity.number.arg != nullptr)
        prepare_encode_string(&reply->status.identity.number, pool);
    if (reply->status.identity.name.arg != nullptr)
        prepare_encode_string(&reply->status.identity.name, pool);
    if (reply->status.identity.generationId.arg != nullptr)
        prepare_encode_data(&reply->status.identity.generationId, pool);

    if (reply->status.firmware.version.arg != nullptr)
        prepare_encode_string(&reply->status.firmware.version, pool);
    if (reply->status.firmware.build.arg != nullptr)
        prepare_encode_string(&reply->status.firmware.build, pool);
    if (reply->status.firmware.number.arg != nullptr)
        prepare_encode_string(&reply->status.firmware.number, pool);
    if (reply->status.firmware.hash.arg != nullptr)
        prepare_encode_string(&reply->status.firmware.hash, pool);

    if (reply->status.memory.firmware.arg != nullptr) {
        prepare_encode_array(&reply->status.memory.firmware, pool);
        auto array = reinterpret_cast<pb_array_t *>(reply->status.memory.firmware.arg);
        for (size_t i = 0; i < array->length; ++i) {
            auto fw = &((fk_app_Firmware *)array->buffer)[i];

            prepare_encode_string(&fw->version, pool);
            prepare_encode_string(&fw->build, pool);
            prepare_encode_string(&fw->number, pool);
            prepare_encode_string(&fw->name, pool);
            prepare_encode_string(&fw->hash, pool);
        }
    }

    if (reply->status.schedules.readings.intervals.arg != nullptr) {
        prepare_encode_array(&reply->status.schedules.readings.intervals, pool);
    }
    if (reply->status.schedules.gps.intervals.arg != nullptr) {
        prepare_encode_array(&reply->status.schedules.gps.intervals, pool);
    }
    if (reply->status.schedules.network.intervals.arg != nullptr) {
        prepare_encode_array(&reply->status.schedules.network.intervals, pool);
    }
    if (reply->status.schedules.lora.intervals.arg != nullptr) {
        prepare_encode_array(&reply->status.schedules.lora.intervals, pool);
    }

    if (reply->nearbyNetworks.networks.arg != nullptr) {
        prepare_encode_array(&reply->nearbyNetworks.networks, pool);
        auto array = reinterpret_cast<pb_array_t *>(reply->nearbyNetworks.networks.arg);
        for (size_t i = 0; i < array->length; ++i) {
            auto nn = &((fk_app_NearbyNetwork *)array->buffer)[i];
            prepare_encode_string(&nn->ssid, pool);
        }
    }

    if (reply->modules.arg != nullptr) {
        prepare_encode_array(&reply->modules, pool);
        auto array = reinterpret_cast<pb_array_t *>(reply->modules.arg);
        for (size_t i = 0; i < array->length; ++i) {
            auto module = &((fk_app_ModuleCapabilities *)array->buffer)[i];
            prepare_encode_string(&module->name, pool);
            prepare_encode_string(&module->path, pool);
            prepare_encode_data(&module->id, pool);
            prepare_encode_data(&module->configuration, pool);
            if (module->sensors.arg != nullptr) {
                prepare_encode_array(&module->sensors, pool);
                auto array = reinterpret_cast<pb_array_t *>(module->sensors.arg);
                for (size_t i = 0; i < array->length; ++i) {
                    auto sensor = &((fk_app_SensorCapabilities *)array->buffer)[i];
                    prepare_encode_string(&sensor->name, pool);
                    prepare_encode_string(&sensor->path, pool);
                    prepare_encode_string(&sensor->unitOfMeasure, pool);
                    prepare_encode_string(&sensor->uncalibratedUnitOfMeasure, pool);
                }
            }
        }
    }

    if (reply->streams.arg != nullptr) {
        prepare_encode_array(&reply->streams, pool);
        auto array = reinterpret_cast<pb_array_t *>(reply->streams.arg);
        for (size_t i = 0; i < array->length; ++i) {
            auto stream = &((fk_app_DataStream *)array->buffer)[i];
            prepare_encode_string(&stream->name, pool);
            prepare_encode_string(&stream->path, pool);
            prepare_encode_data(&stream->hash, pool);
        }
    }

    if (reply->networkSettings.networks.arg != nullptr) {
        prepare_encode_array(&reply->networkSettings.networks, pool);
        auto array = reinterpret_cast<pb_array_t *>(reply->networkSettings.networks.arg);
        for (size_t i = 0; i < array->length; ++i) {
            auto network = &((fk_app_NetworkInfo *)array->buffer)[i];
            prepare_encode_string(&network->ssid, pool);
            prepare_encode_string(&network->password, pool);
        }
    }

    if (reply->networkSettings.macAddress.arg != nullptr) {
        prepare_encode_string(&reply->networkSettings.macAddress, pool);
    }

    if (reply->networkSettings.connected.ssid.arg != nullptr) {
        prepare_encode_string(&reply->networkSettings.connected.ssid, pool);
    }

    if (reply->liveReadings.arg != nullptr) {
        prepare_encode_array(&reply->liveReadings, pool);
        auto live_readings_array = reinterpret_cast<pb_array_t *>(reply->liveReadings.arg);
        for (size_t i = 0; i < live_readings_array->length; ++i) {
            auto live_readings = &((fk_app_LiveReadings *)live_readings_array->buffer)[i];
            if (live_readings->modules.arg != nullptr) {
                prepare_encode_array(&live_readings->modules, pool);
                auto modules_array = reinterpret_cast<pb_array_t *>(live_readings->modules.arg);
                for (size_t j = 0; j < modules_array->length; ++j) {
                    auto lmr = &((fk_app_LiveModuleReadings *)modules_array->buffer)[j];
                    if (lmr->module.name.arg != nullptr) {
                        prepare_encode_string(&lmr->module.name, pool);
                        prepare_encode_data(&lmr->module.id, pool);
                        prepare_encode_data(&lmr->module.configuration, pool);
                    }
                    if (lmr->readings.arg != nullptr) {
                        prepare_encode_array(&lmr->readings, pool);
                        auto readings_array = reinterpret_cast<pb_array_t *>(lmr->readings.arg);
                        for (size_t k = 0; k < readings_array->length; ++k) {
                            auto lsr = &((fk_app_LiveSensorReading *)readings_array->buffer)[k];
                            prepare_encode_string(&lsr->sensor.name, pool);
                            prepare_encode_string(&lsr->sensor.unitOfMeasure, pool);
                            prepare_encode_string(&lsr->sensor.uncalibratedUnitOfMeasure, pool);
                        }
                    }
                }
            }
        }
    }

    if (reply->transmission.wifi.url.arg != nullptr) {
        prepare_encode_string(&reply->transmission.wifi.url, pool);
    }

    if (reply->transmission.wifi.token.arg != nullptr) {
        prepare_encode_string(&reply->transmission.wifi.token, pool);
    }

    if (reply->events.arg != nullptr) {
        prepare_encode_buffer_ptr(&reply->events, pool);
    }

    return reply;
}

void fk_lora_record_encoding_new(fk_data_LoraRecord *record, Pool *pool) {
    *record = fk_data_LoraRecord_init_default;
    prepare_encode_array(&record->values, pool);
    prepare_encode_data(&record->deviceId, pool);
}

static bool pb_decode_float_array(pb_istream_t *stream, const pb_field_t *field, void **arg) {
    float value = 0.0f;

    if (!pb_decode_fixed32(stream, &value)) {
        return false;
    }

    auto array = (pb_array_t *)*arg;

    pb_append_array(array, &value);

    return true;
}

static inline bool pb_data_module_configuration_point_item_decode(pb_istream_t *stream, pb_array_t *array) {
    auto pool = array->pool;

    fk_data_CalibrationPoint point = fk_data_CalibrationPoint_init_default;
    prepare_decode_float_array(&point.uncalibrated, pool);
    prepare_decode_float_array(&point.references, pool);
    prepare_decode_float_array(&point.factory, pool);

    if (!pb_decode(stream, fk_data_CalibrationPoint_fields, &point)) {
        return false;
    }

    pb_append_array(array, &point);

    return true;
}

static inline bool pb_data_module_configuration_calibration_decode(pb_istream_t *stream, pb_array_t *array) {
    auto pool = array->pool;

    fk_data_Calibration calibration = fk_data_Calibration_init_default;
    prepare_decode_float_array(&calibration.coefficients.values, pool);
    prepare_decode_array(&calibration.points, pool->malloc_with<pb_array_t>({
                                                  .length = 0,
                                                  .allocated = 0,
                                                  .item_size = sizeof(fk_data_CalibrationPoint),
                                                  .buffer = nullptr,
                                                  .fields = fk_data_CalibrationPoint_fields,
                                                  .decode_item_fn = pb_data_module_configuration_point_item_decode,
                                                  .pool = pool,
                                              }));

    if (!pb_decode(stream, fk_data_Calibration_fields, &calibration)) {
        return false;
    }

    pb_append_array(array, &calibration);

    return true;
}

fk_data_ModuleConfiguration *fk_module_configuration_decoding_new(Pool *pool) {
    auto record = (fk_data_ModuleConfiguration *)pool->malloc(sizeof(fk_data_ModuleConfiguration));

    *record = fk_data_ModuleConfiguration_init_default;
    prepare_decode_float_array(&record->calibration.coefficients.values, pool);
    prepare_decode_array(&record->calibrations, pool->malloc_with<pb_array_t>({
                                                    .length = 0,
                                                    .allocated = 0,
                                                    .item_size = sizeof(fk_data_Calibration),
                                                    .buffer = nullptr,
                                                    .fields = fk_data_Calibration_fields,
                                                    .decode_item_fn = pb_data_module_configuration_calibration_decode,
                                                    .pool = pool,
                                                }));
    prepare_decode_array(&record->calibration.points, pool->malloc_with<pb_array_t>({
                                                          .length = 0,
                                                          .allocated = 0,
                                                          .item_size = sizeof(fk_data_CalibrationPoint),
                                                          .buffer = nullptr,
                                                          .fields = fk_data_CalibrationPoint_fields,
                                                          .decode_item_fn = pb_data_module_configuration_point_item_decode,
                                                          .pool = pool,
                                                      }));

    return record;
}

fk_app_ModuleHttpQuery *fk_module_query_prepare_decoding(fk_app_ModuleHttpQuery *query, Pool *pool) {
    *query = fk_app_ModuleHttpQuery_init_default;
    prepare_decode_data(&query->configuration, pool);

    return query;
}

fk_app_ModuleHttpReply *fk_module_reply_prepare_encoding(fk_app_ModuleHttpReply *reply, Pool *pool) {
    if (reply->errors.arg != nullptr) {
        prepare_encode_array(&reply->errors, pool);
        auto array = (pb_array_t *)reply->errors.arg;
        for (auto i = 0u; i < array->length; ++i) {
            auto error = &((fk_app_Error *)array->buffer)[i];
            prepare_encode_string(&error->message, pool);
        }
    }

    return reply;
}

void fk_prepare_events_record_encode(fk_data_Event *record, Pool *pool) {
    prepare_encode_data(&record->details.data, pool);
    prepare_encode_data(&record->debug, pool);
}

} // namespace fk
