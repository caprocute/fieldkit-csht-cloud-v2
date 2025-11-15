#pragma once

#include "common.h"
#include "pool.h"
#include "config.h"
#include "collections.h"

namespace fk {

class GlobalState;

typedef struct xbm_data_t {
    uint8_t w;
    uint8_t h;
    const uint8_t *data;
} xbm_data_t;

struct DisplayScreen {};

struct TaskProgress {
    const char *operation;
    float progress;
};

struct WorkerInfo {
    const char *name;
    float progress;
    bool visible;
};

struct HomeScreen : public DisplayScreen {
    struct Gps {
        bool enabled;
        bool fix;
    };

    struct Network {
        bool enabled;
        bool connected;
        uint32_t bytes_rx;
        uint32_t bytes_tx;
    };

    struct PowerInfo {
        float battery;
        BatteryStatus battery_status;
    };

    uint32_t time;
    Network network;
    Gps gps;
    bool recording;
    bool logo;
    const char *debug_mode;
    const char *primary;
    const char *secondary;
    PowerInfo power;
    TaskProgress progress;
    WorkerInfo workers[NumberOfWorkerTasks];
    uint32_t readings;
    uint32_t messages;
};

class ViewController;

class MenuContext {
public:
    ViewController *views;
    Pool *pool;

public:
    MenuContext(ViewController *views, Pool *pool) : views(views), pool(pool) {
    }
};

struct ItemScreen : public DisplayScreen {};

class MenuScreen;

class MenuHandlerReturn {
private:
    bool home_{ false };
    bool back_{ false };
    bool reset_{ false };
    MenuScreen *menu_{ nullptr };
    uint32_t menu_timeout_{ 0 };

private:
    MenuHandlerReturn(bool home, bool back, bool reset, MenuScreen *menu, uint32_t menu_timeout)
        : home_(home), back_(back), reset_(reset), menu_(menu), menu_timeout_(menu_timeout) {
    }

public:
    bool go_back() const {
        return back_;
    }

    bool go_home() const {
        return home_;
    }

    MenuScreen *go_menu() const {
        return menu_;
    }

    uint32_t menu_timeout() const {
        return menu_timeout_;
    }

    bool reset_menu() const {
        return reset_;
    }

public:
    static MenuHandlerReturn none() {
        return MenuHandlerReturn{ false, false, false, nullptr, 0 };
    }

    static MenuHandlerReturn reset() {
        return MenuHandlerReturn{ false, false, true, nullptr, 0 };
    }

    static MenuHandlerReturn back() {
        return MenuHandlerReturn{ false, true, false, nullptr, 0 };
    }

    static MenuHandlerReturn home() {
        return MenuHandlerReturn{ true, false, false, nullptr, 0 };
    }

    static MenuHandlerReturn menu(MenuScreen *menu) {
        return MenuHandlerReturn{ false, false, false, menu, FiveSecondsMs };
    }

    static MenuHandlerReturn menu(MenuScreen *menu, uint32_t menu_timeout) {
        return MenuHandlerReturn{ false, false, false, menu, menu_timeout };
    }
};

struct MenuOption {
    const char *label_;
    bool focused_;
    bool selected_;
    bool visible_;
    bool active_;

    MenuOption(const char *label) : label_(label), focused_(false), selected_(false), visible_(true), active_(true) {
    }

    virtual MenuHandlerReturn on_selected(MenuContext &menus) = 0;

    virtual bool active() const {
        return active_;
    }

    virtual void active(bool active) {
        active_ = active;
    }

    virtual bool visible() const {
        return visible_;
    }

    virtual void visible(bool visible) {
        visible_ = visible;
    }

    virtual bool selected() const {
        return selected_;
    }

    virtual void selected(bool value) {
        selected_ = value;
    }

    virtual bool focused() const {
        return focused_;
    }

    virtual void focused(bool value) {
        focused_ = value;
    }

    virtual const char *label() const {
        return label_;
    }

    virtual void refresh(GlobalState const *gs) {
    }
};

struct SimpleScreen : public DisplayScreen {
    const char *message{ nullptr };
    const char *secondary{ nullptr };

    explicit SimpleScreen() {
    }

    explicit SimpleScreen(const char *message) : message(message) {
    }

    explicit SimpleScreen(const char *message, const char *secondary) : message(message), secondary(secondary) {
    }
};

struct DisplayReading {
    const char *module_name{ nullptr };
    const char *sensor_name{ nullptr };
    optional<float> value;

    DisplayReading() {
    }

    DisplayReading(const char *module_name, const char *sensor_name, optional<float> value)
        : module_name(module_name), sensor_name(sensor_name), value(value) {
    }
};

struct ReadingScreen : public DisplayScreen {
    collection<DisplayReading> *readings{ nullptr };

    ReadingScreen() {
    }

    ReadingScreen(collection<DisplayReading> *readings) : readings(readings) {
    }
};

template <typename TSelect> struct LambdaOption : public MenuOption {
    TSelect select_fn;

    LambdaOption(const char *label, TSelect select_fn) : MenuOption(label), select_fn(select_fn) {
    }

    MenuHandlerReturn on_selected(MenuContext &menus) override {
        return select_fn(menus);
    }
};

template <typename TSelect> LambdaOption<TSelect> *to_lambda_option(Pool *pool, const char *label, TSelect fn) {
    return new (*pool) LambdaOption<TSelect>(label, fn);
}

class MenuScreen : public DisplayScreen {
private:
    const char *title_{ nullptr };
    /**
     * A NULL value indicates the end of this array.
     */
    MenuOption **options_{ nullptr };
    size_t number_options_{ 0 };

public:
    MenuScreen(const char *title, MenuOption **options);

public:
    size_t number_of_options() const {
        return number_options_;
    }

    MenuOption *get_option(size_t i) const {
        FK_ASSERT(i < number_of_options());
        return options_[i];
    }

public:
    const char *get_title() const {
        return title_;
    }

    void refresh(GlobalState const *gs) {
        for (auto i = 0u; i < number_of_options(); ++i) {
            get_option(i)->refresh(gs);
        }
    }

    void reset() {
        for (auto i = 0u; i < number_of_options(); ++i) {
            get_option(i)->focused(i == 0);
        }
    }
};

enum CheckType {
    PassFail,
    Flags,
    Skipped,
};

struct Check {
    const char *name;
    CheckType type;
    uint32_t value;
};

struct SelfCheckScreen : public DisplayScreen {
    Check **checks;
};

struct ModuleStatusScreen : public DisplayScreen {
    uint8_t bay;
    const char *name;
    const char *message;

    ModuleStatusScreen() {
    }

    ModuleStatusScreen(uint8_t bay, const char *name, const char *message) : bay(bay), name(name), message(message) {
    }
};

class Display {
public:
    virtual bool begin() = 0;
    virtual void on() = 0;
    virtual void off() = 0;
    virtual void centered(const xbm_data_t &xbm) = 0;
    virtual void company_logo() = 0;
    virtual void fk_logo() = 0;
    virtual void home(HomeScreen const &screen) = 0;
    virtual void menu(MenuScreen const &screen) = 0;
    virtual void self_check(SelfCheckScreen const &screen) = 0;
    virtual void simple(SimpleScreen const &screen) = 0;
    virtual void item(ItemScreen const &screen) = 0;
    virtual void reading(ReadingScreen const &screen) = 0;
    virtual void module_status(ModuleStatusScreen const &screen) = 0;
    virtual void fault(FaultCode const *code) = 0;
};

class NullDisplay : public Display {
public:
    bool begin() override {
        return true;
    }
    void on() override {
    }
    void off() override {
    }
    void centered(const xbm_data_t &xbm) override {
    }
    void company_logo() override {
    }
    void fk_logo() override {
    }
    void home(HomeScreen const &screen) override {
    }
    void menu(MenuScreen const &screen) override {
    }
    void self_check(SelfCheckScreen const &screen) override {
    }
    void simple(SimpleScreen const &screen) override {
    }
    void item(ItemScreen const &screen) override {
    }
    void reading(ReadingScreen const &screen) override {
    }
    void module_status(ModuleStatusScreen const &screen) override {
    }
    void fault(FaultCode const *code) override {
    }
};

Display *get_display();

} // namespace fk
