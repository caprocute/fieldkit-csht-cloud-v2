# Troubleshooting ECR 403 Forbidden Error

Lỗi `403 Forbidden` khi push Docker images lên ECR thường do các nguyên nhân sau:

## 1. Thiếu IAM Permissions

Đảm bảo IAM user/role có đủ các quyền sau. **Quan trọng**: Các quyền cần được chia thành nhiều statements với Resource scope đúng:

### Statement 1: GetAuthorizationToken (phải có Resource: *)
```json
{
  "Effect": "Allow",
  "Action": ["ecr:GetAuthorizationToken"],
  "Resource": "*"
}
```

### Statement 2: Repository Management
```json
{
  "Effect": "Allow",
  "Action": [
    "ecr:CreateRepository",
    "ecr:DescribeRepositories",
    "ecr:ListImages",
    "ecr:DescribeImages"
  ],
  "Resource": "arn:aws:ecr:ap-southeast-1:ACCOUNT_ID:repository/hieuhk_fieldkit/*"
}
```

### Statement 3: Image Push/Pull (quan trọng nhất cho push)
```json
{
  "Effect": "Allow",
  "Action": [
    "ecr:BatchGetImage",
    "ecr:GetDownloadUrlForLayer",
    "ecr:BatchCheckLayerAvailability",
    "ecr:PutImage",
    "ecr:InitiateLayerUpload",
    "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload"
  ],
  "Resource": "arn:aws:ecr:ap-southeast-1:ACCOUNT_ID:repository/hieuhk_fieldkit/*"
}
```

**Lưu ý**: Không gộp tất cả actions vào một statement với Resource: "*" vì có thể gây vấn đề với một số permissions.

Đảm bảo IAM user/role có đủ các quyền sau:

```json
{
  "Action": [
    "ecr:GetAuthorizationToken",
    "ecr:PutImage",
    "ecr:InitiateLayerUpload",
    "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload",
    "ecr:BatchCheckLayerAvailability"
  ]
}
```

**Fix:**
```bash
# Kiểm tra policy hiện tại
aws iam list-attached-user-policies --user-name YOUR_USERNAME

# Setup policy đầy đủ
./deployment/setup-iam-policy.sh YOUR_USERNAME USER
```

## 2. Repository ARN không khớp với Policy

Kiểm tra Resource ARN trong IAM policy phải khớp với repository name:

```json
{
  "Resource": [
    "arn:aws:ecr:ap-southeast-1:ACCOUNT_ID:repository/hieuhk_fieldkit/*"
  ]
}
```

**Fix:**
- Đảm bảo ACCOUNT_ID đúng
- Đảm bảo repository name pattern khớp (`hieuhk_fieldkit/*`)

## 3. Docker Authentication Token hết hạn

ECR authentication token chỉ có hiệu lực 12 giờ.

**Fix:**
```bash
# Re-authenticate
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin \
  ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com

# Kiểm tra đăng nhập thành công
docker pull ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/hieuhk_fieldkit/server:latest
```

## 4. Repository chưa tồn tại

**Fix:**
```bash
# Tạo repository thủ công
aws ecr create-repository \
  --repository-name hieuhk_fieldkit/server \
  --region ap-southeast-1 \
  --image-scanning-configuration scanOnPush=true
```

## 5. Kiểm tra Permissions

```bash
# Test ECR permissions
aws ecr describe-repositories --region ap-southeast-1
aws ecr get-authorization-token --region ap-southeast-1

# Test push với một image nhỏ
docker pull alpine:latest
docker tag alpine:latest ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/hieuhk_fieldkit/test:latest
docker push ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/hieuhk_fieldkit/test:latest
```

## 6. Kiểm tra CloudTrail Logs

Nếu vẫn gặp lỗi, kiểm tra CloudTrail để xem action nào bị deny:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=YOUR_USERNAME \
  --max-results 10 \
  --region ap-southeast-1
```

## 7. Test Permissions Chi Tiết

Chạy script test để kiểm tra từng permission:

```bash
./deployment/test-ecr-permissions.sh
```

Script này sẽ test:
- `ecr:GetAuthorizationToken`
- `ecr:DescribeRepositories`
- `ecr:BatchCheckLayerAvailability`
- `ecr:ListImages`
- Docker login
- Push capability

## 8. Common Issues

### Issue: "AccessDenied" khi push
- **Nguyên nhân**: Thiếu `ecr:PutImage` hoặc các quyền upload layer
- **Fix**: Thêm vào IAM policy:
  ```json
  "ecr:PutImage",
  "ecr:InitiateLayerUpload",
  "ecr:UploadLayerPart",
  "ecr:CompleteLayerUpload"
  ```

### Issue: "RepositoryNotFoundException"
- **Nguyên nhân**: Repository chưa được tạo
- **Fix**: Chạy `build-and-push.sh` sẽ tự động tạo, hoặc tạo thủ công

### Issue: "UnauthorizedOperation"
- **Nguyên nhân**: AWS credentials không đúng hoặc không có quyền
- **Fix**: 
  ```bash
  aws sts get-caller-identity
  # Kiểm tra account ID và user/role
  ```

## Quick Fix Checklist

1. ✅ Kiểm tra AWS credentials: `aws sts get-caller-identity`
2. ✅ Kiểm tra IAM permissions: `./deployment/check-prerequisites.sh`
3. ✅ Re-authenticate Docker: `aws ecr get-login-password ...`
4. ✅ Đảm bảo repository tồn tại: `aws ecr describe-repositories`
5. ✅ Kiểm tra policy ARN khớp với repository name
6. ✅ Thử push một image nhỏ để test

## Debug Commands

```bash
# Xem thông tin chi tiết về lỗi
docker push ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/hieuhk_fieldkit/server:latest 2>&1

# Kiểm tra IAM policy
aws iam get-user-policy --user-name YOUR_USERNAME --policy-name FieldKitDeploymentPolicy

# Test từng permission
aws ecr get-authorization-token --region ap-southeast-1
aws ecr describe-repositories --repository-names hieuhk_fieldkit/server --region ap-southeast-1
```

