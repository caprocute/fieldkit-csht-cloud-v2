#pragma once

#include "worker.h"
#include "storage/storage.h"

namespace fk {

struct ConnectionInfo {
    const char *url;
    const char *token;
    const char *name;
    const char *generation;

    bool is_configured() const {
        return strlen(url) > 0 && strlen(token) > 0;
    }
};

class UploadDataWorker : public Worker {
private:
    bool all_meta_{ false };
    bool all_data_{ false };

public:
    explicit UploadDataWorker();
    explicit UploadDataWorker(bool all_meta, bool all_data);

public:
    void run(Pool &pool) override;

public:
    const char *name() const override {
        return "upldata";
    }

private:
    struct FileUpload {
        uint32_t record;

        // cppcheck-suppress noExplicitConstructor
        FileUpload(uint32_t record) : record(record) {
        }

        operator bool() {
            return record > 0;
        }
    };

    FileUpload upload_file(ConnectionInfo connection, Storage &storage, uint8_t file_number, uint32_t first_record, const char *type,
                           Pool &pool);
};

FK_ENABLE_TYPE_NAME(UploadDataWorker);

} // namespace fk
