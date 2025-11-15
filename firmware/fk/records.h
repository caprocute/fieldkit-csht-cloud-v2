#pragma once

#include <fk-data-protocol.h>
#include <fk-app-protocol.h>

#include "common.h"
#include "protobuf.h"

namespace fk {

void fk_data_record_decoding_new(fk_data_DataRecord *record, Pool *pool);

void fk_data_record_encoding_new(fk_data_DataRecord *record, Pool *pool);

fk_app_HttpQuery *fk_http_query_prepare_decoding(fk_app_HttpQuery *query, Pool *pool);

fk_app_HttpReply *fk_http_reply_encoding_initialize(fk_app_HttpReply *reply, Pool *pool);

void fk_lora_record_encoding_new(fk_data_LoraRecord *record, Pool *pool);

fk_data_ModuleConfiguration *fk_module_configuration_decoding_new(Pool *pool);

fk_app_ModuleHttpQuery *fk_module_query_prepare_decoding(fk_app_ModuleHttpQuery *reply, Pool *pool);

fk_app_ModuleHttpReply *fk_module_reply_prepare_encoding(fk_app_ModuleHttpReply *reply, Pool *pool);

void fk_prepare_events_record_encode(fk_data_Event *record, Pool *pool);

} // namespace fk
