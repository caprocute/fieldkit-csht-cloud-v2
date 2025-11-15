#include "ms5837_module.h"
#include "MS5837.h"

namespace fk {

FK_DECLARE_LOGGER("ms5837");

Ms5837Module::Ms5837Module(Pool &pool) {
}

Ms5837Module::~Ms5837Module() {
}

ModuleReturn Ms5837Module::initialize(ModuleContext mc, Pool &pool) {
    return { ModuleStatus::Ok };
}

ModuleReturn Ms5837Module::api(ModuleContext mc, HttpServerConnection *connection, Pool &pool) {
    connection->busy(0, "unsupported", pool);

    return { ModuleStatus::Fatal };
}

ModuleReturn Ms5837Module::service(ModuleContext mc, Pool &pool) {
    return { ModuleStatus::Ok };
}

static SensorMetadata const fk_module_ms5837_sensor_metas[] = {
    { .name = "temp", .unitOfMeasure = "°C", .uncalibratedUnitOfMeasure = "°C", .flags = 0 },
    { .name = "depth", .unitOfMeasure = "kPa", .uncalibratedUnitOfMeasure = "kPa", .flags = 0 },
};

static ModuleSensors fk_module_ms5837_sensors = {
    .nsensors = sizeof(fk_module_ms5837_sensor_metas) / sizeof(SensorMetadata),
    .sensors = fk_module_ms5837_sensor_metas,
};

ModuleSensors const *Ms5837Module::get_sensors(Pool &pool) {
    return &fk_module_ms5837_sensors;
}

ModuleConfiguration const Ms5837Module::get_configuration(Pool &pool) {
    return ModuleConfiguration{ ModulePower::ReadingsOnly, DefaultModuleOrder };
}

ModuleReadings *Ms5837Module::take_readings(ReadingsContext mc, Pool &pool) {
    MS5837 ms5837;

    // TODO Refactor to use our I2C abstraction? Or simply map to Arduino type.
    if (!ms5837.begin(Wire2)) {
        logerror("ms5837:missing");
        return nullptr;
    }

    /**
     * Hello traveller!
     *
     * As of today, we do this manually rather than relying on the
     * self-identification features of these chips. According to the
     * documentation the `version` portion of the first PROM register is
     * supposed to identify the model for these.
     *
     * Only, there seems to be some issues.
     *
     * None of the 30BA sensors I've received or seen in the wild declare
     * themselves properly. In fact, all of the versions come back as 0,
     * indicating that they are 02BA models. Only, we know they aren't because
     * the values produced by them only make sense if you force the model to
     * 30BA.
     *
     * This means we'll need some user intervention to understand which model is
     * actually attached.
     */
    ms5837.setModel(MS5837::MS5837_02BA);
    ms5837.read();

    const float MBAR_TO_KPA = 0.1f;
    auto temperature = ms5837.temperature();
    auto pressure_kpa = ms5837.pressure(MBAR_TO_KPA);

    auto mr = new (pool) NModuleReadings<2>();
    mr->set(0, SensorReading{ mc.now(), temperature, temperature });
    mr->set(1, SensorReading{ mc.now(), pressure_kpa, pressure_kpa });

    return mr;
}

} // namespace fk
