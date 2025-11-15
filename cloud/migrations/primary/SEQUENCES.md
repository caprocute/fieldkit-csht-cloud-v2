# Thống Kê Sequences cho ID trong Database

Tài liệu này liệt kê tất cả các sequence được sử dụng cho ID trong các bảng của database FieldKit.

## Quy Tắc Chung

- Tất cả các bảng sử dụng `serial` hoặc `SERIAL` cho cột `id` PRIMARY KEY
- PostgreSQL tự động tạo sequence với tên: `{table_name}_id_seq`
- Khi INSERT không chỉ định ID, PostgreSQL tự động sử dụng `nextval('{table_name}_id_seq')`
- Để reset sequence về giá trị đúng: `SELECT setval('{table_name}_id_seq', COALESCE((SELECT MAX(id) + 1 FROM fieldkit.{table_name}), 1), false);`

## Danh Sách Sequences Chính

### 1. User & Authentication
- **`user_id_seq`** - Bảng `fieldkit.user`
- **`validation_token`** - Không có sequence (token là PRIMARY KEY)
- **`refresh_token`** - Không có sequence (token là PRIMARY KEY)
- **`invite_token`** - Không có sequence (token là PRIMARY KEY)
- **`recovery_token`** - Không có sequence (token là PRIMARY KEY)

### 2. Project & Team
- **`project_id_seq`** - Bảng `fieldkit.project`
- **`project_user`** - Không có sequence (composite PRIMARY KEY)
- **`project_invite_id_seq`** - Bảng `fieldkit.project_invite`
- **`project_station_id_seq`** - Bảng `fieldkit.project_station`
- **`expedition_id_seq`** - Bảng `fieldkit.expedition`
- **`team_id_seq`** - Bảng `fieldkit.team`
- **`team_user`** - Không có sequence (composite PRIMARY KEY)

### 3. Station
- **`station_id_seq`** - Bảng `fieldkit.station` ⭐ QUAN TRỌNG
- **`station_log_id_seq`** - Bảng `fieldkit.station_log`
- **`station_model_id_seq`** - Bảng `fieldkit.station_model`
- **`station_module_id_seq`** - Bảng `fieldkit.station_module`
- **`station_reading_id_seq`** - Bảng `fieldkit.station_reading`
- **`station_configuration_id_seq`** - Bảng `fieldkit.station_configuration`
- **`station_deployed`** - Không có sequence (composite PRIMARY KEY)
- **`station_ingestion`** - Không có sequence (composite PRIMARY KEY)
- **`station_activity_id_seq`** - Bảng `fieldkit.station_activity`
- **`station_interestingness_id_seq`** - Bảng `fieldkit.station_interestingness`

### 4. Ingestion & Data
- **`ingestion_id_seq`** - Bảng `fieldkit.ingestion` ⭐ QUAN TRỌNG
- **`provision_id_seq`** - Bảng `fieldkit.provision` ⭐ QUAN TRỌNG
- **`meta_record_id_seq`** - Bảng `fieldkit.meta_record` ⭐ QUAN TRỌNG
- **`data_record_id_seq`** - Bảng `fieldkit.data_record` ⭐ QUAN TRỌNG
- **`ingestion_queue_id_seq`** - Bảng `fieldkit.ingestion_queue`

### 5. Metadata
- **`module_meta_id_seq`** - Bảng `fieldkit.module_meta` ⭐ QUAN TRỌNG (đã được reset trong migration)
- **`sensor_meta_id_seq`** - Bảng `fieldkit.sensor_meta` ⭐ QUAN TRỌNG (đã được reset trong migration)
- **`record_range_meta_id_seq`** - Bảng `fieldkit.record_range_meta`

### 6. Aggregated Data
- **`aggregated_sensor_id_seq`** - Bảng `fieldkit.aggregated_sensor`
- **`aggregated_10s_id_seq`** - Bảng `fieldkit.aggregated_10s`
- **`aggregated_1m_id_seq`** - Bảng `fieldkit.aggregated_1m`
- **`aggregated_10m_id_seq`** - Bảng `fieldkit.aggregated_10m`
- **`aggregated_30m_id_seq`** - Bảng `fieldkit.aggregated_30m`
- **`aggregated_1h_id_seq`** - Bảng `fieldkit.aggregated_1h`
- **`aggregated_6h_id_seq`** - Bảng `fieldkit.aggregated_6h`
- **`aggregated_12h_id_seq`** - Bảng `fieldkit.aggregated_12h`
- **`aggregated_24h_id_seq`** - Bảng `fieldkit.aggregated_24h`
- **`aggregated_bymod_10s_id_seq`** - Bảng `fieldkit.aggregated_bymod_10s`
- **`aggregated_bymod_1m_id_seq`** - Bảng `fieldkit.aggregated_bymod_1m`
- **`aggregated_bymod_10m_id_seq`** - Bảng `fieldkit.aggregated_bymod_10m`
- **`aggregated_bymod_30m_id_seq`** - Bảng `fieldkit.aggregated_bymod_30m`
- **`aggregated_bymod_1h_id_seq`** - Bảng `fieldkit.aggregated_bymod_1h`
- **`aggregated_bymod_6h_id_seq`** - Bảng `fieldkit.aggregated_bymod_6h`
- **`aggregated_bymod_12h_id_seq`** - Bảng `fieldkit.aggregated_bymod_12h`
- **`aggregated_bymod_24h_id_seq`** - Bảng `fieldkit.aggregated_bymod_24h`

### 7. Module & Sensor
- **`module_sensor_id_seq`** - Bảng `fieldkit.module_sensor`
- **`sensor_data_dirty_id_seq`** - Bảng `fieldkit.sensor_data_dirty`

### 8. Notes & Media
- **`field_note_category_id_seq`** - Bảng `fieldkit.field_note_category`
- **`field_note_media_id_seq`** - Bảng `fieldkit.field_note_media`
- **`field_note_id_seq`** - Bảng `fieldkit.field_note`
- **`notes_media_id_seq`** - Bảng `fieldkit.notes_media`
- **`notes_id_seq`** - Bảng `fieldkit.notes`
- **`notes_media_link`** - Không có sequence (composite PRIMARY KEY)
- **`station_note_id_seq`** - Bảng `fieldkit.station_note`

### 9. Social & Activity
- **`project_follower_id_seq`** - Bảng `fieldkit.project_follower`
- **`project_activity_id_seq`** - Bảng `fieldkit.project_activity`
- **`project_update`** - Không có sequence (composite PRIMARY KEY)
- **`project_station_activity`** - Không có sequence (composite PRIMARY KEY)

### 10. Discussion
- **`discussion_post_id_seq`** - Bảng `fieldkit.discussion_post`

### 11. Notifications
- **`notification_id_seq`** - Bảng `fieldkit.notification`

### 12. Exports
- **`data_export_id_seq`** - Bảng `fieldkit.data_export`

### 13. Jobs & Queue
- **`que_jobs_job_id_seq`** - Bảng `fieldkit.que_jobs` (BIGSERIAL)
- **`sagas`** - Không có sequence (composite PRIMARY KEY)

### 14. Other
- **`schema_id_seq`** - Bảng `fieldkit.schema`
- **`source_id_seq`** - Bảng `fieldkit.source`
- **`source_token_id_seq`** - Bảng `fieldkit.source_token`
- **`firmware_id_seq`** - Bảng `fieldkit.firmware`
- **`device_firmware_id_seq`** - Bảng `fieldkit.device_firmware`
- **`device_stream_id_seq`** - Bảng `fieldkit.device_stream`
- **`device_stream_location_id_seq`** - Bảng `fieldkit.device_stream_location`
- **`device_notes_id_seq`** - Bảng `fieldkit.device_notes`
- **`device_schema_id_seq`** - Bảng `fieldkit.device_schema`
- **`device_location_id_seq`** - Bảng `fieldkit.device_location`
- **`archive_history_id_seq`** - Bảng `fieldkit.archive_history`
- **`ttn_schema_id_seq`** - Bảng `fieldkit.ttn_schema`
- **`ttn_messages_id_seq`** - Bảng `fieldkit.ttn_messages`
- **`bookmarks_id_seq`** - Bảng `fieldkit.bookmarks`
- **`project_attribute_id_seq`** - Bảng `fieldkit.project_attribute`
- **`station_project_attribute_id_seq`** - Bảng `fieldkit.station_project_attribute`
- **`associated_station`** - Không có sequence (composite PRIMARY KEY)
- **`data_event_id_seq`** - Bảng `fieldkit.data_event`
- **`moderator_id_seq`** - Bảng `fieldkit.moderator`
- **`moderation_request_id_seq`** - Bảng `moderation_request`

## Cách Sử Dụng trong Code

### 1. INSERT với ID tự động (Khuyến nghị)
```sql
INSERT INTO fieldkit.station (name, device_id, owner_id, model_id, created_at, updated_at, location)
VALUES (:name, :device_id, :owner_id, :model_id, :created_at, :updated_at, ST_SetSRID(ST_GeomFromText(:location), 4326))
RETURNING id;
```

### 2. Đảm bảo ID = 0 trước khi INSERT
```go
station := &data.Station{
    // ... các field khác
}
station.ID = 0  // Đảm bảo ID = 0 để PostgreSQL tự động dùng nextval
```

### 3. Reset Sequence (nếu cần)
```sql
SELECT setval('station_id_seq', COALESCE((SELECT MAX(id) + 1 FROM fieldkit.station), 1), false);
```

## Lưu Ý Quan Trọng

1. **KHÔNG BAO GIỜ** set ID thủ công khi INSERT, để PostgreSQL tự động dùng sequence
2. **KHÔNG BAO GIỜ** dùng `ON CONFLICT` với ID, vì ID luôn unique
3. Nếu cần reset sequence sau khi import dữ liệu, sử dụng pattern trong `20220614145834_fix_meta_pkeys.up.sql`
4. Các bảng có composite PRIMARY KEY không có sequence riêng cho ID

## Migration Đặc Biệt

File `20220614145834_fix_meta_pkeys.up.sql` đã reset sequence cho:
- `sensor_meta_id_seq`
- `module_meta_id_seq`

Pattern này nên được sử dụng nếu cần reset sequence cho các bảng khác.

