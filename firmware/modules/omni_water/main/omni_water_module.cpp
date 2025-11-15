#include "omni_water_module.h"
#include "omni_water_api.h"

#include "modules/eeprom.h"
#include "platform.h"
#include "state_ref.h"

#include "hal/display.h"

namespace fk {

FK_DECLARE_LOGGER("omniwater");

#define FK_MCP2803_ADDRESS 0x22
#define FK_ADS1219_ADDRESS 0x45

#define FK_MCP2803_IODIR 0b00000010
#define FK_MCP2803_GPPU  0b00000010

#define FK_MCP2803_GPIO_ON  0b00000001
#define FK_MCP2803_GPIO_OFF 0b00000000

#define FK_MCP2803_GPIO_EXCITE_ON  0b00000101
#define FK_MCP2803_GPIO_EXCITE_OFF 0b00000001

#define FK_MCP2803_GPIO_PH   0b00101000
#define FK_MCP2803_GPIO_EC   0b00001000
#define FK_MCP2803_GPIO_TEMP 0b00011000
#define FK_MCP2803_GPIO_DO   0b00111000
#define FK_MCP2803_GPIO_ORP  0b00000000

static WaterMcpGpioConfig OmniPhConfig{ FK_MCP2803_IODIR,
                                        FK_MCP2803_GPPU,
                                        FK_MCP2803_GPIO_ON | FK_MCP2803_GPIO_PH,
                                        FK_MCP2803_GPIO_OFF | FK_MCP2803_GPIO_PH,
                                        FK_MCP2803_GPIO_EXCITE_ON | FK_MCP2803_GPIO_PH,
                                        FK_MCP2803_GPIO_EXCITE_OFF | FK_MCP2803_GPIO_PH };

static WaterMcpGpioConfig OmniEcConfig{ FK_MCP2803_IODIR,
                                        FK_MCP2803_GPPU,
                                        FK_MCP2803_GPIO_ON | FK_MCP2803_GPIO_EC,
                                        FK_MCP2803_GPIO_OFF | FK_MCP2803_GPIO_EC,
                                        FK_MCP2803_GPIO_EXCITE_ON | FK_MCP2803_GPIO_EC,
                                        FK_MCP2803_GPIO_EXCITE_OFF | FK_MCP2803_GPIO_EC };

static WaterMcpGpioConfig OmniTempConfig{ FK_MCP2803_IODIR,
                                          FK_MCP2803_GPPU,
                                          FK_MCP2803_GPIO_ON | FK_MCP2803_GPIO_TEMP,
                                          FK_MCP2803_GPIO_OFF | FK_MCP2803_GPIO_TEMP,
                                          FK_MCP2803_GPIO_EXCITE_ON | FK_MCP2803_GPIO_TEMP,
                                          FK_MCP2803_GPIO_EXCITE_OFF | FK_MCP2803_GPIO_TEMP };

static WaterMcpGpioConfig OmniDoConfig{ FK_MCP2803_IODIR,
                                        FK_MCP2803_GPPU,
                                        FK_MCP2803_GPIO_ON | FK_MCP2803_GPIO_DO,
                                        FK_MCP2803_GPIO_OFF | FK_MCP2803_GPIO_DO,
                                        FK_MCP2803_GPIO_EXCITE_ON | FK_MCP2803_GPIO_DO,
                                        FK_MCP2803_GPIO_EXCITE_OFF | FK_MCP2803_GPIO_DO };

static WaterMcpGpioConfig OmniOrpConfig{ FK_MCP2803_IODIR,
                                         FK_MCP2803_GPPU,
                                         FK_MCP2803_GPIO_ON | FK_MCP2803_GPIO_ORP,
                                         FK_MCP2803_GPIO_OFF | FK_MCP2803_GPIO_ORP,
                                         FK_MCP2803_GPIO_EXCITE_ON | FK_MCP2803_GPIO_ORP,
                                         FK_MCP2803_GPIO_EXCITE_OFF | FK_MCP2803_GPIO_ORP };

OmniWaterModule::OmniWaterModule(Pool &pool) {
}

OmniWaterModule::~OmniWaterModule() {
}

ModuleEepromContents OmniWaterModule::read_eeprom(ModuleContext mc, Pool &pool) {
    auto mec = Module::read_eeprom(mc, pool);
    if (!cfg_.load(mec.config)) {
        logwarn("configuration error");
    }

    header_ = mec.header;

    return mec;
}

ModuleReturn OmniWaterModule::api(ModuleContext mc, HttpServerConnection *connection, Pool &pool) {
    OmniWaterApi api;
    if (!api.handle(mc, connection, pool)) {
        logerror("api (ms::fatal)");
        return { ModuleStatus::Fatal };
    }

    return { ModuleStatus::Ok };
}

ModuleReturn OmniWaterModule::service(ModuleContext mc, Pool &pool) {
    return { ModuleStatus::Ok };
}

static SensorMetadata const fk_module_omni_water_sensor_metas[] = {
    { .name = "ph", .unitOfMeasure = "pH", .uncalibratedUnitOfMeasure = "V", .flags = 0 },
    { .name = "ec", .unitOfMeasure = "µS/cm", .uncalibratedUnitOfMeasure = "V", .flags = 0 },
    { .name = "temp", .unitOfMeasure = "°C", .uncalibratedUnitOfMeasure = "V", .flags = 0 },
    { .name = "do", .unitOfMeasure = "%", .uncalibratedUnitOfMeasure = "V", .flags = 0 },
    { .name = "orp", .unitOfMeasure = "mV", .uncalibratedUnitOfMeasure = "V", .flags = 0 },
};

static ModuleSensors fk_module_omni_water_sensors = {
    .nsensors = sizeof(fk_module_omni_water_sensor_metas) / sizeof(SensorMetadata),
    .sensors = fk_module_omni_water_sensor_metas,
};

ModuleSensors const *OmniWaterModule::get_sensors(Pool &pool) {
    return &fk_module_omni_water_sensors;
}

ModuleConfiguration const OmniWaterModule::get_configuration(Pool &pool) {
    return ModuleConfiguration{ ModulePower::ReadingsOnly, DefaultModuleOrder };
}

bool OmniWaterModule::can_enable() {
    return lockout_.can_enable();
}

ModuleReturn OmniWaterModule::initialize(ModuleContext mc, Pool &pool) {
    loginfo("initialize");

    auto &bus = mc.module_bus();
    WaterProtocol water_protocol{ pool, bus, WaterModality::PH, OmniPhConfig, false };
    if (!water_protocol.initialize()) {
        return { ModuleStatus::Fatal };
    }

    return { ModuleStatus::Ok };
}

struct Modality {
    const char *name;
    WaterModality modality;
    WaterMcpGpioConfig config;
};

static Modality AllModalities[] = {
    { "ph", WaterModality::PH, OmniPhConfig },       { "ec", WaterModality::EC, OmniEcConfig },
    { "temp", WaterModality::Temp, OmniTempConfig }, { "do", WaterModality::DO, OmniDoConfig },
    { "orp", WaterModality::ORP, OmniOrpConfig },
};

ModuleReadings *OmniWaterModule::take_readings(ReadingsContext mc, Pool &pool) {
    if (!lockout_.try_enable(mc.position())) {
        return new (pool) EmptyReadings();
    }

    auto uptime = fk_uptime();

    auto &bus = mc.module_bus();

    auto mr = new (pool) NModuleReadings<5>();
    auto position = 0u;

    for (auto &modality : AllModalities) {
        loginfo("omni:modality %s", modality.name);

        WaterProtocol water_protocol{ pool, bus, modality.modality, modality.config, false };
        if (!water_protocol.initialize()) {
            logwarn("water-proto: initialize error");
            return nullptr;
        }

        auto water_readings = water_protocol.take_readings(mc, cfg_.cal(), pool);
        if (water_readings == nullptr) {
            logwarn("water-proto: readings error");
        } else {
            auto sr = SensorReading{ mc.now(), water_readings->uncalibrated, water_readings->calibrated, water_readings->factory };
            mr->set(position, sr);
        }

        position++;

        fk_delay(100);
    }

    // Enable lockout.
    lockout_.enable_until_uptime(uptime + OneMinuteMs);

    if (mr->size() == 0) {
        return nullptr;
    }

    return mr;
}

MenuScreen *OmniWaterModule::debug_menu(Pool *pool) {
    auto option_index = 0u;
    auto options = (MenuOption **)pool->malloc(sizeof(MenuOption *) * (5 + 1));
    for (auto &modality : AllModalities) {
        options[option_index++] = to_lambda_option(pool, modality.name, [=](MenuContext &menus) {
            loginfo("'%s' selected", modality.name);

            auto mm = get_modmux();

            // TODO Need to get our module position.
            mm->enable_module(ModulePosition::from(0), ModulePower::Always);

            auto bus = get_board()->i2c_module();
            WaterProtocol water_protocol{ *pool, bus, modality.modality, modality.config, false };
            if (!water_protocol.initialize()) {
                logwarn("water-proto: initialize error");
            }

            return MenuHandlerReturn::none();
        });
    }

    options[option_index] = nullptr;

    return new (pool) MenuScreen("omni-debug", options);
}

} // namespace fk
