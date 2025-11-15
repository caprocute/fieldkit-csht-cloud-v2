# Giải Thích Bảng `ingestion_queue`

## Các Trường Trong Bảng

| Trường | Kiểu | Mô Tả |
|--------|------|-------|
| `id` | SERIAL | ID của queue record |
| `ingestion_id` | INTEGER | ID của ingestion được queue (tham chiếu đến `fieldkit.ingestion`) |
| `queued` | TIMESTAMP | Thời gian ingestion được thêm vào queue |
| `attempted` | TIMESTAMP (nullable) | Thời gian worker bắt đầu xử lý (NULL = chưa bắt đầu) |
| `completed` | TIMESTAMP (nullable) | Thời gian hoàn thành xử lý (NULL = chưa hoàn thành) |
| `total_records` | INTEGER (nullable) | Tổng số records đã xử lý thành công (NULL = có lỗi) |
| `other_errors` | INTEGER (nullable) | Số lỗi khác (1 = có lỗi, 0 = không lỗi, NULL = chưa xử lý) |
| `meta_errors` | INTEGER (nullable) | Số lỗi khi xử lý meta records |
| `data_errors` | INTEGER (nullable) | Số lỗi khi xử lý data records |

## Các Trạng Thái Xử Lý

### ✅ Thành Công (Success)
```
total_records > 0
other_errors = 0
meta_errors = 0 (hoặc NULL cho data ingestion)
data_errors = 0 (hoặc NULL cho meta ingestion)
completed IS NOT NULL
```

**Ví dụ từ dữ liệu của bạn:**
- ID 927, 926 (ingestion_id 1015 - meta): `total_records=1, other_errors=0` ✅
- ID 938, 939 (ingestion_id 1026 - meta): `total_records=1, other_errors=0` ✅

### ❌ Có Lỗi (Error)
```
total_records IS NULL
other_errors = 1
completed IS NOT NULL
```

**Ví dụ từ dữ liệu của bạn:**
- Tất cả data ingestions (1017, 1018, 1023, 1024, ...): `total_records=NULL, other_errors=1` ❌

### ⏳ Đang Xử Lý (In Progress)
```
attempted IS NOT NULL
completed IS NULL
```

### 📋 Chờ Xử Lý (Pending)
```
attempted IS NULL
completed IS NULL
```

## Phân Tích Dữ Liệu Của Bạn

### Meta Ingestions (Thành Công)
- **Ingestion ID 1015** (queue IDs: 927, 926): ✅ Thành công
- **Ingestion ID 1026** (queue IDs: 938, 939): ✅ Thành công  
- **Ingestion ID 1037** (queue IDs: 951, 950): ✅ Thành công
- **Ingestion ID 1048** (queue IDs: 963, 962): ✅ Thành công
- **Ingestion ID 1059** (queue IDs: 974, 975): ✅ Thành công

**Lưu ý:** Mỗi meta ingestion có 2 queue records (có thể do được trigger 2 lần).

### Data Ingestions (Có Lỗi)
- **Tất cả data ingestions** (1017, 1018, 1019, 1020, 1021, 1022, 1023, 1024, 1025, ...): ❌ Có lỗi

**Đặc điểm:**
- `total_records = NULL` → Không có records nào được xử lý thành công
- `other_errors = 1` → Có lỗi trong quá trình xử lý
- `attempted = NULL` → Worker có thể chưa bắt đầu xử lý, hoặc lỗi xảy ra ngay từ đầu
- `completed IS NOT NULL` → Processing đã kết thúc (với lỗi)

## Nguyên Nhân Có Thể

Từ code `ingestion_received_handler.go`, `MarkProcessedHasOtherErrors` được gọi khi:

1. **`WriteRecords` trả về error** (dòng 197-203):
   - File ingestion không tồn tại hoặc không đọc được
   - Station không tồn tại
   - Provision không tồn tại
   - Lỗi khi parse file

2. **`recordIngestionActivity` trả về error** (dòng 223-228):
   - Không tạo được `station_ingestion` record
   - Lỗi khi update station

## Cách Kiểm Tra Chi Tiết

### 1. Kiểm tra ingestion file có tồn tại không:
```sql
SELECT 
    i.id,
    i.type,
    i.url,
    i.upload_id,
    i.device_id,
    s.id AS station_id,
    s.name AS station_name
FROM fieldkit.ingestion i
LEFT JOIN fieldkit.station s ON (s.device_id = i.device_id)
WHERE i.id IN (1017, 1018, 1019, 1020, 1021)
ORDER BY i.id;
```

### 2. Kiểm tra provision có tồn tại không:
```sql
SELECT 
    i.id AS ingestion_id,
    i.device_id,
    i.generation,
    p.id AS provision_id,
    p.device_id AS provision_device_id,
    p.generation AS provision_generation
FROM fieldkit.ingestion i
LEFT JOIN fieldkit.provision p ON (
    p.device_id = i.device_id 
    AND p.generation = i.generation
)
WHERE i.id IN (1017, 1018, 1019, 1020, 1021)
ORDER BY i.id;
```

### 3. Kiểm tra station có tồn tại không:
```sql
SELECT 
    i.id AS ingestion_id,
    i.device_id,
    s.id AS station_id,
    s.name AS station_name
FROM fieldkit.ingestion i
LEFT JOIN fieldkit.station s ON (s.device_id = i.device_id)
WHERE i.id IN (1017, 1018, 1019, 1020, 1021)
ORDER BY i.id;
```

## Giải Pháp

1. **Kiểm tra logs của worker** để xem lỗi cụ thể
2. **Kiểm tra file ingestion** có tồn tại và đọc được không
3. **Kiểm tra provision** có được tạo từ meta ingestion không
4. **Trigger processing lại** bằng tool `process_meta` hoặc API

