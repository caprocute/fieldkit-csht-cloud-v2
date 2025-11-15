#pragma once

#include "hal/hal.h"

namespace fk {

class MetalModMux : public ModMux {
private:
    uint8_t gpio_{ 0 };
    ModulePosition active_module_{ ModulePosition::None };
    ModulePower bay_power_[MaximumNumberOfPhysicalModules];
    uint32_t enabled_at_[MaximumNumberOfPhysicalModules] = { 0 };

public:
    MetalModMux();

public:
    bool begin() override;
    bool enable_all_modules() override;
    bool disable_all_modules() override;
    bool enable_module(ModulePosition position, ModulePower power) override;
    bool disable_module(ModulePosition position) override;
    bool power_cycle(ModulePosition position) override;
    bool choose(ModulePosition position) override;
    bool choose_nothing() override;
    bool enable_topology_irq() override;
    bool disable_topology_irq() override;
    optional<Topology> read_topology_register() override;
    ModulesLock lock() override;
    bool any_modules_on(ModulePower power) override;
    bool is_module_on(ModulePosition position) override;
    bool try_read_eeprom(uint32_t address, uint8_t *data, size_t size) override;
    EepromLock lock_eeprom() override;
    void release_eeprom() override;
    void signal_eeprom(uint8_t times) override;
    void get_power_status(char *buffer, size_t size) override;
    ModulePower get_module_power(ModulePosition position) override;

private:
    bool update_gpio(uint8_t new_gpio);
};

} // namespace fk
