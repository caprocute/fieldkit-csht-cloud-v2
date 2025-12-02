# Hướng dẫn sửa lỗi CORS

## Vấn đề
Khi gọi backend từ IP khác (ví dụ: ALB domain, IP address), gặp lỗi CORS vì server chỉ cho phép các origin đã được định nghĩa trong design file.

## Giải pháp

### Cách 1: Regenerate code (Khuyến nghị)

1. Cài đặt goa (nếu chưa có):
```bash
go install goa.design/goa/v3/cmd/goa@latest
```

2. Regenerate code từ design file:
```bash
cd cloud
make generate
```

Hoặc:
```bash
cd cloud/server/api
$(GOPATH)/bin/goa gen gitlab.com/fieldkit/cloud/server/api/design
```

3. Rebuild server:
```bash
cd cloud
make server
```

### Cách 2: Sửa tạm thời trong generated code

Đã sửa file `cloud/server/api/gen/http/user/server/server.go` để thêm pattern cho:
- IP addresses (ví dụ: `http://1.2.3.4:8080`)
- AWS ELB/ALB domains (ví dụ: `http://xxx.elb.amazonaws.com`)
- AWS ALB trong ap-southeast-1

Nếu cần sửa các service khác, tìm hàm `handle*Origin` trong các file:
- `cloud/server/api/gen/http/project/server/server.go`
- `cloud/server/api/gen/http/station/server/server.go`
- Và các service khác trong `cloud/server/api/gen/http/*/server/server.go`

Thêm các pattern tương tự như đã làm trong `user/server.go`.

## Lưu ý

- Code trong thư mục `gen/` là generated code, sẽ bị ghi đè khi regenerate
- Nên regenerate code sau khi sửa `design.go` để đảm bảo consistency
- Các pattern đã thêm vào `design.go`:
  - IP addresses với port: `/\\d+\\.\\d+\\.\\d+\\.\\d+:\\d+/`
  - AWS ELB/ALB domains: `/(.+[.])?elb\\.amazonaws\\.com(:\\d+)?/`
  - AWS ALB ap-southeast-1: `/(.+[.])?ap-southeast-1\\.elb\\.amazonaws\\.com(:\\d+)?/`

## Test

Sau khi sửa, test bằng cách gọi API từ browser console hoặc curl:

```bash
curl -X OPTIONS http://your-alb-domain/users \
  -H "Origin: http://your-frontend-domain" \
  -H "Access-Control-Request-Method: POST" \
  -v
```

Kiểm tra response có header `Access-Control-Allow-Origin` không.

