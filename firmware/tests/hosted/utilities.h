#pragma once

#include "common.h"
#include "hal/linux/linux.h"
#include "pool.h"
#include "protobuf.h"
#include "storage/storage.h"

namespace fk {

template <typename T = uint8_t, size_t Size> static void fake_data(T (&buffer)[Size]) {
    for (auto i = 0u; i < Size; ++i) {
        buffer[i] = i % 255;
    }
}

template <typename T = char, size_t Size> static void fake_string(T (&buffer)[Size]) {
    for (auto i = 0u; i < Size - 1; ++i) {
        buffer[i] = 'a' + (i % 10);
    }
    buffer[Size - 1] = 0;
}

fkb_header_t const *get_fake_header();

void write_meta_records(DataMemory *memory, size_t total);

void write_readings(DataMemory *memory, size_t total);

uint32_t write_number_of_blocks(DataMemory *memory, size_t nblocks);

void write_number_of_readings(DataMemory *memory, size_t n);

void write_alternating(DataMemory *memory, size_t total);

class ReadingRecord {
public:
    fk_data_SensorAndValue readings[10]{
        { 0, fk_data_SensorAndValue_calibratedValue_tag, { (float)fk_random_i32(0, 100) } },
        { 1, fk_data_SensorAndValue_calibratedValue_tag, { (float)fk_random_i32(0, 100) } },
        { 2, fk_data_SensorAndValue_calibratedValue_tag, { (float)fk_random_i32(0, 100) } },
        { 3, fk_data_SensorAndValue_calibratedValue_tag, { (float)fk_random_i32(0, 100) } },
        { 4, fk_data_SensorAndValue_calibratedValue_tag, { (float)fk_random_i32(0, 100) } },
        { 5, fk_data_SensorAndValue_calibratedValue_tag, { (float)fk_random_i32(0, 100) } },
        { 6, fk_data_SensorAndValue_calibratedValue_tag, { (float)fk_random_i32(0, 100) } },
        { 7, fk_data_SensorAndValue_calibratedValue_tag, { (float)fk_random_i32(0, 100) } },
        { 8, fk_data_SensorAndValue_calibratedValue_tag, { (float)fk_random_i32(0, 100) } },
        { 9, fk_data_SensorAndValue_calibratedValue_tag, { (float)fk_random_i32(0, 100) } },
    };

    pb_array_t readings_array{
        .length = 10u,
        .allocated = 10u,
        .item_size = sizeof(fk_data_SensorAndValue),
        .buffer = &readings,
        .fields = fk_data_SensorAndValue_fields,
    };

    fk_data_SensorGroup groups[1]{
        {
            .module = 0,
            .readings = {
                .funcs = {
                    .encode = pb_encode_array,
                },
                .arg = &readings_array,
            },
        }
    };

    pb_array_t sensor_groups_array{
        .length = 1u,
        .allocated = 1u,
        .item_size = sizeof(fk_data_SensorGroup),
        .buffer = &groups,
        .fields = fk_data_SensorGroup_fields,
    };

    fk_data_DataRecord record;

public:
    ReadingRecord(uint32_t uptime, uint32_t reading_number) {
        record = fk_data_DataRecord_init_default;
        record.has_readings = true;
        record.readings.time = uptime;
        record.readings.reading = reading_number;
        record.readings.flags = 0;
        record.readings.has_location = true;
        record.readings.location.fix = 0;
        record.readings.location.time = uptime;
        record.readings.location.longitude = -118.2709223;
        record.readings.location.latitude = 34.0318047;
        record.readings.location.altitude = 100.0f;
        record.readings.sensorGroups.funcs.encode = pb_encode_array;
        record.readings.sensorGroups.arg = &sensor_groups_array;
    }
};

} // namespace fk
