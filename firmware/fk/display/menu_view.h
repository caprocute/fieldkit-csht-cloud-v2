#pragma once

#include "common.h"
#include "display_views.h"
#include "hal/display.h"
#include "state.h"

namespace fk {

class GotoMenu {
public:
    virtual MenuScreen *goto_menu(MenuScreen *screen, MenuScreen *previous_menu = nullptr, uint32_t hold_time = FiveSecondsMs) = 0;
};

class MenuView : public DisplayView, GotoMenu {
private:
    Pool *pool_{ nullptr };
    ViewController *views_{ nullptr };
    MenuScreen *active_menu_{ nullptr };
    MenuScreen *previous_menu_{ nullptr };
    uint32_t menu_time_{ 0 };
    uint32_t hold_time_{ FiveSecondsMs };
    uint32_t refresh_time_{ 0 };

public:
    MenuView(ViewController *views, Pool &pool);

public:
    void show() override;
    void show_for_module(uint8_t bay);
    void show_readings();
    void tick(ViewController *views, Pool &pool) override;
    void up(ViewController *views) override;
    void down(ViewController *views) override;
    void enter(ViewController *views) override;

private:
    void refresh();
    MenuScreen *goto_menu(MenuScreen *screen, MenuScreen *previous_menu = nullptr, uint32_t hold_time = FiveSecondsMs) override;

private:
    static void focus_up(MenuScreen &screen);
    static void focus_down(MenuScreen &screen);
    static void refresh_visible(MenuScreen &screen, int8_t focused_index);
    static MenuOption *selected(MenuScreen &screen);
};

} // namespace fk
