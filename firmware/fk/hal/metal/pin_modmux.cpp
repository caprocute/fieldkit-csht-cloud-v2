#include "hal/hal.h"
#include "hal/metal/metal.h"
#include "modules/eeprom.h"

#if defined(__SAMD51__)

namespace fk {

#define FKUW_PIN_PH_POWER     (32u) // A21
#define FKUW_PIN_EC_POWER     (31u) // A22
#define FKUW_PIN_DO_POWER     (30u) // A23
#define FKUW_PIN_MS5837_POWER (59u) // A4
#define FKUW_PIN_BAY_1_POWER  (68u) // A5
#define FKUW_PIN_BAY_2_POWER  (61u) // A6
#define FKUW_PIN_BAY_3_POWER  (60u) // A7

const uint8_t ModulePowerPins[7] = { FKUW_PIN_PH_POWER,    FKUW_PIN_EC_POWER,    FKUW_PIN_DO_POWER,   FKUW_PIN_MS5837_POWER,
                                     FKUW_PIN_BAY_1_POWER, FKUW_PIN_BAY_2_POWER, FKUW_PIN_BAY_3_POWER };

FK_DECLARE_LOGGER("pinmodmux");

PinModMux::PinModMux() {
}

bool PinModMux::begin() {
    available_ = true;
    enabled_ = ModulePosition::None;

    loginfo("begin");

    for (auto &pin : ModulePowerPins) {
        pinMode(pin, OUTPUT);
        digitalWrite(pin, LOW);
    }

    return true;
}

bool PinModMux::enable_topology_irq() {
    return false;
}

bool PinModMux::disable_topology_irq() {
    return false;
}

optional<Topology> PinModMux::read_topology_register() {
    return { 0 };
}

bool PinModMux::enable_all_modules() {
    return false;
}

bool PinModMux::disable_all_modules() {
    return choose_nothing();
}

bool PinModMux::enable_module(ModulePosition position, ModulePower power) {
    if (position == ModulePosition::Virtual) {
        return choose_nothing();
    }

    if (!disable_all_modules()) {
        logwarn("diasble all failed");
    }

    if (position.integer() >= MaximumNumberOfPhysicalModules) {
        logerror("module position out of bounds");
        return false;
    }

    logdebug("[%d] selecting", position.integer());
    auto &pin = ModulePowerPins[position.integer()];
    digitalWrite(pin, HIGH);

    enabled_ = position;

    fk_delay(100);

    return true;
}

bool PinModMux::disable_module(ModulePosition position) {
    if (enabled_ != ModulePosition::None && enabled_ != position) {
        logwarn("[%d] disabled while inactive");
    }

    return disable_all_modules();
}

bool PinModMux::power_cycle(ModulePosition position) {
    if (!disable_module(position)) {
        return false;
    }

    fk_delay(1000); // Too long?

    if (!enable_module(position, ModulePower::ReadingsOnly)) {
        return false;
    }

    return true;
}

bool PinModMux::choose(ModulePosition position) {
    return enable_module(position, ModulePower::ReadingsOnly);
}

bool PinModMux::try_read_eeprom(uint32_t address, uint8_t *data, size_t size) {
    auto module_bus = get_board()->i2c_module();
    UnknownEeprom unknown{ module_bus };
    auto eeprom = unknown.find();
    if (!eeprom) {
        return false;
    }
    if (!eeprom->read_data(address, data, size)) {
        return false;
    }
    return true;
}

bool PinModMux::choose_nothing() {
    for (auto &pin : ModulePowerPins) {
        if (pin > 0) {
            pinMode(pin, OUTPUT);
            digitalWrite(pin, LOW);
        }
    }

    enabled_ = ModulePosition::None;

    return true;
}

ModulesLock PinModMux::lock() {
    auto modules_lock = modules_mutex.acquire(UINT32_MAX);

    FK_ASSERT(modules_lock);

    return { std::move(modules_lock), EepromLock{}, fk_uptime() };
}

bool PinModMux::any_modules_on(ModulePower power) {
    return enabled_ != ModulePosition::None;
}

bool PinModMux::is_module_on(ModulePosition position) {
    return enabled_ == position;
}

} // namespace fk

#endif
