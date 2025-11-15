#include "tests.h"
#include "patterns.h"
#include "common.h"
#include "hal/linux/linux.h"
#include "startup/startup_worker.h"
#include "storage/factory_wipe.h"
#include "readings_worker.h"
#include "state_manager.h"
#include "state_ref.h"
#include "storage_suite.h"
#include "test_modules.h"

using namespace fk;

FK_DECLARE_LOGGER("readings-worker-tests");

class ReadingsWorkerSuite : public StorageSuite {};

TEST_F(ReadingsWorkerSuite, OnlyDiagnosticsModule_FirstReading) {
    factory_wipe();

    auto gs = get_global_state_ro();

    ASSERT_EQ(gs.get()->readings.nreadings, 0u);

    ReadingsWorker readings_worker{ true, false, false, ModulePowerState::Unknown };
    readings_worker.run(pool_);

    ASSERT_EQ(gs.get()->readings.nreadings, 1u);
}

TEST_F(ReadingsWorkerSuite, OnlyDiagnosticsModule_SecondReading) {
    auto gs = get_global_state_ro();

    factory_wipe();

    ASSERT_EQ(gs.get()->readings.nreadings, 0u);

    ReadingsWorker readings_worker{ true, false, false, ModulePowerState::Unknown };
    readings_worker.run(pool_);

    ASSERT_EQ(gs.get()->readings.nreadings, 1u);

    readings_worker.run(pool_);

    ASSERT_EQ(gs.get()->readings.nreadings, 2u);
}

TEST_F(ReadingsWorkerSuite, ScannedModule_InvalidHeader) {
    auto mm = (LinuxModMux *)get_modmux();

    ModuleHeader header;
    bzero(&header, sizeof(ModuleHeader));
    mm->set_eeprom_data(ModulePosition::from(2), (uint8_t *)&header, sizeof(header));

    auto gs = get_global_state_ro();

    factory_wipe();

    ASSERT_EQ(gs.get()->readings.nreadings, 0u);

    fk_fake_uptime({ 20321 });

    ReadingsWorker readings_worker{ true, false, false, ModulePowerState::Unknown };
    readings_worker.run(pool_);

    ASSERT_EQ(gs.get()->readings.nreadings, 1u);
}

TEST_F(ReadingsWorkerSuite, ScannedModule_MultipleReadings) {
    auto mm = (LinuxModMux *)get_modmux();

    ModuleHeader header;
    bzero(&header, sizeof(ModuleHeader));
    header.manufacturer = FK_MODULES_MANUFACTURER;
    header.kind = FK_MODULES_KIND_RANDOM;
    header.version = 0x02;
    header.crc = fk_module_header_sign(&header);
    mm->set_eeprom_data(ModulePosition::from(2), (uint8_t *)&header, sizeof(header));

    fk_modules_builtin_register(&fk_test_module_fake_1);

    auto gs = get_global_state_ro();

    fk_fake_uptime({ 20321 });

    factory_wipe();

    ASSERT_EQ(gs.get()->readings.nreadings, 0u);

    ReadingsWorker readings_worker{ true, false, false, ModulePowerState::Unknown };
    readings_worker.run(pool_);

    ASSERT_EQ(gs.get()->readings.nreadings, 1u);

    fk_fake_uptime({ 30321 });

    readings_worker.run(pool_);

    ASSERT_EQ(gs.get()->readings.nreadings, 2u);

    fk_fake_uptime({ 40321 });

    readings_worker.run(pool_);

    ASSERT_EQ(gs.get()->readings.nreadings, 3u);

    {
        StandardPool pool{ "tests" };
        Storage storage{ memory_, pool, false };

        ASSERT_TRUE(storage.begin());

        auto reader = storage.file_reader(Storage::Data, pool);
        ASSERT_NE(reader, nullptr);

        ASSERT_TRUE(reader->seek_record(0, pool));

        MetaRecord meta_record{ pool };

        // State record
        auto bytes_read = reader->read(meta_record.for_decoding(), fk_data_DataRecord_fields);
        ASSERT_EQ(bytes_read, 578);

        // Modules record
        bytes_read = reader->read(meta_record.for_decoding(), fk_data_DataRecord_fields);
        ASSERT_EQ(bytes_read, 489);

        // Data record
        bytes_read = reader->read(meta_record.for_decoding(), fk_data_DataRecord_fields);
        ASSERT_EQ(bytes_read, 179);
        ASSERT_EQ(meta_record.record()->readings.reading, 2u);
        ASSERT_EQ(meta_record.record()->readings.meta, 1u);
        ASSERT_EQ(meta_record.record()->readings.uptime, 20321u);

        // Data record
        bytes_read = reader->read(meta_record.for_decoding(), fk_data_DataRecord_fields);
        ASSERT_EQ(bytes_read, 179);
        ASSERT_EQ(meta_record.record()->readings.reading, 3u);
        ASSERT_EQ(meta_record.record()->readings.meta, 1u);
        ASSERT_EQ(meta_record.record()->readings.uptime, 30321u);

        // Data record
        bytes_read = reader->read(meta_record.for_decoding(), fk_data_DataRecord_fields);
        ASSERT_EQ(bytes_read, 179);
        ASSERT_EQ(meta_record.record()->readings.reading, 4u);
        ASSERT_EQ(meta_record.record()->readings.meta, 1u);
        ASSERT_EQ(meta_record.record()->readings.uptime, 40321u);

        // End of file
        bytes_read = reader->read(meta_record.for_decoding(), fk_data_DataRecord_fields);
        ASSERT_EQ(bytes_read, -1);
    }
}

TEST_F(ReadingsWorkerSuite, ScannedModule_ModuleAdded) {
    auto mm = (LinuxModMux *)get_modmux();

    ModuleHeader header;
    bzero(&header, sizeof(ModuleHeader));
    header.manufacturer = FK_MODULES_MANUFACTURER;
    header.kind = FK_MODULES_KIND_RANDOM;
    header.version = 0x02;
    header.crc = fk_module_header_sign(&header);

    fk_modules_builtin_register(&fk_test_module_fake_1);

    auto gs = get_global_state_ro();

    factory_wipe();

    ASSERT_EQ(gs.get()->readings.nreadings, 0u);

    ReadingsWorker readings_worker{ true, false, false, ModulePowerState::Unknown };

    fk_fake_uptime({ 20321 });

    readings_worker.run(pool_);

    ASSERT_EQ(gs.get()->readings.nreadings, 1u);

    // Add the module
    mm->set_eeprom_data(ModulePosition::from(2), (uint8_t *)&header, sizeof(header));

    readings_worker.run(pool_);

    ASSERT_EQ(gs.get()->readings.nreadings, 2u);

    {
        StandardPool pool{ "tests" };
        Storage storage{ memory_, pool, false };

        ASSERT_TRUE(storage.begin());

        auto reader = storage.file_reader(Storage::Data, pool);
        ASSERT_NE(reader, nullptr);

        ASSERT_TRUE(reader->seek_record(0, pool));

        MetaRecord meta_record{ pool };

        // State record
        auto bytes_read = reader->read(meta_record.for_decoding(), fk_data_DataRecord_fields);
        ASSERT_EQ(bytes_read, 578);

        // Modules record
        bytes_read = reader->read(meta_record.for_decoding(), fk_data_DataRecord_fields);
        ASSERT_EQ(bytes_read, 428);

        // Data record
        bytes_read = reader->read(meta_record.for_decoding(), fk_data_DataRecord_fields);
        ASSERT_EQ(bytes_read, 166);
        ASSERT_EQ(meta_record.record()->readings.reading, 2u);
        ASSERT_EQ(meta_record.record()->readings.meta, 1u);
        ASSERT_EQ(meta_record.record()->readings.uptime, 20321u);

        // Modules record
        bytes_read = reader->read(meta_record.for_decoding(), fk_data_DataRecord_fields);
        ASSERT_EQ(bytes_read, 489);

        // Data record
        bytes_read = reader->read(meta_record.for_decoding(), fk_data_DataRecord_fields);
        ASSERT_EQ(bytes_read, 179);
        ASSERT_EQ(meta_record.record()->readings.reading, 4u);
        ASSERT_EQ(meta_record.record()->readings.meta, 3u);
        ASSERT_EQ(meta_record.record()->readings.uptime, 20321u);

        // End of file
        bytes_read = reader->read(meta_record.for_decoding(), fk_data_DataRecord_fields);
        ASSERT_EQ(bytes_read, -1);
    }
}
