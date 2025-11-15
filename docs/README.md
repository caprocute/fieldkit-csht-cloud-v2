# FieldKit Engineering

Tài liệu này tập hợp các định nghĩa và thông tin liên quan đến quy trình để team có thể tham khảo dễ dàng.

## Cấu trúc Repository

Repository này là một monorepo chứa toàn bộ mã nguồn của hệ thống FieldKit, bao gồm:

```
gitlab-fieldkit/
├── app/                    # Ứng dụng mobile (Flutter/Dart)
├── cloud/                  # Backend server và portal web
├── firmware/               # Firmware cho các stations
├── app-protocol/           # Protocol definitions cho ứng dụng
├── data-protocol/          # Protocol definitions cho dữ liệu
├── rustfk/                 # Thư viện Rust
├── fkc/                    # Go client library
├── phylum/                 # Thư viện C++
├── caldor/                 # Dart package
├── distance-test-module/    # Module test khoảng cách
├── water-test-module/      # Module test nước
├── weather-test-module/    # Module test thời tiết
├── swiss-army/             # Utility scripts
├── bin/                    # Binary utilities
└── docs/                   # Tài liệu
```

## Các Module và Chức năng

### 1. `app/` - Ứng dụng Mobile

**Công nghệ:** Flutter/Dart, Rust, SQLite

**Chức năng:**
- Ứng dụng mobile cho iOS và Android
- Giao diện người dùng được xây dựng bằng Flutter
- Quản lý dữ liệu và đồng bộ với stations
- Tương tác với Web Portal API
- Lưu trữ dữ liệu cục bộ bằng SQLite
- Tích hợp Rust code thông qua flutter_rust_bridge

**Cấu trúc:**
- `lib/` - Mã nguồn Dart chính
- `rust/` - Mã nguồn Rust cho data layer
- `android/`, `ios/` - Platform-specific code
- `flows/` - Flow definitions
- `resources/` - Tài nguyên (hình ảnh, PDFs)

### 2. `cloud/` - Backend và Portal

**Công nghệ:** Go (Golang), Vue.js/TypeScript, PostgreSQL, TimescaleDB

**Chức năng:**
- **Server (`cloud/server/`)**: Backend REST API monolith
  - Xử lý authentication và authorization
  - Quản lý stations và dữ liệu
  - API endpoints cho mobile app và portal
  - Tích hợp với S3 cho object storage
  - Xử lý ingestion queue cho dữ liệu từ stations
  
- **Portal (`cloud/portal/`)**: Single-page application (SPA)
  - Giao diện web để quản lý stations
  - Hiển thị và phân tích dữ liệu
  - Quản lý projects và users
  
- **Charting (`cloud/charting/`)**: Service cho biểu đồ
  - Tạo và hiển thị biểu đồ dữ liệu
  - Visualization services

- **Migrations (`cloud/migrations/`)**: Database migrations
  - Schema changes cho PostgreSQL
  - TimescaleDB setup và configuration

**Các binary tools trong `cloud/server/cmd/`:**
- `server` - Main API server
- `ingester` - Xử lý ingestion queue
- `fktool` - Command-line tool
- `fkdata` - Data manipulation tool
- `sanitizer` - Sanitize database
- `webhook` - Webhook handler
- `merger` - Data merger
- `debug_station` - Debug station tool
- `check_sensors` - Kiểm tra sensors

### 3. `firmware/` - Firmware cho Stations

**Công nghệ:** C++, CMake, ARM Cortex-M

**Chức năng:**
- Firmware cho các FieldKit stations
- Hỗ trợ nhiều board targets:
  - `samd51` - Main station board
  - `samd51-fkuw` - Underwater variant
  - `samd09` - Module board
  - `amd64` - Hosted tests
- Quản lý sensors và modules
- WiFi connectivity
- Data logging và storage
- Power management

**Cấu trúc:**
- `fk/` - Core firmware code
- `modules/` - Sensor modules
- `bootloader/` - Bootloader code
- `tools/` - Build và utility scripts
- `tests/` - Unit tests
- `third-party/` - Dependencies

### 4. `app-protocol/` - App Protocol Definitions

**Chức năng:**
- Định nghĩa protocol buffer cho giao tiếp giữa app và stations
- Generate code cho nhiều ngôn ngữ (Go, Dart, Python, Swift, JavaScript)
- File chính: `fk-app.proto`

### 5. `data-protocol/` - Data Protocol Definitions

**Chức năng:**
- Định nghĩa protocol buffer cho dữ liệu sensors
- Format chuẩn cho dữ liệu từ stations
- File chính: `fk-data.proto`

### 6. `rustfk/` - Rust Libraries

**Chức năng:**
- Thư viện Rust cho data management
- Store và model definitions
- Protocol handling
- CLI tools

### 7. `fkc/` - Go Client Library

**Chức năng:**
- Go library để tương tác với FieldKit devices
- Device communication
- Protocol decoding
- Utilities

### 8. `phylum/` - C++ Library

**Chức năng:**
- Thư viện C++ cho signal processing
- Audio và sensor data analysis
- CMake-based build system

### 9. `caldor/` - Dart Package

**Chức năng:**
- Dart package cho các utilities
- Shared code cho Flutter app

### 10. Test Modules

- `distance-test-module/` - Module test cho distance sensors
- `water-test-module/` - Module test cho water quality sensors  
- `weather-test-module/` - Module test cho weather sensors

### 11. `swiss-army/` - Utility Scripts

**Chức năng:**
- Các script tiện ích đa năng
- `parse-logs.py` - Parse và analyze logs

## Scripts và Vị trí

### Cloud Scripts (`cloud/`)

#### Build và Development
- **`build.sh`** - Build Docker containers cho server và portal
  - Build node-base image
  - Build server và portal images
  - Tạo final container với tất cả assets
  - Generate static.env với version info

- **`run-server.sh`** - Chạy development server
  - Load environment variables từ .env
  - Setup database connections
  - Build và chạy server binary
  - Port mặc định: 8080

- **`run-portal.sh`** - Chạy development portal
  - Chạy Vue.js development server
  - Hot reload cho development

- **`run-charting.sh`** - Chạy charting service
  - Chạy charting server với nodemon
  - Auto-reload khi có thay đổi

#### Database Tools (`cloud/tools/`)
- **`load-db.sh`** - Load database từ SQL file
  - Drop và recreate database
  - Setup PostGIS và TimescaleDB extensions
  - Load SQL file (hỗ trợ .sql, .bz2, .xz)
  - Chạy migrations sau khi load

- **`load-sensor-data.sh`** - Load sensor data vào database
  - Load SQL file vào database fk
  - Hỗ trợ compressed files (.bz2, .xz)

- **`mkm.sh`** - Make migrations tool
- **`wait-for-site.sh`** - Wait for site to be ready
- **`ecs-logs.sh`** - ECS logs utility

#### Server Scripts (`cloud/server/scripts/`)
- **`get_token.sh`** - Lấy authentication token
- **`setup_test_data.sh`** - Setup test data

### Firmware Scripts (`firmware/tools/`)

- **`package.sh`** - Package firmware build
  - Tạo firmware package với bootloader và firmware binaries
  - Include flash tools và WiFi driver binaries
  - Tạo ZIP archive

- **`package-weather.sh`** - Package weather module firmware

- **`update-strings.sh`** - Update string resources

- **`battery.py`** - Battery analysis tool
- **`power-analysis.py`** - Power consumption analysis
- **`power-log.py`** - Power logging
- **`stack-usage.py`** - Analyze stack usage
- **`mem.py`** - Memory analysis
- **`names.py`** - Name utilities
- **`symbols.py`** - Symbol analysis
- **`send-udp.py`** - Send UDP packets
- **`write_test_packets.py`** - Generate test packets

### Root Level Scripts

- **`bin/check_sensors`** - Check sensors utility

### Makefiles

- **`cloud/Makefile`** - Build targets cho cloud
  - `make server` - Build server binary
  - `make portal` - Build portal
  - `make binaries` - Build tất cả binaries
  - `make gotests` - Run Go tests
  - `make jstests` - Run JavaScript tests
  - `make migrate-up` - Run database migrations

- **`firmware/Makefile`** - Build targets cho firmware
  - `make samd51` - Build cho SAMD51 board
  - `make samd51-fkuw` - Build underwater variant
  - `make samd09` - Build cho SAMD09 module
  - `make amd64` - Build hosted tests
  - `make test` - Run tests
  - `make package` - Package firmware

## Definitions

Để chạy project này, bạn cần thêm các biến môi trường sau vào file `.env`:

### `FK`

Viết tắt phổ biến của FieldKit, đặc biệt trong source code.

### `NS, NS8, NS#`

Viết tắt của NativeScript và các phiên bản chính. NativeScript là framework được sử dụng để build app cho phép viết code nhắm tới cả hai platform (iOS / Android).

### `Repository, Repo`

Thường đề cập đến "Source Repository" hoặc "Git Repository" (cả hai đều giống nhau).

### `Branch`

Hệ thống version control Git theo dõi các thay đổi source code và files bằng cách tập hợp các thay đổi tương tự vào các branches. Một số branches tồn tại lâu dài và một số xuất hiện và biến mất khi cần. Thông thường, các thay đổi từ một branch sẽ được "Merged" vào các branches khác.

### `Merge`

Quá trình lấy hai branches và merge các thay đổi của một branch vào branch kia.

### `develop`

Nơi chứa phiên bản phát triển đang hoạt động của một deployable/artifact cụ thể. Đây là nơi các thay đổi được đưa vào đầu tiên để có thể được test. Thông thường đây cũng là phiên bản mà QA đang test và là phiên bản mà mọi người quan tâm nhất khi download từ [distribution site](https://code.conservify.org/distribution).

### `main`

Main chứa phiên bản production hoặc release cập nhật của artifact/deployable cụ thể đó.

### `feature branch`

Đôi khi một feature sẽ mất nhiều thời gian hơn hoặc cần những thay đổi đáng kể để hoàn thành và trong những tình huống đó chúng ta sẽ tạo một branch riêng cho những thay đổi đó. Cuối cùng branch này sẽ được merge vào `develop`.

## Repositories

Tất cả source repositories của chúng ta được host trên GitHub và có thể xem công khai.
Hầu hết được host dưới tổ chức [FieldKit](https://github.com/fieldkit) và một số được host dưới tổ chức [Conservify](https://github.com/conservify).

Chúng ta tuân theo một [Git branching model](https://nvie.com/posts/a-successful-git-branching-model) rất nghiêm ngặt, điều này chủ yếu quan trọng cho firmware và vì vậy dễ dàng hơn khi tuân theo cùng một quy trình ở mọi nơi. Nếu bạn tò mò, đây là [mô tả đầy đủ](https://nvie.com/posts/a-successful-git-branching-model/) nếu tóm tắt ở đây chưa đủ:

Đây là [một tutorial khác](https://medium.com/crowdbotics/a-dead-simple-intro-to-github-for-the-non-technical-f9d56410a856) về các khái niệm Git chung được cho là ít kỹ thuật hơn.

### https://github.com/fieldkit/mobile

Phần lớn ứng dụng mobile. Có một số repositories chứa các thư viện hỗ trợ cũng được bao gồm nhưng tất cả application releases được tạo từ repository này.

### https://github.com/fieldkit/cloud

Portal và backend code. Lưu ý: Đây chỉ là portal và backend cho portal, code cho wordpress site nằm trong một repository riêng.

### https://github.com/fieldkit/firmware

Firmware cho các stations.

## Versions

Các phiên bản của chúng ta có thể hơi phức tạp và đây là breakdown về những gì đang xảy ra với chúng. Đầu tiên, phần lớn độ phức tạp ở đó để hỗ trợ phát triển và không nhất thiết hữu ích cho production releases.

Hãy bắt đầu với một phiên bản đơn giản, lấy trực tiếp từ portal:

`0.2.1-main.7-12d43e85`

Mỗi phiên bản được cấu thành từ nhiều phần nhỏ hơn:

### `0.2.1`

Đây là major, minor và patch version cho artifact này. Chúng hoạt động như các số phiên bản bình thường mà chúng ta quen thuộc và thường là tất cả những gì end users cần cung cấp cho chúng ta để biết họ đang ở phiên bản nào.

### `main`

Tiếp theo là repository branch mà build này đến từ đó. Đối với end-users, điều này thường sẽ là `main` vì đó là branch mà chúng ta thực hiện tất cả các public releases. Tuy nhiên, trong nội bộ, sẽ phổ biến khi thấy các giá trị khác ở đây. Phổ biến nhất, xa nhất, sẽ là `develop` vì đó là branch mà tất cả công việc đang hoạt động diễn ra. Có một số tình huống trong nội bộ chúng ta sẽ thấy các branches khác ở đây, cụ thể là feature branches. Mặc dù điều này sẽ hiếm vì chúng ta muốn test mọi thứ trong `develop` khi có thể.

### `7`

Đây là pre-release version và được gán bởi Jenkins. Đây là nơi build number cũ được migrate đến và sẽ bắt đầu từ 0 cho mỗi branch và tăng lên mỗi build. Nó chỉ ở đây để dễ dàng phân biệt sự khác biệt giữa hai phiên bản tiếp theo trên một `feature` branch hoặc trên `develop` vì major, minor và patch versions chỉ thay đổi khi chúng ta thực hiện release. Số lớn hơn được build gần đây hơn.

### `12d43e85`

Đây là Git hash của branch tại thời điểm build. Cuối cùng điều này cực kỳ cụ thể và duy nhất. Chỉ với trường này thôi chúng ta có thể tìm thấy chính xác thời điểm trong repository đã được phân phối.

Dưới đây là một số ví dụ về phiên bản và mô tả của chúng:

`0.1.1-develop-34-ecf856`

Build đơn giản từ develop branch, vì vậy chỉ có thể nhìn thấy trong nội bộ.

`0.1.2-main-3-56adef3`

Đây là public release và đến sau phiên bản ví dụ trước đó (`0.1.1` vs `0.1.2`) Không phải là thay đổi đáng kể, mặc dù vì chỉ patch version được tăng.

`0.2.1-zeus-3-8b557d20`

Chắc chắn là build nội bộ, trong trường hợp này từ `feature/zeus` branch. Nó mới hơn release trước đó, mặc dù vì `0.2.1` mới hơn `0.1.2`.

`0.2.1-develop-500-8b557d20`

Một develop build của cùng major/minor/patch version. Điều thú vị về cái này là git hashes giống hệt nhau, có nghĩa là các builds này giống hệt nhau. Sẽ thường xảy ra sau một merge đơn giản.

## Submitting Bugs

Hệ sinh thái của chúng ta được tạo thành từ nhiều phần làm việc cùng nhau và vì vậy việc xác định vấn đề nằm ở đâu có thể là một nghệ thuật. Không bao giờ tổn hại khi thu thập tất cả thông tin bạn có thể, đặc biệt khi một bug mới/lạ.

Ngoài việc thu thập thông tin bên dưới, việc bao gồm mô tả về những gì bạn đang làm và những gì bạn mong đợi sẽ xảy ra là cực kỳ hữu ích. Nếu bạn có thể reproduce vấn đề, bao gồm các bước đó sẽ hầu như luôn đẩy nhanh quá trình.

### Hardware / Firmware

Đối với các vấn đề liên quan trực tiếp đến hành vi của hardware hoặc thu thập dữ liệu, v.v... các logs được ghi vào SD card thường là nơi đầu tiên cần đến. Quy trình ưa thích để submit những logs đó liên quan đến việc tạo ZIP archive, tốt nhất sử dụng các hướng dẫn này:

1. Tạo một folder mới trong SD drive: [station name]_yyyy_mm_dd_HHMM
2. Copy TẤT CẢ files vào folder mới đó
3. Zip folder
4. Gửi nó!

### App

App luôn logging ở background và các logs đó có thể được submit như diagnostics từ app bằng cách điều hướng đến menu `Developer`. Điều này có sẵn từ icon `Application Settings` ở góc dưới bên phải của bottom navigation.

### Portal

Chúng ta chưa cài đặt cơ chế chính thức để thu thập client-side logs hoặc thông tin diagnostics khác. Nói chung screenshots rất hữu ích ở đây. Hãy cố gắng bao gồm browser URL trong chúng.

## Hardware Details

I2C: RTC, INA219 Bat, INA219 Sol, Backplane MCP, Backplane LED, Backplane TCA, Core temp gauge. Module EEPROM.

## Station Interaction

### Debug Mode

Nút ngoài cùng bên phải.

### Emergency Rescue

Nút ngoài cùng bên trái.

### IRQs

- SysTick
- SVC
- PendSV
- WDT
- EIC-11 Wifi
- EIC-12 Battery
