# Troubleshooting AWS Profile Error

## Lỗi: "The config profile (fieldkit) could not be found"

### Nguyên nhân
AWS CLI không tìm thấy profile "fieldkit" trong file cấu hình (`~/.aws/config` và `~/.aws/credentials`).

### Giải pháp

#### Option 1: Không dùng AWS_PROFILE (Khuyến nghị)
Nếu bạn đã cấu hình default credentials, chỉ cần bỏ qua `AWS_PROFILE`:

```bash
# Không set AWS_PROFILE
export AWS_ACCOUNT_ID="585768163363"
export AWS_REGION="ap-southeast-1"
# Không cần: export AWS_PROFILE="fieldkit"

./deployment/build-and-push.sh v1.0.0 staging
```

#### Option 2: Tạo AWS Profile
Nếu muốn dùng profile riêng:

```bash
# Tạo profile mới
aws configure --profile fieldkit

# Nhập thông tin:
# - AWS Access Key ID: [your-access-key]
# - AWS Secret Access Key: [your-secret-key]
# - Default region name: ap-southeast-1
# - Default output format: json

# Sau đó sử dụng
export AWS_PROFILE="fieldkit"
./deployment/build-and-push.sh v1.0.0 staging
```

#### Option 3: Kiểm tra profile có tồn tại
```bash
# List tất cả profiles
aws configure list-profiles

# Kiểm tra profile cụ thể
aws configure list --profile fieldkit

# Nếu profile không tồn tại, bạn sẽ thấy lỗi
```

### Script sẽ tự động xử lý
Các deployment scripts đã được cập nhật để:
- Tự động kiểm tra profile có tồn tại không
- Nếu không tồn tại, sẽ cảnh báo và sử dụng default credentials
- Script sẽ tiếp tục chạy bình thường

### Kiểm tra AWS Credentials
```bash
# Kiểm tra credentials hiện tại (default)
aws sts get-caller-identity

# Kiểm tra với profile cụ thể
aws sts get-caller-identity --profile fieldkit

# Nếu không có credentials, sẽ thấy lỗi:
# "Unable to locate credentials"
```

### Cấu trúc AWS Config Files

**~/.aws/config:**
```ini
[default]
region = ap-southeast-1
output = json

[profile fieldkit]
region = ap-southeast-1
output = json
```

**~/.aws/credentials:**
```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY

[fieldkit]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

### Quick Fix
```bash
# Unset AWS_PROFILE nếu không cần
unset AWS_PROFILE

# Hoặc xóa từ .bashrc/.zshrc nếu đã set ở đó
# Sau đó chạy lại script
./deployment/build-and-push.sh v1.0.0 staging
```

