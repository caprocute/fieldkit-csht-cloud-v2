package main

import (
	"bytes"
	"context"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"math"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/golang/protobuf/proto"
	_ "github.com/lib/pq"
	"golang.org/x/crypto/blake2b"

	"gitlab.com/fieldkit/cloud/server/common"
	"gitlab.com/fieldkit/cloud/server/common/logging"
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
	pb "gitlab.com/fieldkit/libraries/data-protocol"
)

const (
	FloodNetModuleID = 19
	// FIXED: Sử dụng giá trị từ DB (module_meta table)
	// wh.floodnet có manufacturer=0, kinds={0}
	FloodNetManufacturer    = 0x00 // 0 (từ DB: manufacturer=0)
	FloodNetModuleKind      = 0x00 // 0 (từ DB: kinds={0})
	floodNetReadingInterval = 15 * time.Minute
)

type APIClient struct {
	BaseURL string
	Token   string
	Client  *http.Client
}

type LoginResponse struct {
	Authorization string `json:"authorization"`
}

type UserResponse struct {
	ID       int32  `json:"id"`
	Name     string `json:"name"`
	Email    string `json:"email"`
	Username string `json:"username"`
}

type ProjectResponse struct {
	ID          int32  `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Goal        string `json:"goal"`
	Location    string `json:"location"`
	Tags        string `json:"tags"`
	Privacy     int32  `json:"privacy"`
}

type StationResponse struct {
	ID       int32  `json:"id"`
	Name     string `json:"name"`
	DeviceID string `json:"deviceId"`
	// Lưu thông tin location từ VietnamStations
	VietnamStation *VietnamStation `json:"-"`
}

func main() {
	var (
		apiURL     = flag.String("api", "http://localhost:8080", "API base URL")
		dbURL      = flag.String("db", "", "PostgreSQL connection URL (required for enabling user)")
		stations   = flag.Int("stations", 5, "Number of FloodNet stations to create")
		readings   = flag.Int("readings", 672, "Number of readings per station (default: 672 = 1 week with 15-minute interval)")
		project    = flag.String("project", "FloodNet Vietnam Monitoring", "Project name")
		userEmail  = flag.String("user", "floodnet@test.local", "User email")
		userName   = flag.String("name", "FloodNet Test User", "User name")
		password   = flag.String("password", "test123456", "User password")
		userExists = flag.Bool("user-exists", false, "Skip user creation, assume user already exists and login directly")
	)
	flag.Parse()

	if *dbURL == "" {
		log.Fatalf("Error: -db flag is required (needed for user enablement and station location updates)")
	}

	ctx := context.Background()
	db, err := sqlxcache.Open(ctx, "postgres", *dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Normalize API URL
	normalizedAPIURL, err := normalizeAPIURL(*apiURL)
	if err != nil {
		log.Fatalf("Invalid API URL: %v", err)
	}

	// Khởi tạo logger
	logging.Configure(false, "auto_seed")

	log.Printf("📡 Using API URL: %s", normalizedAPIURL)

	// Khởi tạo API client
	apiClient := &APIClient{
		BaseURL: normalizedAPIURL,
		Client:  &http.Client{Timeout: 30 * time.Second},
	}

	// Bước 1: Tạo user qua API (hoặc sử dụng user đã tồn tại)
	var user *UserResponse
	if *userExists {
		// Bỏ qua tạo user, giả định user đã tồn tại
		log.Println("\n📝 Step 1: Skipping user creation (user-exists flag set)...")
		log.Printf("ℹ️  Using existing user: %s", *userEmail)
		user = &UserResponse{
			Email: *userEmail,
			ID:    0, // Sẽ được cập nhật sau khi login
		}
	} else {
		log.Println("\n📝 Step 1: Creating user via API...")
		createdUser, err := createUserViaAPI(apiClient, *userEmail, *userName, *password)
		if err != nil {
			// Nếu user đã tồn tại, đăng nhập luôn
			if strings.Contains(err.Error(), "email registered") || strings.Contains(err.Error(), "user-email-registered") {
				log.Printf("ℹ️  User already exists: %s, proceeding to login...", *userEmail)
				user = &UserResponse{
					Email: *userEmail,
					ID:    0, // Sẽ được cập nhật sau khi login
				}
			} else {
				log.Fatalf("Failed to create user: %v", err)
			}
		} else {
			log.Printf("✅ Created user: %s (ID: %d)", createdUser.Email, createdUser.ID)
			user = createdUser

			// Ngay lập tức enable user và cấp quyền admin trong DB
			if db != nil {
				log.Println("\n🔐 Step 1.5: Enabling user and granting admin privileges in database...")
				if err := enableUserInDB(ctx, db, user.ID); err != nil {
					log.Printf("⚠️  Warning: Failed to enable user in database: %v", err)
					log.Printf("⚠️  User may need to be enabled manually or may already be enabled")
					log.Printf("⚠️  Continuing anyway - login may fail if user is not enabled")
				} else {
					log.Printf("✅ Enabled user and granted admin privileges: %s (ID: %d)", user.Email, user.ID)
				}
			} else {
				log.Println("\n⚠️  Warning: No database connection - cannot enable user or grant admin privileges")
				log.Printf("⚠️  User may need to be enabled manually - login may fail if user is not enabled")
			}
		}
	}

	// Bước 2: Login và lấy token (token sẽ có quyền admin nếu user vừa được enable)
	log.Println("\n🔐 Step 2: Logging in and getting token...")
	log.Printf("🔑 Attempting login with email: %s", user.Email)
	token, err := loginAndGetToken(apiClient, user.Email, *password)
	if err != nil {
		log.Fatalf("Failed to login: %v", err)
	}
	apiClient.Token = token
	log.Printf("✅ Got token: %s...", token[:20])

	// Export token ra file và environment variable
	tokenFile := ".fieldkit_token"
	if err := os.WriteFile(tokenFile, []byte(token), 0600); err != nil {
		log.Printf("⚠️  Warning: Failed to write token to file: %v", err)
	} else {
		log.Printf("💾 Token saved to: %s", tokenFile)
	}

	// Export token ra environment variable (cho shell script)
	if err := os.Setenv("FIELDKIT_TOKEN", token); err != nil {
		log.Printf("⚠️  Warning: Failed to set environment variable: %v", err)
	} else {
		log.Printf("🔧 Token exported to: FIELDKIT_TOKEN environment variable")
	}

	// Bước 3: Tạo project qua API
	log.Println("\n📁 Step 3: Creating project via API...")
	proj, err := createProjectViaAPI(apiClient, *project)
	if err != nil {
		log.Fatalf("Failed to create project: %v", err)
	}
	log.Printf("✅ Created project: %s (ID: %d)", proj.Name, proj.ID)

	// Bước 4: Tạo stations qua API
	log.Printf("\n🏭 Step 4: Creating %d FloodNet stations via API...", *stations)
	stationList, err := createFloodNetStationsViaAPI(apiClient, proj.ID, *stations, db)
	if err != nil {
		log.Fatalf("Failed to create stations: %v", err)
	}
	log.Printf("✅ Created %d stations", len(stationList))

	// Bước 5: Upload dữ liệu cho mỗi station qua API
	for i, station := range stationList {
		log.Printf("\n📊 Step 5.%d: Uploading data for station %d/%d: %s", i+1, i+1, len(stationList), station.Name)

		if err := uploadStationDataViaAPI(apiClient, station, *readings, db); err != nil {
			log.Printf("❌ Failed to upload data for station %s: %v", station.Name, err)
			continue
		}
		log.Printf("✅ Completed data upload for station: %s", station.Name)
	}

	log.Println("\n🎉 Data generation completed successfully!")
	log.Printf("📋 Summary:")
	log.Printf("   - User: %s (ID: %d)", user.Email, user.ID)
	log.Printf("   - Project: %s (ID: %d)", proj.Name, proj.ID)
	log.Printf("   - Stations: %d", len(stationList))
	log.Printf("   - Token: %s...", token[:20])
	log.Printf("\n💡 Next steps:")
	log.Printf("   - Token saved to: .fieldkit_token")
	log.Printf("   - Token exported to: FIELDKIT_TOKEN environment variable")
	log.Printf("   - Use token in other tools: export FIELDKIT_TOKEN=\"$(cat .fieldkit_token)\"")
}

// createUserViaAPI tạo user qua API POST /users
func createUserViaAPI(client *APIClient, email, name, password string) (*UserResponse, error) {
	url := fmt.Sprintf("%s/users", client.BaseURL)
	payload := map[string]interface{}{
		"name":     name,
		"email":    email,
		"password": password,
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("POST", url, bytes.NewReader(jsonData))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("create user failed: status %d, body: %s", resp.StatusCode, string(body))
	}

	var result UserResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	return &result, nil
}

// enableUserInDB enable user trong database (set valid = true và admin = true)
func enableUserInDB(ctx context.Context, db *sqlxcache.DB, userID int32) error {
	_, err := db.ExecContext(ctx, `UPDATE fieldkit.user SET valid = true, admin = true WHERE id = $1`, userID)
	return err
}

// createProjectViaAPI tạo project qua API POST /projects
func createProjectViaAPI(client *APIClient, name string) (*ProjectResponse, error) {
	url := fmt.Sprintf("%s/projects", client.BaseURL)
	payload := map[string]interface{}{
		"name":        name,
		"description": "FloodNet monitoring project for Vietnam area",
		"goal":        "Monitor flood levels in Vietnam",
		"location":    "Vietnam",
		"tags":        "floodnet,monitoring,vietnam",
		"privacy":     0, // Public
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("POST", url, bytes.NewReader(jsonData))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", client.Token))
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("create project failed: status %d, body: %s", resp.StatusCode, string(body))
	}

	var result ProjectResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	return &result, nil
}

// createFloodNetStationsViaAPI tạo stations qua API POST /stations
func createFloodNetStationsViaAPI(client *APIClient, projectID int32, count int, db *sqlxcache.DB) ([]*StationResponse, error) {
	stations := []*StationResponse{}
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	vietnamStations := GetRandomStations(count, rng)

	for i := 0; i < count; i++ {
		// Sử dụng tên địa điểm Việt Nam
		name := fmt.Sprintf("FloodNet - %s, %s", vietnamStations[i].Name, vietnamStations[i].Province)

		time.Sleep(time.Millisecond * 10)
		hasher := sha1.New()
		hasher.Write([]byte(fmt.Sprintf("floodnet-station-%d-%d-%d-%d", projectID, i, time.Now().UnixNano(), rand.Int63())))
		deviceID := hasher.Sum(nil)

		url := fmt.Sprintf("%s/stations", client.BaseURL)
		payload := map[string]interface{}{
			"name":         name,
			"deviceId":     hex.EncodeToString(deviceID),
			"locationName": fmt.Sprintf("%s, %s", vietnamStations[i].Name, vietnamStations[i].Province),
			"description":  fmt.Sprintf("Trạm FloodNet giám sát %s, %s (%s)", vietnamStations[i].Name, vietnamStations[i].Province, vietnamStations[i].Region),
		}

		jsonData, err := json.Marshal(payload)
		if err != nil {
			return nil, err
		}

		req, err := http.NewRequest("POST", url, bytes.NewReader(jsonData))
		if err != nil {
			return nil, err
		}

		req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", client.Token))
		req.Header.Set("Content-Type", "application/json")

		resp, err := client.Client.Do(req)
		if err != nil {
			return nil, err
		}

		if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
			resp.Body.Close()
			body, _ := io.ReadAll(resp.Body)
			return nil, fmt.Errorf("create station failed: status %d, body: %s", resp.StatusCode, string(body))
		}

		var station StationResponse
		if err := json.NewDecoder(resp.Body).Decode(&station); err != nil {
			resp.Body.Close()
			return nil, err
		}
		resp.Body.Close()

		// Lưu thông tin location từ VietnamStations
		station.VietnamStation = &vietnamStations[i]

		// Add station to project
		addStationURL := fmt.Sprintf("%s/projects/%d/stations/%d", client.BaseURL, projectID, station.ID)
		addReq, err := http.NewRequest("POST", addStationURL, nil)
		if err != nil {
			return nil, err
		}

		addReq.Header.Set("Authorization", fmt.Sprintf("Bearer %s", client.Token))

		addResp, err := client.Client.Do(addReq)
		if err != nil {
			return nil, err
		}
		addResp.Body.Close()

		if addResp.StatusCode != http.StatusOK && addResp.StatusCode != http.StatusNoContent {
			log.Printf("⚠️  Warning: Failed to add station %d to project %d", station.ID, projectID)
		}

		if err := updateStationLocationViaAPI(client, &station, station.VietnamStation); err != nil {
			log.Printf("⚠️  Warning: Failed to update station %d location via API: %v", station.ID, err)
		}
		if err := setStationLocationInDB(db, station.ID, station.VietnamStation); err != nil {
			log.Printf("⚠️  Warning: Failed to persist station %d location in DB: %v", station.ID, err)
		}

		stations = append(stations, &station)
	}

	return stations, nil
}

func updateStationLocationViaAPI(client *APIClient, station *StationResponse, location *VietnamStation) error {
	if client == nil || station == nil || location == nil {
		return nil
	}

	payload := map[string]interface{}{
		"name":         station.Name,
		"locationName": fmt.Sprintf("%s, %s", location.Name, location.Province),
		"description":  fmt.Sprintf("Trạm FloodNet giám sát %s, %s (%s)", location.Name, location.Province, location.Region),
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	url := fmt.Sprintf("%s/stations/%d", client.BaseURL, station.ID)
	req, err := http.NewRequest("PATCH", url, bytes.NewReader(jsonData))
	if err != nil {
		return err
	}

	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", client.Token))
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("update station location failed: status %d, body: %s", resp.StatusCode, string(body))
	}

	return nil
}

func setStationLocationInDB(db *sqlxcache.DB, stationID int32, location *VietnamStation) error {
	if db == nil || location == nil {
		return nil
	}

	ctx := context.Background()
	locationName := fmt.Sprintf("%s, %s", location.Name, location.Province)

	_, err := db.ExecContext(ctx, `
		UPDATE fieldkit.station
		SET location = ST_SetSRID(ST_MakePoint($1, $2), 4326),
			location_name = $3,
			place_other = $4,
			place_native = $5
		WHERE id = $6
	`, location.Longitude, location.Latitude, locationName, location.Name, location.Province, stationID)
	return err
}

// uploadStationDataViaAPI upload meta và data cho station qua API POST /ingestion
func uploadStationDataViaAPI(client *APIClient, station *StationResponse, numReadings int, db *sqlxcache.DB) error {
	// Decode device ID
	deviceID, err := hex.DecodeString(station.DeviceID)
	if err != nil {
		return fmt.Errorf("invalid device ID: %w", err)
	}

	if station.VietnamStation != nil {
		if err := updateStationLocationViaAPI(client, station, station.VietnamStation); err != nil {
			log.Printf("  ⚠️  Warning: Failed to update station %d location via API: %v", station.ID, err)
		}
		if err := setStationLocationInDB(db, station.ID, station.VietnamStation); err != nil {
			log.Printf("  ⚠️  Warning: Failed to persist station %d location in DB: %v", station.ID, err)
		}
	}

	// Generate generation ID - FIXED: Dùng cùng generationID cho cả meta và data ingestion
	// Không dùng timestamp để tránh tạo generationID khác nhau mỗi lần gọi
	hasher := blake2b.Sum256(append(deviceID, []byte("-floodnet-v1")...))
	generationID := hasher[:]

	// 1. Create and upload meta
	metaRecord, _, err := createFloodNetMeta(station, deviceID, generationID, 1)
	if err != nil {
		return err
	}

	metaFile := proto.NewBuffer(make([]byte, 0))
	if err := metaFile.EncodeMessage(metaRecord); err != nil {
		return fmt.Errorf("failed to encode meta: %w", err)
	}

	metaIngestion, err := client.UploadIngestion(deviceID, generationID, "meta", metaFile.Bytes())
	if err != nil {
		return fmt.Errorf("failed to upload meta: %w", err)
	}
	log.Printf("  ✅ Uploaded meta ingestion: ID=%d", metaIngestion.ID)

	// Trigger processing để tạo sensors ngay lập tức
	// Lưu ý: API này cần quyền admin, nhưng nếu không có quyền thì worker sẽ xử lý sau
	if err := client.ProcessIngestion(metaIngestion.ID); err != nil {
		// Nếu lỗi 401 (unauthorized), đây là expected behavior vì user thường không có quyền admin
		// Worker sẽ tự động xử lý ingestion sau
		if strings.Contains(err.Error(), "status 401") || strings.Contains(err.Error(), "unauthorized") {
			log.Printf("  ℹ️  Meta processing requires admin privileges (worker will process automatically)")
		} else {
			log.Printf("  ⚠️  Warning: Failed to trigger meta processing (worker will process later): %v", err)
		}
	} else {
		log.Printf("  ✅ Triggered meta processing to create sensors")
	}

	// Đợi để meta ingestion được xử lý xong (tạo meta_record trong DB)
	// Điều này quan trọng để data ingestion có thể tìm thấy meta_record khi xử lý
	log.Printf("  ⏳ Waiting for meta ingestion to be processed...")
	maxRetries := 15
	metaProcessed := false
	for retry := 0; retry < maxRetries; retry++ {
		// Kiểm tra xem meta ingestion đã được xử lý xong chưa bằng cách query DB
		if db != nil {
			var count int
			if err := db.GetContext(context.Background(), &count, `
				SELECT COUNT(*) FROM fieldkit.meta_record mr
				JOIN fieldkit.provision p ON mr.provision_id = p.id
				WHERE p.device_id = $1 AND p.generation = $2 AND mr.number = 1
			`, deviceID, generationID); err == nil && count > 0 {
				metaProcessed = true
				log.Printf("  ✅ Meta record created in database (number=1)")
				break
			}
		}

		if retry < maxRetries-1 {
			log.Printf("  ⏳ Meta record not found yet, waiting... (retry %d/%d)", retry+1, maxRetries)
			time.Sleep(2 * time.Second)
		}
	}

	if !metaProcessed {
		log.Printf("  ⚠️  Warning: Meta record may not be created yet, but proceeding with data upload")
	}

	// Kiểm tra xem sensors đã được tạo chưa bằng cách query station
	maxRetries = 10
	for retry := 0; retry < maxRetries; retry++ {
		// Query station để kiểm tra sensors
		stationURL := fmt.Sprintf("%s/stations/%d", client.BaseURL, station.ID)
		req, err := http.NewRequest("GET", stationURL, nil)
		if err == nil {
			req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", client.Token))
			resp, err := client.Client.Do(req)
			if err == nil && resp.StatusCode == http.StatusOK {
				var stationData map[string]interface{}
				if json.NewDecoder(resp.Body).Decode(&stationData) == nil {
					// API trả về configurations.all[0].modules[0].sensors
					if configurations, ok := stationData["configurations"].(map[string]interface{}); ok {
						if all, ok := configurations["all"].([]interface{}); ok && len(all) > 0 {
							if config, ok := all[0].(map[string]interface{}); ok {
								if modules, ok := config["modules"].([]interface{}); ok && len(modules) > 0 {
									if module, ok := modules[0].(map[string]interface{}); ok {
										if sensors, ok := module["sensors"].([]interface{}); ok && len(sensors) > 0 {
											log.Printf("  ✅ Sensors created successfully (%d sensors found)", len(sensors))
											resp.Body.Close()

											// Set visible configuration nếu có DB connection
											if db != nil {
												if err := setVisibleConfiguration(db, station.ID, metaIngestion.ID); err != nil {
													log.Printf("  ⚠️  Warning: Failed to set visible configuration: %v", err)
												} else {
													log.Printf("  ✅ Set visible configuration for station")
												}
											}
											break
										}
									}
								}
							}
						}
					}
				}
				resp.Body.Close()
			}
		}

		if retry < maxRetries-1 {
			log.Printf("  ⏳ Sensors not ready yet, waiting... (retry %d/%d)", retry+1, maxRetries)
			time.Sleep(2 * time.Second)
		} else {
			log.Printf("  ⚠️  Warning: Sensors may not be created yet, worker may still be processing")
			// Dù API không tìm thấy sensors, vẫn thử set visible_configuration từ DB
			// vì có thể worker đã xử lý xong nhưng API chưa cập nhật
			if db != nil {
				if err := setVisibleConfiguration(db, station.ID, metaIngestion.ID); err != nil {
					log.Printf("  ⚠️  Warning: Failed to set visible configuration: %v", err)
				} else {
					log.Printf("  ✅ Set visible configuration for station (from DB)")
				}
			}
		}
	}

	// 2. Create and upload data records
	// Meta record number là 1 (record đầu tiên trong file meta)
	metaRecordNumber := uint64(1)
	totalReadings := numReadings
	if totalReadings <= 0 {
		totalReadings = 1
	}
	startTime := time.Now().Add(-time.Duration(totalReadings-1) * floodNetReadingInterval)
	readingNumber := uint64(1)

	for i := 0; i < numReadings; i += 100 {
		batchSize := 100
		if i+batchSize > numReadings {
			batchSize = numReadings - i
		}

		batchStartTime := startTime.Add(time.Duration(i) * floodNetReadingInterval)
		readings := createFloodNetReadingsBatch(int64(metaRecordNumber), readingNumber, batchSize, batchStartTime, station.VietnamStation)

		dataFile := proto.NewBuffer(make([]byte, 0))
		for _, reading := range readings {
			if err := dataFile.EncodeMessage(reading); err != nil {
				return fmt.Errorf("failed to encode reading: %w", err)
			}
		}

		// FIXED: Đảm bảo dùng cùng generationID với meta ingestion
		dataIngestion, err := client.UploadIngestion(deviceID, generationID, "data", dataFile.Bytes())
		if err != nil {
			return fmt.Errorf("failed to upload data batch: %w", err)
		}

		log.Printf("  ✅ Uploaded batch %d/%d (Ingestion ID: %d)", i/batchSize+1, (numReadings+99)/100, dataIngestion.ID)
		readingNumber += uint64(batchSize)
	}

	return nil
}

// normalizeAPIURL removes any path or query string from the URL
func normalizeAPIURL(rawURL string) (string, error) {
	if !strings.HasPrefix(rawURL, "http://") && !strings.HasPrefix(rawURL, "https://") {
		rawURL = "http://" + rawURL
	}

	parsed, err := url.Parse(rawURL)
	if err != nil {
		return "", fmt.Errorf("failed to parse URL: %w", err)
	}

	normalized := url.URL{
		Scheme: parsed.Scheme,
		Host:   parsed.Host,
	}

	return normalized.String(), nil
}

func clampFloat(value float32, min float32, max float32) float32 {
	if value < min {
		return min
	}
	if value > max {
		return max
	}
	return value
}

func sdErrorValue(r *rand.Rand) float32 {
	if r.Float32() < 0.02 {
		return 1.0 + r.Float32()*2.0
	}
	return 0.0
}

// loginAndGetToken logs in and returns JWT token
func loginAndGetToken(client *APIClient, email, password string) (string, error) {
	loginURL := fmt.Sprintf("%s/login", client.BaseURL)

	// API expect body format: {"email": "...", "password": "..."}
	payload := map[string]string{
		"email":    email,
		"password": password,
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequest("POST", loginURL, bytes.NewReader(jsonData))
	if err != nil {
		return "", err
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("login failed: status %d, body: %s", resp.StatusCode, string(body))
	}

	// Token có thể ở trong header hoặc body
	authHeader := resp.Header.Get("Authorization")
	if authHeader != "" {
		// Remove "Bearer " prefix if present
		token := strings.TrimPrefix(authHeader, "Bearer ")
		return token, nil
	}

	// Try to read from body
	var loginResp LoginResponse
	if err := json.NewDecoder(resp.Body).Decode(&loginResp); err != nil {
		return "", fmt.Errorf("failed to decode login response: %w", err)
	}

	token := strings.TrimPrefix(loginResp.Authorization, "Bearer ")
	return token, nil
}

// UploadIngestion uploads data via POST /ingestion
func (c *APIClient) UploadIngestion(deviceID, generationID []byte, dataType string, data []byte) (*IngestionResponse, error) {
	url := fmt.Sprintf("%s/ingestion", c.BaseURL)

	req, err := http.NewRequest("POST", url, bytes.NewReader(data))
	if err != nil {
		return nil, err
	}

	// Set headers
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", c.Token))
	req.Header.Set("Content-Type", common.FkDataBinaryContentType)
	req.Header.Set("Content-Length", fmt.Sprintf("%d", len(data)))
	req.Header.Set("Fk-DeviceId", hex.EncodeToString(deviceID))
	req.Header.Set("Fk-Generation", hex.EncodeToString(generationID))
	req.Header.Set("Fk-Type", dataType)

	// Calculate blocks
	blocksValue := "1,1"
	if dataType == "data" {
		// Estimate number of records (rough estimate)
		blocksValue = fmt.Sprintf("1,%d", len(data)/500)
	}
	req.Header.Set("Fk-Blocks", blocksValue)

	resp, err := c.Client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("upload failed: status %d, body: %s", resp.StatusCode, string(body))
	}

	var result IngestionResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	return &result, nil
}

// ProcessIngestion triggers processing of an ingestion via API POST /data/ingestions/{ingestionId}/process
func (c *APIClient) ProcessIngestion(ingestionID int64) error {
	url := fmt.Sprintf("%s/data/ingestions/%d/process", c.BaseURL, ingestionID)

	req, err := http.NewRequest("POST", url, nil)
	if err != nil {
		return err
	}

	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", c.Token))
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.Client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("process ingestion failed: status %d, body: %s", resp.StatusCode, string(body))
	}

	return nil
}

type IngestionResponse struct {
	ID       int64  `json:"id"`
	UploadID string `json:"upload_id"`
}

// createFloodNetMeta tạo meta record cho FloodNet module
func createFloodNetMeta(station *StationResponse, deviceID, generationID []byte, recordNumber uint64) (*pb.SignedRecord, *pb.DataRecord, error) {
	// Tạo hardware_id cố định cho mỗi station dựa trên device_id
	uniqueSeed := fmt.Sprintf("floodnet-%s", hex.EncodeToString(deviceID))
	moduleID := hashString(uniqueSeed)

	floodNetModule := &pb.ModuleInfo{
		Position: 0,
		Name:     "wh.floodnet",
		Id:       moduleID,
		Header: &pb.ModuleHeader{
			Manufacturer: FloodNetManufacturer,
			Kind:         FloodNetModuleKind,
			Version:      0x01,
		},
		Firmware: &pb.Firmware{
			Version: "1.0.0",
			Build:   "floodnet-v1",
		},
		Sensors: []*pb.SensorInfo{
			{Number: 0, Name: "depth", UnitOfMeasure: "inches", Flags: 0},
			{Number: 1, Name: "depthUnfiltered", UnitOfMeasure: "inches", Flags: 1},
			{Number: 2, Name: "distance", UnitOfMeasure: "mm", Flags: 1},
			{Number: 3, Name: "battery", UnitOfMeasure: "%", Flags: 0},
			{Number: 4, Name: "tideFeet", UnitOfMeasure: "inches", Flags: 0},
			{Number: 5, Name: "humidity", UnitOfMeasure: "%", Flags: 1},
			{Number: 6, Name: "pressure", UnitOfMeasure: "kPa", Flags: 1},
			{Number: 7, Name: "altitude", UnitOfMeasure: "m", Flags: 1},
			{Number: 8, Name: "temperature", UnitOfMeasure: "°C", Flags: 1},
			{Number: 9, Name: "sdError", UnitOfMeasure: "", Flags: 1},
		},
	}

	metadata := &pb.DataRecord{
		Metadata: &pb.Metadata{
			DeviceId: deviceID,
			Time:     time.Now().Unix(),
			Firmware: &pb.Firmware{
				Version: "3.0.5",
				Build:   "fk-v3",
			},
			Modules:    []*pb.ModuleInfo{floodNetModule},
			Generation: generationID,
			Record:     recordNumber,
		},
		Identity: &pb.Identity{
			Name: station.Name,
		},
		// Set Modules field trực tiếp từ Metadata.Modules để handler OnMeta có thể sử dụng
		Modules: []*pb.ModuleInfo{floodNetModule},
	}

	delimited := proto.NewBuffer(make([]byte, 0))
	if err := delimited.EncodeMessage(metadata); err != nil {
		return nil, nil, err
	}

	hash := blake2b.Sum256(delimited.Bytes())

	signedRecord := &pb.SignedRecord{
		Kind:   pb.SignedRecordKind_SIGNED_RECORD_KIND_MODULES,
		Time:   time.Now().Unix(),
		Data:   delimited.Bytes(),
		Hash:   hash[:],
		Record: recordNumber,
	}

	return signedRecord, metadata, nil
}

// setVisibleConfiguration sets the visible configuration for a station after meta processing
func setVisibleConfiguration(db *sqlxcache.DB, stationID int32, metaIngestionID int64) error {
	ctx := context.Background()

	// Query meta_record từ ingestion_id
	var metaRecordID int64
	if err := db.GetContext(ctx, &metaRecordID, `
		SELECT mr.id 
		FROM fieldkit.meta_record mr
		JOIN fieldkit.provision p ON mr.provision_id = p.id
		JOIN fieldkit.station s ON p.device_id = s.device_id
		JOIN fieldkit.ingestion i ON i.device_id = s.device_id
		WHERE i.id = $1 AND s.id = $2
		ORDER BY mr.id DESC
		LIMIT 1
	`, metaIngestionID, stationID); err != nil {
		return fmt.Errorf("failed to find meta_record: %w", err)
	}

	// Query configuration từ meta_record_id
	var configurationID int64
	if err := db.GetContext(ctx, &configurationID, `
		SELECT id FROM fieldkit.station_configuration
		WHERE meta_record_id = $1
		LIMIT 1
	`, metaRecordID); err != nil {
		return fmt.Errorf("failed to find configuration: %w", err)
	}

	// Set visible configuration
	if _, err := db.ExecContext(ctx, `
		INSERT INTO fieldkit.visible_configuration (station_id, configuration_id)
		VALUES ($1, $2)
		ON CONFLICT (station_id) DO UPDATE SET configuration_id = EXCLUDED.configuration_id
	`, stationID, configurationID); err != nil {
		return fmt.Errorf("failed to set visible configuration: %w", err)
	}

	return nil
}

// createFloodNetReadingsBatch tạo batch readings
func createFloodNetReadingsBatch(metaNumber int64, startReadingNumber uint64, count int, startTime time.Time, location *VietnamStation) []*pb.DataRecord {
	readings := make([]*pb.DataRecord, count)
	for i := 0; i < count; i++ {
		recordTime := startTime.Add(time.Duration(i) * floodNetReadingInterval)
		cycleSeconds := recordTime.Hour()*3600 + recordTime.Minute()*60 + recordTime.Second()
		dayFraction := float64(cycleSeconds) / float64(24*3600)
		tideEffect := float32(math.Sin(dayFraction * 2 * math.Pi))
		randomizer := rand.New(rand.NewSource(recordTime.UnixNano()))
		depthInches := 6.0 + tideEffect*3.0 + (randomizer.Float32()*2.0 - 1.0)
		if depthInches < 0.2 {
			depthInches = 0.2
		}
		readings[i] = createFloodNetReading(metaNumber, startReadingNumber+uint64(i), depthInches, recordTime, location)
	}
	return readings
}

func createFloodNetReading(metaNumber int64, readingNumber uint64, depthInches float32, recordTime time.Time, location *VietnamStation) *pb.DataRecord {
	mrand := rand.New(rand.NewSource(recordTime.Unix()))

	return &pb.DataRecord{
		Readings: &pb.Readings{
			Time:    int64(recordTime.Unix()),
			Reading: readingNumber,
			Meta:    uint64(metaNumber),
			Flags:   0,
			Location: func() *pb.DeviceLocation {
				baseLongitude := float32(105.8412)
				baseLatitude := float32(21.0285)
				if location != nil {
					baseLongitude = float32(location.Longitude)
					baseLatitude = float32(location.Latitude)
				}
				longitude := baseLongitude + (mrand.Float32()-0.5)*0.02
				latitude := baseLatitude + (mrand.Float32()-0.5)*0.02
				altitude := 3.0 + mrand.Float32()*4.0
				return &pb.DeviceLocation{
					Fix:        1,
					Time:       int64(recordTime.Unix()),
					Longitude:  longitude,
					Latitude:   latitude,
					Altitude:   altitude,
					Satellites: 7 + uint32(mrand.Intn(3)),
				}
			}(),
			SensorGroups: []*pb.SensorGroup{
				{
					Module: 0,
					Time:   int64(recordTime.Unix()),
					Readings: []*pb.SensorAndValue{
						{Sensor: 0, Calibrated: &pb.SensorAndValue_CalibratedValue{CalibratedValue: depthInches}},
						{Sensor: 1, Calibrated: &pb.SensorAndValue_CalibratedValue{CalibratedValue: depthInches + (mrand.Float32()-0.5)*0.8}},
						{Sensor: 2, Calibrated: &pb.SensorAndValue_CalibratedValue{CalibratedValue: depthInches*25.4 + (mrand.Float32()-0.5)*15.0}},
						{Sensor: 3, Calibrated: &pb.SensorAndValue_CalibratedValue{CalibratedValue: 75.0 + (mrand.Float32()-0.5)*10.0}},
						{Sensor: 4, Calibrated: &pb.SensorAndValue_CalibratedValue{CalibratedValue: (depthInches / 12.0) + (mrand.Float32()-0.5)*0.2}},
						{Sensor: 5, Calibrated: &pb.SensorAndValue_CalibratedValue{CalibratedValue: clampFloat(60.0+(mrand.Float32()-0.5)*25.0, 0, 100)}},
						{Sensor: 6, Calibrated: &pb.SensorAndValue_CalibratedValue{CalibratedValue: 101.3 + (mrand.Float32()-0.5)*4.0}},
						{Sensor: 7, Calibrated: &pb.SensorAndValue_CalibratedValue{CalibratedValue: 3.0 + mrand.Float32()*4.0}},
						{Sensor: 8, Calibrated: &pb.SensorAndValue_CalibratedValue{CalibratedValue: 26.0 + (mrand.Float32()-0.5)*6.0}},
						{Sensor: 9, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{UncalibratedValue: sdErrorValue(mrand)}},
					},
				},
			},
		},
	}
}

func hashString(seed string) []byte {
	hasher := sha1.New()
	hasher.Write([]byte(seed))
	return hasher.Sum(nil)
}

func extractPlainBytes(signed *pb.SignedRecord) []byte {
	var dataRecord pb.DataRecord
	if err := proto.Unmarshal(signed.Data, &dataRecord); err != nil {
		return nil
	}
	plain := proto.NewBuffer(make([]byte, 0))
	if err := plain.Marshal(&dataRecord); err != nil {
		return nil
	}
	return plain.Bytes()
}
