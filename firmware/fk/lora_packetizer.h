#pragma once

#include <fk-data-protocol.h>

#include "common.h"
#include "containers.h"
#include "buffers.h"
#include "state.h"

namespace fk {

class LoraReadingsPacketizer {
public:
    tl::expected<BufferPtr *, Error> packetize(GlobalState const *gs, Pool &pool);
};

class LoraLocationPacketizer {
public:
    tl::expected<BufferPtr *, Error> packetize(GlobalState const *gs, Pool &pool);
};

class LoraStatusPacketizer {
public:
    tl::expected<BufferPtr *, Error> packetize(GlobalState const *gs, Pool &pool);
};

} // namespace fk
