#include "tests.h"
#include "common.h"
#include "hal/linux/linux.h"
#include "storage/events.h"
#include "storage_suite.h"

using namespace fk;

#define LOG_FACILITY "tests"

class EventsSuite : public StorageSuite {};

TEST_F(EventsSuite, FindingEvents_NoneYet) {
    factory_wipe();

    Storage storage{ memory_, pool_, false };
    ASSERT_TRUE(storage.begin());

    Events events{ &storage };
    MetaRecord record{ pool_ };
    ASSERT_FALSE(events.read(record, pool_));
}

TEST_F(EventsSuite, AppendEvent_LoraJoinOk_NoneYet) {
    factory_wipe();

    auto gs = get_global_state_rw();
    Storage storage{ memory_, pool_, false };
    ASSERT_TRUE(storage.begin());

    Events events{ &storage };
    LoraEvent event = LoraEvent::joined();
    ASSERT_TRUE(events.append(&event, gs.get(), get_fake_header(), pool_));

    auto attrs = storage.data_ops()->attributes(pool_);
    ASSERT_EQ(attrs->records, 2u);
    ASSERT_EQ(attrs->size, 990u);

    MetaRecord record{ pool_ };
    ASSERT_TRUE(events.read(record, pool_));
    auto events_array = pb_get_array(record.record()->events, &pool_);
    ASSERT_EQ(events_array->length, 1u);

    BufferChain chain{ &pool_ };
    ASSERT_TRUE(events.copy(&chain, pool_));
    ASSERT_EQ(chain.length(), 412u);
}

TEST_F(EventsSuite, AppendEvent_LoraJoinFail_LoraJoinOk) {
    factory_wipe();

    auto gs = get_global_state_rw();
    Storage storage{ memory_, pool_, false };
    ASSERT_TRUE(storage.begin());

    Events events{ &storage };
    LoraEvent failed = LoraEvent::failed_join();
    ASSERT_TRUE(events.append(&failed, gs.get(), get_fake_header(), pool_));

    LoraEvent ok = LoraEvent::joined();
    ASSERT_TRUE(events.append(&ok, gs.get(), get_fake_header(), pool_));

    auto attrs = storage.data_ops()->attributes(pool_);
    ASSERT_EQ(attrs->records, 3u);
    ASSERT_EQ(attrs->size, 1402u);

    MetaRecord record{ pool_ };
    ASSERT_TRUE(events.read(record, pool_));
    auto events_array = pb_get_array(record.record()->events, &pool_);
    ASSERT_EQ(events_array->length, 1u);

    BufferChain chain{ &pool_ };
    ASSERT_TRUE(events.copy(&chain, pool_));
    ASSERT_EQ(chain.length(), 412u);
}

TEST_F(EventsSuite, AppendEvent_LoraJoinFail_Restart_LoraJoinOk) {
    factory_wipe();

    auto gs = get_global_state_rw();
    Storage storage{ memory_, pool_, false };
    ASSERT_TRUE(storage.begin());

    Events events{ &storage };
    LoraEvent failed = LoraEvent::failed_join();
    ASSERT_TRUE(events.append(&failed, gs.get(), get_fake_header(), pool_));

    RestartEvent restarted{ FK_RESET_REASON_BOD33 };
    ASSERT_TRUE(events.append(&restarted, gs.get(), get_fake_header(), pool_));

    LoraEvent ok = LoraEvent::joined();
    ASSERT_TRUE(events.append(&ok, gs.get(), get_fake_header(), pool_));

    auto attrs = storage.data_ops()->attributes(pool_);
    ASSERT_EQ(attrs->records, 4u);
    ASSERT_EQ(attrs->size, 1842u);

    MetaRecord record{ pool_ };
    ASSERT_TRUE(events.read(record, pool_));
    auto events_array = pb_get_array(record.record()->events, &pool_);
    ASSERT_EQ(events_array->length, 2u);

    BufferChain chain{ &pool_ };
    ASSERT_TRUE(events.copy(&chain, pool_));
    ASSERT_EQ(chain.length(), 426u);
}