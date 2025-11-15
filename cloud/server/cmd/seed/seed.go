package main

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"os"
	"strings"
	"time"

	"github.com/golang/protobuf/proto"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/lib/pq"
	"golang.org/x/crypto/blake2b"

	"gitlab.com/fieldkit/cloud/server/backend/handlers"
	"gitlab.com/fieldkit/cloud/server/backend/repositories"
	"gitlab.com/fieldkit/cloud/server/common/logging"
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
	"gitlab.com/fieldkit/cloud/server/data"
	pb "gitlab.com/fieldkit/libraries/data-protocol"
)

const (
	FloodNetModuleID     = 19
	// FIXED: Sử dụng giá trị từ DB (module_meta table)
	// wh.floodnet có manufacturer=0, kinds={0}
	FloodNetManufacturer = 0x00 // 0 (từ DB: manufacturer=0)
	FloodNetModuleKind   = 0x00 // 0 (từ DB: kinds={0})
)

func main() {
	var (
		dbURL         = flag.String("db", "", "PostgreSQL connection URL (required)")
		stations      = flag.Int("stations", 5, "Number of FloodNet stations to create")
		readings      = flag.Int("readings", 672, "Number of readings per station (default: 672 = 1 week with 15-minute interval)")
		project       = flag.String("project", "FloodNet Vietnam Monitoring", "Project name")
		userEmail     = flag.String("user", "floodnet@test.local", "User email")
		userName      = flag.String("name", "FloodNet Test User", "User name")
		password      = flag.String("password", "test123456", "User password")
		cleanupOnly   = flag.Bool("cleanup-only", false, "Only cleanup invalid notifications, don't create data")
		deleteAllUsersFlag = flag.Bool("delete-all-users", false, "Delete all users and their associated data")
	)
	flag.Parse()

	if *dbURL == "" {
		fmt.Fprintf(os.Stderr, "Error: -db flag is required\n")
		flag.Usage()
		os.Exit(1)
	}

	// Khởi tạo logger - cần thiết cho repositories
	logging.Configure(false, "seed")

	ctx := context.Background()

	// Kết nối database
	db, err := sqlxcache.Open(ctx, "postgres", *dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	pgxcfg, err := pgxpool.ParseConfig(*dbURL)
	if err != nil {
		log.Fatalf("Failed to parse database config: %v", err)
	}

	dbpool, err := pgxpool.NewWithConfig(ctx, pgxcfg)
	if err != nil {
		log.Fatalf("Failed to create connection pool: %v", err)
	}
	defer dbpool.Close()

	log.Println("Connected to database successfully")

	// Xóa tất cả users nếu flag được set
	if *deleteAllUsersFlag {
		if err := deleteAllUsers(ctx, db); err != nil {
			log.Fatalf("Failed to delete all users: %v", err)
		}
		log.Println("✅ All users deleted successfully")
		// Nếu chỉ xóa users thì dừng ở đây
		if !*cleanupOnly {
			return
		}
	}

	// Cleanup notifications không hợp lệ (có post_id nhưng discussion_post/user không tồn tại)
	// Điều này tránh lỗi nil pointer khi NotificationUserInfo() dereference *n.AuthorID
	// Khi websocket query notifications và gọi ToMap(), nó sẽ gọi NotificationUserInfo()
	// Nếu AuthorID là nil, sẽ panic khi dereference *n.AuthorID
	if err := cleanupInvalidNotifications(ctx, db); err != nil {
		log.Printf("Warning: Failed to cleanup invalid notifications: %v (continuing anyway)", err)
	} else {
		log.Println("✅ Cleanup completed successfully")
	}

	// Nếu chỉ cleanup thì dừng ở đây
	if *cleanupOnly {
		return
	}

	// Tạo user
	user, err := createUser(ctx, db, *userEmail, *userName, *password)
	if err != nil {
		log.Fatalf("Failed to create user: %v", err)
	}
	log.Printf("Created user: %s (ID: %d)", user.Email, user.ID)

	// Tạo project
	proj, err := createProject(ctx, db, *project, user.ID)
	if err != nil {
		log.Fatalf("Failed to create project: %v", err)
	}
	log.Printf("Created project: %s (ID: %d)", proj.Name, proj.ID)

	// Reset sequence cho station để đảm bảo không có conflict
	// Điều này cần thiết nếu sequence bị lệch so với dữ liệu hiện có
	if _, err := db.ExecContext(ctx, `
		SELECT setval('station_id_seq', COALESCE((SELECT MAX(id) FROM fieldkit.station), 0) + 1, false)
	`); err != nil {
		log.Printf("Warning: Failed to reset station sequence: %v (continuing anyway)", err)
	}

	// Tạo danh sách địa điểm Việt Nam trước khi tạo stations
	rngForStations := rand.New(rand.NewSource(time.Now().UnixNano()))
	vietnamStations := GetRandomStations(*stations, rngForStations)

	// Tạo stations
	log.Printf("Creating %d FloodNet stations...", *stations)
	stationList, err := createFloodNetStations(ctx, db, proj.ID, user.ID, *stations, vietnamStations)
	if err != nil {
		log.Fatalf("Failed to create stations: %v", err)
	}
	log.Printf("Created %d stations", len(stationList))

	// Tạo map để lưu location cho mỗi station
	stationLocationMap := make(map[int32]*VietnamStation)
	for i, station := range stationList {
		// Lấy location từ vietnamStations
		if i < len(vietnamStations) {
			stationLocationMap[station.ID] = &vietnamStations[i]
		}
	}

	// Tạo dữ liệu cho mỗi station
	for i, station := range stationList {
		log.Printf("Creating data for station %d/%d: %s", i+1, len(stationList), station.Name)
		location := stationLocationMap[station.ID]

		if err := createStationData(ctx, db, dbpool, station, user, *readings, location); err != nil {
			log.Printf("Warning: Failed to create data for station %s: %v", station.Name, err)
			continue
		}
		log.Printf("Completed data for station: %s", station.Name)
	}

	log.Println("✅ Database seeding completed successfully!")
}

// cleanupInvalidNotifications xóa các notifications không hợp lệ:
// - Có user_id nhưng user không tồn tại (foreign key violation)
// - Có post_id nhưng discussion_post không tồn tại
// - Hoặc discussion_post có user_id nhưng user không tồn tại
// Điều này tránh lỗi nil pointer khi NotificationUserInfo() dereference *n.AuthorID
// và tránh lỗi khi query notifications với user_id không tồn tại
func cleanupInvalidNotifications(ctx context.Context, db *sqlxcache.DB) error {
	var totalDeleted int64

	// 1. Xóa notifications có user_id nhưng user không tồn tại
	result1, err := db.ExecContext(ctx, `
		DELETE FROM fieldkit.notification
		WHERE NOT EXISTS (
			SELECT 1 FROM fieldkit.user WHERE id = notification.user_id
		)
	`)
	if err != nil {
		return fmt.Errorf("failed to cleanup notifications with invalid user_id: %w", err)
	}
	deleted1, _ := result1.RowsAffected()
	totalDeleted += deleted1
	if deleted1 > 0 {
		log.Printf("Cleaned up %d notifications with invalid user_id", deleted1)
	}

	// 2. Xóa notifications có post_id nhưng discussion_post không tồn tại
	// hoặc discussion_post có user_id nhưng user không tồn tại
	result2, err := db.ExecContext(ctx, `
		DELETE FROM fieldkit.notification
		WHERE post_id IS NOT NULL
		AND (
			NOT EXISTS (
				SELECT 1 FROM fieldkit.discussion_post WHERE id = notification.post_id
			)
			OR EXISTS (
				SELECT 1 FROM fieldkit.discussion_post p
				WHERE p.id = notification.post_id
				AND NOT EXISTS (
					SELECT 1 FROM fieldkit.user WHERE id = p.user_id
				)
			)
		)
	`)
	if err != nil {
		return fmt.Errorf("failed to cleanup notifications with invalid post_id: %w", err)
	}
	deleted2, _ := result2.RowsAffected()
	totalDeleted += deleted2
	if deleted2 > 0 {
		log.Printf("Cleaned up %d notifications with invalid post_id or author", deleted2)
	}

	if totalDeleted > 0 {
		log.Printf("✅ Total cleaned up: %d invalid notifications", totalDeleted)
	} else {
		log.Printf("✅ No invalid notifications found")
	}

	return nil
}

func createUser(ctx context.Context, db *sqlxcache.DB, email, name, password string) (*data.User, error) {
	// Tạo email unique bằng cách thêm timestamp
	// Nếu email đã có @ thì tách phần trước @, nếu không thì dùng toàn bộ
	emailPrefix := email
	if idx := strings.Index(email, "@"); idx > 0 {
		emailPrefix = email[:idx]
	}
	uniqueEmail := fmt.Sprintf("%s-%d@test.local", emailPrefix, time.Now().UnixNano())

	user := &data.User{
		Name:     fmt.Sprintf("%s %d", name, time.Now().UnixNano()),
		Username: uniqueEmail,
		Email:    uniqueEmail,
		Bio:      "",
		Valid:    true,
		Admin:    false,
	}
	// Đảm bảo ID = 0 để PostgreSQL tự động dùng nextval từ sequence user_id_seq
	user.ID = 0

	user.SetPassword(password)

	// Create new user - ID sẽ được tự động tạo từ sequence user_id_seq
	if err := db.NamedGetContext(ctx, user, `
		INSERT INTO fieldkit.user (name, username, email, password, bio, valid, admin)
		VALUES (:name, :username, :email, :password, :bio, :valid, :admin)
		RETURNING id
	`, user); err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	return user, nil
}

func createProject(ctx context.Context, db *sqlxcache.DB, name string, ownerID int32) (*data.Project, error) {
	// Tạo name unique bằng cách thêm timestamp
	uniqueName := fmt.Sprintf("%s %d", name, time.Now().UnixNano())

	project := &data.Project{
		Name:             uniqueName,
		Description:      "FloodNet monitoring project for Vietnam area",
		Goal:             "Monitor flood levels in Vietnam",
		Location:         "Vietnam",
		Tags:             "floodnet,monitoring,vietnam",
		Privacy:          data.Public,
		CommunityRanking: 0, // Default value
		ShowStations:     false,
	}
	// Đảm bảo ID = 0 để PostgreSQL tự động dùng nextval từ sequence project_id_seq
	project.ID = 0

	// Create new project - ID sẽ được tự động tạo từ sequence project_id_seq
	// Schema: name, description, goal, location, tags, privacy, community_ranking (all NOT NULL)
	if err := db.NamedGetContext(ctx, project, `
		INSERT INTO fieldkit.project (name, description, goal, location, tags, privacy, community_ranking, show_stations)
		VALUES (:name, :description, :goal, :location, :tags, :privacy, :community_ranking, :show_stations)
		RETURNING id
	`, project); err != nil {
		return nil, fmt.Errorf("failed to create project: %w", err)
	}

	// Add owner to project
	if _, err := db.ExecContext(ctx, `
		INSERT INTO fieldkit.project_user (project_id, user_id, role)
		VALUES ($1, $2, $3)
		ON CONFLICT DO NOTHING
	`, project.ID, ownerID, data.AdministratorRole.ID); err != nil {
		return nil, err
	}

	return project, nil
}

func createFloodNetStations(ctx context.Context, db *sqlxcache.DB, projectID, ownerID int32, count int, vietnamStations []VietnamStation) ([]*data.Station, error) {
	stations := []*data.Station{}

	for i := 0; i < count; i++ {
		// Sử dụng tên địa điểm Việt Nam
		name := fmt.Sprintf("FloodNet - %s, %s", vietnamStations[i].Name, vietnamStations[i].Province)

		// Tạo device_id unique bằng cách thêm timestamp và random
		// Thêm delay nhỏ để đảm bảo timestamp unique
		time.Sleep(time.Millisecond * 10)
		hasher := sha1.New()
		hasher.Write([]byte(fmt.Sprintf("floodnet-station-%d-%d-%d-%d", projectID, i, time.Now().UnixNano(), rand.Int63())))
		deviceID := hasher.Sum(nil)

		location := []float64{vietnamStations[i].Longitude, vietnamStations[i].Latitude}

		// Create new station - ID sẽ được tự động tạo từ sequence
		// Đảm bảo ID = 0 để PostgreSQL tự động dùng nextval
		station := &data.Station{
			DeviceID:  deviceID,
			OwnerID:   ownerID,
			ModelID:   data.FieldKitModelID,
			Name:      name,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
			Location:  data.NewLocation(location),
		}
		// Đảm bảo ID = 0
		station.ID = 0

		// INSERT không chỉ định ID, PostgreSQL sẽ tự động dùng nextval từ sequence
		// Sử dụng GetContext với RETURNING để tránh vấn đề với NamedGetContext
		// Location cần được convert sang WKT string
		locationWKT, err := station.Location.Value()
		if err != nil {
			return nil, fmt.Errorf("failed to convert location to WKT: %w", err)
		}

		var stationID int32
		if err := db.GetContext(ctx, &stationID, `
			INSERT INTO fieldkit.station (name, device_id, owner_id, model_id, created_at, updated_at, location)
			VALUES ($1, $2, $3, $4, $5, $6, ST_SetSRID(ST_GeomFromText($7), 4326))
			RETURNING id
		`, station.Name, station.DeviceID, station.OwnerID, station.ModelID, station.CreatedAt, station.UpdatedAt, locationWKT); err != nil {
			return nil, fmt.Errorf("failed to create station: %w", err)
		}
		station.ID = stationID

		// Add station to project
		// Schema: id serial4 NOT NULL, station_id int4 NOT NULL, project_id int4 NOT NULL
		// ID sẽ được tự động tạo từ sequence project_station_id_seq
		if _, err := db.ExecContext(ctx, `
			INSERT INTO fieldkit.project_station (station_id, project_id)
			VALUES ($1, $2)
			ON CONFLICT (station_id, project_id) DO NOTHING
		`, station.ID, projectID); err != nil {
			return nil, fmt.Errorf("failed to add station to project: %w", err)
		}

		stations = append(stations, station)
	}

	return stations, nil
}

func createStationData(ctx context.Context, db *sqlxcache.DB, dbpool *pgxpool.Pool, station *data.Station, user *data.User, numReadings int, location *VietnamStation) error {
	// Tạo generation_id unique bằng cách thêm timestamp
	hasher := blake2b.Sum256(append(station.DeviceID, []byte(fmt.Sprintf("-%d", time.Now().UnixNano()))...))
	generationID := hasher[:]

	// Create provision - ID sẽ được tự động tạo từ sequence provision_id_seq
	provision := &data.Provision{
		Created:      time.Now(),
		Updated:      time.Now(),
		DeviceID:     station.DeviceID,
		GenerationID: generationID,
	}
	// Đảm bảo ID = 0 để PostgreSQL tự động dùng nextval từ sequence
	provision.ID = 0

	if err := db.NamedGetContext(ctx, provision, `
		INSERT INTO fieldkit.provision (device_id, generation, created, updated)
		VALUES (:device_id, :generation, :created, :updated)
		RETURNING id
	`, provision); err != nil {
		return fmt.Errorf("failed to create provision: %w", err)
	}

	// Create meta ingestion - ID sẽ được tự động tạo từ sequence ingestion_id_seq
	metaIngestion := &data.Ingestion{
		Time:         time.Now(),
		URL:          fmt.Sprintf("file:///floodnet/meta-%d-%d.fkpb", station.ID, time.Now().UnixNano()),
		UploadID:     fmt.Sprintf("meta-%d-%d", station.ID, time.Now().UnixNano()),
		UserID:       user.ID,
		DeviceID:     station.DeviceID,
		GenerationID: generationID,
		Type:         data.MetaTypeName,
		Size:         1024,
		Blocks:       data.Int64Range([]int64{1, 1}),
		Flags:        pq.Int64Array([]int64{}),
	}
	// Đảm bảo ID = 0 để PostgreSQL tự động dùng nextval từ sequence
	metaIngestion.ID = 0

	if err := db.NamedGetContext(ctx, metaIngestion, `
		INSERT INTO fieldkit.ingestion (time, upload_id, user_id, device_id, generation, type, size, url, blocks, flags)
		VALUES (:time, :upload_id, :user_id, :device_id, :generation, :type, :size, :url, :blocks, :flags)
		RETURNING id
	`, metaIngestion); err != nil {
		return fmt.Errorf("failed to create meta ingestion: %w", err)
	}

	// Create meta record
	metaRecord, metaData, err := createFloodNetMeta(station, 1)
	if err != nil {
		return err
	}

	recordRepo := repositories.NewRecordRepository(db)
	metaRec, err := recordRepo.AddSignedMetaRecord(ctx, provision, metaIngestion, metaRecord, metaData, extractPlainBytes(metaRecord))
	if err != nil {
		return err
	}

	// Tạo StationModule và ModuleSensor từ MetaRecord
	// Điều này cần thiết để station hiển thị sensors trong UI
	// metaData đã có Modules field được set từ createFloodNetMeta
	handler := handlers.NewStationModelRecordHandler(db)
	if err := handler.OnMeta(ctx, provision, metaData, metaRec); err != nil {
		return fmt.Errorf("failed to create station modules and sensors: %w", err)
	}

	// Đảm bảo station có visible configuration để hiển thị sensors
	stationRepo := repositories.NewStationRepository(db)
	// Lấy configuration vừa tạo từ metaRecordID
	configuration, err := stationRepo.QueryStationConfigurationByMetaID(ctx, metaRec.ID)
	if err != nil {
		return fmt.Errorf("failed to query configuration: %w", err)
	}
	if configuration != nil {
		// Set configuration làm visible
		if err := stationRepo.UpsertVisibleConfiguration(ctx, station.ID, configuration.ID); err != nil {
			return fmt.Errorf("failed to set visible configuration: %w", err)
		}
	}

	// Create data ingestion - ID sẽ được tự động tạo từ sequence ingestion_id_seq
	dataIngestion := &data.Ingestion{
		Time:         time.Now(),
		URL:          fmt.Sprintf("file:///floodnet/data-%d-%d.fkpb", station.ID, time.Now().UnixNano()),
		UploadID:     fmt.Sprintf("data-%d-%d", station.ID, time.Now().UnixNano()),
		UserID:       user.ID,
		DeviceID:     station.DeviceID,
		GenerationID: generationID,
		Type:         data.DataTypeName,
		Size:         int64(numReadings * 500), // Estimate
		Blocks:       data.Int64Range([]int64{1, int64(numReadings)}),
		Flags:        pq.Int64Array([]int64{}),
	}
	// Đảm bảo ID = 0 để PostgreSQL tự động dùng nextval từ sequence
	dataIngestion.ID = 0

	if err := db.NamedGetContext(ctx, dataIngestion, `
		INSERT INTO fieldkit.ingestion (time, upload_id, user_id, device_id, generation, type, size, url, blocks, flags)
		VALUES (:time, :upload_id, :user_id, :device_id, :generation, :type, :size, :url, :blocks, :flags)
		RETURNING id
	`, dataIngestion); err != nil {
		return fmt.Errorf("failed to create data ingestion: %w", err)
	}

	// Create readings
	startTime := time.Now().AddDate(0, 0, -7) // 7 days ago
	readingNumber := uint64(1)

	for i := 0; i < numReadings; i++ {
		recordTime := startTime.Add(time.Duration(i) * 15 * time.Minute)

		// Simulate flood pattern
		progress := float32(i) / float32(numReadings)
		var depthInches float32
		if progress < 0.3 {
			depthInches = 8.0 + progress*4.0/0.3
		} else if progress < 0.6 {
			depthInches = 12.0 + (progress-0.3)*6.0/0.3
		} else {
			depthInches = 18.0 - (progress-0.6)*10.0/0.4
		}

		// Sử dụng metaRec.Number thay vì metaRec.ID vì AddDataRecord tìm meta record bằng number
		reading := createFloodNetReading(metaRec.Number, readingNumber, depthInches, recordTime, location)

		buffer := proto.NewBuffer(make([]byte, 0))
		if err := buffer.Marshal(reading); err != nil {
			return err
		}

		_, _, err := recordRepo.AddDataRecord(ctx, provision, dataIngestion, reading, buffer.Bytes())
		if err != nil {
			return err
		}

		readingNumber++
	}

	return nil
}

func createFloodNetMeta(station *data.Station, recordNumber uint64) (*pb.SignedRecord, *pb.DataRecord, error) {
	moduleID := hashString(fmt.Sprintf("floodnet-%s", hex.EncodeToString(station.DeviceID)))

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
			DeviceId: station.DeviceID,
			Time:     time.Now().Unix(),
			Firmware: &pb.Firmware{
				Version: "3.0.5",
				Build:   "fk-v3",
			},
			Modules:    []*pb.ModuleInfo{floodNetModule},
			Generation: station.DeviceID,
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

func createFloodNetReading(metaID int64, readingNumber uint64, depthInches float32, recordTime time.Time, location *VietnamStation) *pb.DataRecord {
	mrand := rand.New(rand.NewSource(recordTime.Unix()))

	return &pb.DataRecord{
		Readings: &pb.Readings{
			Time:    int64(recordTime.Unix()),
			Reading: readingNumber,
			Meta:    uint64(metaID),
			Flags:   0,
			Location: &pb.DeviceLocation{
				Fix:        1,
				Time:       int64(recordTime.Unix()),
				// Sử dụng location từ VietnamStations
				Longitude: func() float32 {
					if location != nil {
						return float32(location.Longitude)
					}
					return 105.8412 // Default: Hanoi
				}(),
				Latitude: func() float32 {
					if location != nil {
						return float32(location.Latitude)
					}
					return 21.0285 // Default: Hanoi
				}(),
				Altitude:   5.0,
				Satellites: 8,
			},
			SensorGroups: []*pb.SensorGroup{
				{
					Module: 0,
					Time:   int64(recordTime.Unix()),
					Readings: []*pb.SensorAndValue{
						// FIXED: Sử dụng đúng số lượng sensors từ DB (10 sensors, ordering 0-9)
						{Sensor: 0, Calibrated: &pb.SensorAndValue_CalibratedValue{CalibratedValue: depthInches}},
						{Sensor: 1, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{UncalibratedValue: depthInches + mrand.Float32()*0.5}},
						{Sensor: 2, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{UncalibratedValue: depthInches * 25.4}},
						{Sensor: 3, Calibrated: &pb.SensorAndValue_CalibratedValue{CalibratedValue: 70.0 + mrand.Float32()*20.0}},
						{Sensor: 4, Calibrated: &pb.SensorAndValue_CalibratedValue{CalibratedValue: 8.0 + mrand.Float32()*2.0}},
						{Sensor: 5, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{UncalibratedValue: 50.0 + mrand.Float32()*30.0}},
						{Sensor: 6, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{UncalibratedValue: 101.3 + mrand.Float32()*2.0}},
						{Sensor: 7, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{UncalibratedValue: 5.0}},
						{Sensor: 8, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{UncalibratedValue: 20.0 + mrand.Float32()*10.0}},
						{Sensor: 9, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{UncalibratedValue: 0.0}}, // sdError
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

// deleteAllUsers xóa tất cả users và tất cả dữ liệu liên quan
// Logic này dựa trên deleteUser() trong user_service.go nhưng xóa tất cả users
func deleteAllUsers(ctx context.Context, db *sqlxcache.DB) error {
	log.Println("⚠️  WARNING: Deleting ALL users and their associated data...")

	// Lấy danh sách tất cả user IDs trước khi xóa
	var userIDs []int32
	if err := db.SelectContext(ctx, &userIDs, `SELECT id FROM fieldkit.user ORDER BY id`); err != nil {
		return fmt.Errorf("failed to query user IDs: %w", err)
	}

	if len(userIDs) == 0 {
		log.Println("No users found to delete")
		return nil
	}

	log.Printf("Found %d users to delete", len(userIDs))

	// Xóa tất cả dữ liệu liên quan đến users
	// Sử dụng logic tương tự như deleteUser() nhưng không cần WHERE user_id = $1
	queries := []struct {
		name  string
		query string
	}{
		{"project_invite", `DELETE FROM fieldkit.project_invite`},
		{"project_follower", `DELETE FROM fieldkit.project_follower`},
		{"project_user", `DELETE FROM fieldkit.project_user`},
		{"station photo", `UPDATE fieldkit.station SET photo_id = NULL WHERE owner_id IN (SELECT id FROM fieldkit.user)`},
		{"notes_media_link (by station)", `DELETE FROM fieldkit.notes_media_link WHERE note_id IN (SELECT id FROM fieldkit.notes WHERE station_id IN (SELECT id FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user)))`},
		{"notes_media_link (by author)", `DELETE FROM fieldkit.notes_media_link WHERE note_id IN (SELECT id FROM fieldkit.notes WHERE author_id IN (SELECT id FROM fieldkit.user))`},
		{"notes_media_link (by media user)", `DELETE FROM fieldkit.notes_media_link WHERE media_id IN (SELECT id FROM fieldkit.notes_media WHERE user_id IN (SELECT id FROM fieldkit.user))`},
		{"notes_media_link (complex)", `DELETE FROM fieldkit.notes_media_link WHERE media_id IN (SELECT media_id FROM fieldkit.notes_media_link WHERE note_id IN (SELECT id FROM fieldkit.notes WHERE station_id IN (SELECT id FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user))))`},
		{"notes_media_link (complex 2)", `DELETE FROM fieldkit.notes_media_link WHERE note_id IN (SELECT media_id FROM fieldkit.notes_media WHERE station_id IN (SELECT id FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user)))`},
		{"notes_media (by link)", `DELETE FROM fieldkit.notes_media WHERE id IN (SELECT media_id FROM fieldkit.notes_media_link WHERE note_id IN (SELECT id FROM fieldkit.notes WHERE station_id IN (SELECT id FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user))))`},
		{"notes_media (by user)", `DELETE FROM fieldkit.notes_media WHERE user_id IN (SELECT id FROM fieldkit.user)`},
		{"notes_media (by station)", `DELETE FROM fieldkit.notes_media WHERE station_id IN (SELECT id FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user))`},
		{"notes (by author)", `DELETE FROM fieldkit.notes WHERE author_id IN (SELECT id FROM fieldkit.user)`},
		{"notes (by station)", `DELETE FROM fieldkit.notes WHERE station_id IN (SELECT id FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user))`},
		{"data_event", `DELETE FROM fieldkit.data_event WHERE user_id IN (SELECT id FROM fieldkit.user)`},
		{"data_export", `DELETE FROM fieldkit.data_export WHERE user_id IN (SELECT id FROM fieldkit.user)`},
		{"discussion_post", `DELETE FROM fieldkit.discussion_post WHERE user_id IN (SELECT id FROM fieldkit.user)`},
		{"project_update", `DELETE FROM fieldkit.project_update WHERE author_id IN (SELECT id FROM fieldkit.user)`},
		{"visible_configuration", `DELETE FROM fieldkit.visible_configuration WHERE station_id IN (SELECT id FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user))`},
		{"project_station", `DELETE FROM fieldkit.project_station WHERE station_id IN (SELECT id FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user))`},
		{"station_activity", `DELETE FROM fieldkit.station_activity WHERE station_id IN (SELECT id FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user))`},
		{"station_ingestion", `DELETE FROM fieldkit.station_ingestion WHERE uploader_id IN (SELECT id FROM fieldkit.user)`},
		{"station", `DELETE FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user)`},
		{"recovery_token", `DELETE FROM fieldkit.recovery_token WHERE user_id IN (SELECT id FROM fieldkit.user)`},
		{"validation_token", `DELETE FROM fieldkit.validation_token WHERE user_id IN (SELECT id FROM fieldkit.user)`},
		{"refresh_token", `DELETE FROM fieldkit.refresh_token WHERE user_id IN (SELECT id FROM fieldkit.user)`},
		{"notification", `DELETE FROM fieldkit.notification WHERE user_id IN (SELECT id FROM fieldkit.user)`},
		{"user", `DELETE FROM fieldkit.user`},
	}

	for _, q := range queries {
		log.Printf("Deleting %s...", q.name)
		result, err := db.ExecContext(ctx, q.query)
		if err != nil {
			return fmt.Errorf("failed to delete %s: %w", q.name, err)
		}
		rowsAffected, _ := result.RowsAffected()
		if rowsAffected > 0 {
			log.Printf("  ✅ Deleted %d rows from %s", rowsAffected, q.name)
		}
	}

	log.Printf("✅ Successfully deleted all %d users and their associated data", len(userIDs))
	return nil
}
