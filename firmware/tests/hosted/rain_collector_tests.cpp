#include "tests.h"
#include "weather/main/rain_collector.h"

using namespace fk;

FK_DECLARE_LOGGER("tests");

class RainCollectorSuite : public ::testing::Test {
protected:
};

static void aw_initialize(fk_weather_aggregated_t *aw) {
    memzero(aw, sizeof(fk_weather_aggregated_t));
    for (size_t m = 0; m < 60; ++m) {
        aw->rain_60m[m].ticks = FK_WEATHER_TICKS_NULL;
    }
}

TEST_F(RainCollectorSuite, New) {
    RainCollector collector;
    ASSERT_EQ(collector.ticks(), 0u);
}

TEST_F(RainCollectorSuite, IncludeOneMinuteNoRain) {
    RainCollector collector;
    fk_weather_aggregated_t aw;
    aw_initialize(&aw);

    aw.rain_60m[0].ticks = 0;
    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 0u);
}

TEST_F(RainCollectorSuite, IncludeOneMinuteSomeRain) {
    RainCollector collector;
    fk_weather_aggregated_t aw;
    aw_initialize(&aw);

    aw.rain_60m[0].ticks = 2;
    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 2u);

    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 2u);

    aw.rain_60m[0].ticks = 4;
    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 4u);
}

TEST_F(RainCollectorSuite, IncludeOverTwoMinutes) {
    RainCollector collector;
    fk_weather_aggregated_t aw;
    aw_initialize(&aw);

    aw.rain_60m[0].ticks = 2;
    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 2u);

    aw.minute = 1;
    aw.rain_60m[1].ticks = 0;
    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 2u);

    aw.rain_60m[1].ticks = 4;
    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 6u);
}

TEST_F(RainCollectorSuite, IncludeTwoMinutesPassedNoRain) {
    RainCollector collector;
    fk_weather_aggregated_t aw;
    aw_initialize(&aw);

    aw.minute = 0;
    aw.rain_60m[0].ticks = 0;
    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 0u);

    aw.minute = 3;
    aw.rain_60m[1].ticks = 0;
    aw.rain_60m[2].ticks = 0;
    aw.rain_60m[3].ticks = 0;
    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 0u);
}

TEST_F(RainCollectorSuite, IncludeTwoMinutesPassed) {
    RainCollector collector;
    fk_weather_aggregated_t aw;
    aw_initialize(&aw);

    aw.minute = 0;
    aw.rain_60m[0].ticks = 1;
    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 1u);

    aw.minute = 3;
    aw.rain_60m[0].ticks = 2;
    aw.rain_60m[1].ticks = 2;
    aw.rain_60m[2].ticks = 2;
    aw.rain_60m[3].ticks = 2;
    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 8u);

    aw.minute = 3;
    aw.rain_60m[3].ticks = 3;
    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 9u);

    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 9u);
}

TEST_F(RainCollectorSuite, IncludeWholeHour) {
    RainCollector collector;
    fk_weather_aggregated_t aw;
    aw_initialize(&aw);

    aw.minute = 0;
    aw.rain_60m[0].ticks = 0;
    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 0u);

    aw.minute = 59;
    for (int32_t i = 0; i < 60; ++i) {
        aw.rain_60m[i].ticks = 1;
    }
    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 60u);
}

TEST_F(RainCollectorSuite, IncludeWrapAround) {
    RainCollector collector;
    fk_weather_aggregated_t aw;
    aw_initialize(&aw);

    aw.minute = 55;
    aw.rain_60m[55].ticks = 0;
    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 0u);

    aw.minute = 5;
    aw.rain_60m[56].ticks = 1;
    aw.rain_60m[57].ticks = 1;
    aw.rain_60m[58].ticks = 1;
    aw.rain_60m[59].ticks = 1;
    aw.rain_60m[00].ticks = 1;
    aw.rain_60m[01].ticks = 1;
    aw.rain_60m[02].ticks = 1;
    aw.rain_60m[03].ticks = 1;
    aw.rain_60m[04].ticks = 1;
    aw.rain_60m[05].ticks = 1;
    collector.include(&aw);
    ASSERT_EQ(collector.ticks(), 10u);
}
