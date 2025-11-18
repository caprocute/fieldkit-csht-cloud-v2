package main

import (
	"bytes"
	"context"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/golang/protobuf/proto"
	_ "github.com/lib/pq"

	"gitlab.com/fieldkit/cloud/server/backend/repositories"
	"gitlab.com/fieldkit/cloud/server/common"
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
	"gitlab.com/fieldkit/cloud/server/data"
	pb "gitlab.com/fieldkit/libraries/data-protocol"
)

const (
	// FIXED: Sử dụng giá trị từ DB (module_meta table)
	// wh.floodnet có manufacturer=0, kinds={0}
	FloodNetManufacturer = 0x00 // 0 (từ DB: manufacturer=0)
	FloodNetModuleKind   = 0x00 // 0 (từ DB: kinds={0})
)

type StationInfo struct {
	Station       *data.Station
	Provision     *data.Provision
	MetaRecord    *data.MetaRecord
	Configuration *data.StationConfiguration
	Location      *data.Location
}

type HardwareSimulator struct {
	APIURL      string
	Token       string
	StationInfo *StationInfo
	Client      *http.Client

	// State
	ReadingNum uint64
	LastUpload time.Time
	mu         sync.Mutex
}

type simulationState struct {
	started    time.Time
	running    atomic.Bool
	uploads    atomic.Uint64
	stations   int32
	interval   time.Duration
	batchSize  int
	lastUpload atomic.Value // time.Time
}

var simState simulationState

func main() {
	var (
		apiURL    = "http://fieldkit-staging-alb-1189893191.ap-southeast-1.elb.amazonaws.com"
		token     = flag.String("token", "", "JWT token for authentication (optional, will auto-login if empty)")
		dbURL     = "postgresql://fieldkit:WxdI7USgPlkSVOcrE8cCcn2vA@fieldkit-staging-postgres-nlb-2e92e35ac371a189.elb.ap-southeast-1.amazonaws.com:5432/fieldkit?sslmode=disable"
		stationID = flag.Int("station-id", 0, "Station ID (0 to simulate all stations)")
		interval  = flag.Duration("interval", 90*time.Second, "Upload interval")
		batchSize = flag.Int("batch", 100, "Number of readings per upload")
		email     = flag.String("email", "floodnet@test.local", "Email for auto-login")
		password  = flag.String("password", "test123456", "Password for auto-login")
	)
	flag.Parse()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Auto-login if token not provided
	if *token == "" {
		log.Printf("No token provided, attempting auto-login with email=%s...", *email)
		fetchedToken, err := fetchToken(apiURL, *email, *password)
		if err != nil {
			log.Fatalf("❌ Auto-login failed: %v", err)
		}
		*token = fetchedToken
		log.Printf("✅ Auto-login successful, token obtained")
	}

	if *token == "" {
		fmt.Fprintf(os.Stderr, "Error: -token flag is required (or provide -email/-password for auto-login)\n")
		flag.Usage()
		os.Exit(1)
	}

	if dbURL == "" {
		fmt.Fprintf(os.Stderr, "Error: -db flag is required\n")
		flag.Usage()
		os.Exit(1)
	}

	// Normalize API URL
	normalizedAPIURL, err := normalizeAPIURL(apiURL)
	if err != nil {
		log.Fatalf("Invalid API URL: %v", err)
	}
	log.Printf("Using API URL: %s", normalizedAPIURL)

	// Connect to database
	ctx := context.Background()
	db, err := sqlxcache.Open(ctx, "postgres", dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Load station information
	stationRepo := repositories.NewStationRepository(db)
	// removed: provisionRepo and recordRepo (unused)

	var stations []*StationInfo

	if *stationID > 0 {
		// Load single station
		station, err := stationRepo.QueryStationByID(ctx, int32(*stationID))
		if err != nil {
			log.Fatalf("Failed to query station %d: %v", *stationID, err)
		}

		info, err := loadStationInfo(ctx, station, db, stationRepo)
		if err != nil {
			log.Fatalf("Failed to load station info: %v", err)
		}
		stations = []*StationInfo{info}
		log.Printf("✅ Loaded station: %s (ID: %d)", station.Name, station.ID)
	} else {
		// Load all stations - query directly from DB
		allStations := []*data.Station{}
		if err := db.SelectContext(ctx, &allStations, `
			SELECT id, name, device_id, model_id, owner_id, created_at, updated_at, battery, location_name, place_other, place_native, photo_id,
				recording_started_at, memory_used, memory_available, firmware_number, firmware_time, ST_AsBinary(location) AS location, hidden, description, status
			FROM fieldkit.station
			WHERE hidden IS FALSE OR hidden IS NULL
			ORDER BY id
		`); err != nil {
			log.Fatalf("Failed to query stations: %v", err)
		}

		log.Printf("Found %d stations, loading information...", len(allStations))
		for _, station := range allStations {
			info, err := loadStationInfo(ctx, station, db, stationRepo)
			if err != nil {
				log.Printf("⚠️  Warning: Failed to load info for station %d (%s): %v", station.ID, station.Name, err)
				continue
			}
			stations = append(stations, info)
		}
		log.Printf("✅ Loaded %d stations", len(stations))
	}

	if len(stations) == 0 {
		log.Fatalf("No stations to simulate")
	}

	// Start HTTP server immediately (Cloud Run readiness)
	go startHTTPServer(port)

	// Setup signal handling
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	simState.interval = *interval
	simState.batchSize = *batchSize
	simState.stations = int32(len(stations))

	simState.started = time.Now()
	simState.running.Store(true)

	// Start simulators for each station
	var wg sync.WaitGroup
	for _, stationInfo := range stations {
		wg.Add(1)
		go func(info *StationInfo) {
			defer wg.Done()
			sim := &HardwareSimulator{
				APIURL:      normalizedAPIURL,
				Token:       *token,
				StationInfo: info,
				Client:      &http.Client{Timeout: 30 * time.Second},
				ReadingNum:  1,
				LastUpload:  time.Now(),
			}

			// Initialize: upload meta if needed
			log.Printf("[Station %d: %s] Initializing...", info.Station.ID, info.Station.Name)
			if err := sim.initialize(); err != nil {
				log.Printf("[Station %d: %s] ❌ Failed to initialize: %v", info.Station.ID, info.Station.Name, err)
				return
			}
			log.Printf("[Station %d: %s] ✅ Initialized", info.Station.ID, info.Station.Name)

			// Start upload loop
			ticker := time.NewTicker(*interval)
			defer ticker.Stop()

			// Upload immediately
			go func() {
				if err := sim.uploadBatch(*batchSize); err == nil {
					simState.uploads.Add(1)
					simState.lastUpload.Store(time.Now())
				}
			}()

			for {
				select {
				case <-ticker.C:
					if err := sim.uploadBatch(*batchSize); err != nil {
						log.Printf("[Station %d: %s] Error uploading batch: %v", info.Station.ID, info.Station.Name, err)
					} else {
						simState.uploads.Add(1)
						simState.lastUpload.Store(time.Now())
					}
				case sig := <-sigChan:
					log.Printf("[Station %d: %s] Received signal: %v, shutting down...", info.Station.ID, info.Station.Name, sig)
					return
				}
			}
		}(stationInfo)
	}

	wg.Wait()
	simState.running.Store(false)
	select {} // keep process alive so Cloud Run doesn't exit
}

func loadStationInfo(ctx context.Context, station *data.Station, db *sqlxcache.DB, stationRepo *repositories.StationRepository) (*StationInfo, error) {
	// Get provision (contains generation ID) - query directly from DB
	provisions := []*data.Provision{}
	if err := db.SelectContext(ctx, &provisions, `
		SELECT id, created, updated, generation, device_id
		FROM fieldkit.provision
		WHERE device_id = $1
		ORDER BY updated DESC
	`, station.DeviceID); err != nil {
		return nil, fmt.Errorf("failed to query provision: %w", err)
	}
	if len(provisions) == 0 {
		return nil, fmt.Errorf("no provision found for station")
	}
	provision := provisions[0] // Use most recent

	// Get visible configuration
	configuration, provisionFromConfig, err := stationRepo.QueryVisibleConfiguration(ctx, station.ID)
	if err != nil || configuration == nil {
		// Try to get latest configuration
		configurations := []*data.StationConfiguration{}
		if err := db.SelectContext(ctx, &configurations, `
			SELECT id, provision_id, meta_record_id, source_id, updated_at
			FROM fieldkit.station_configuration
			WHERE provision_id = $1
			ORDER BY updated_at DESC
			LIMIT 1
		`, provision.ID); err != nil || len(configurations) == 0 {
			return nil, fmt.Errorf("no configuration found for station")
		}
		configuration = configurations[0]
		provisionFromConfig = provision
	} else {
		provision = provisionFromConfig
	}

	// Get meta record (contains meta record number) - query directly from DB
	metaRecords := []*data.MetaRecord{}
	if err := db.SelectContext(ctx, &metaRecords, `
		SELECT id, provision_id, time, number, raw, pb
		FROM fieldkit.meta_record
		WHERE provision_id = $1
		ORDER BY number DESC
		LIMIT 1
	`, provision.ID); err != nil {
		return nil, fmt.Errorf("failed to query meta record: %w", err)
	}
	if len(metaRecords) == 0 {
		return nil, fmt.Errorf("no meta record found for station")
	}
	metaRecord := metaRecords[0] // Use most recent

	// Get location from station
	var location *data.Location
	if station.Location != nil {
		location = station.Location
	}

	return &StationInfo{
		Station:       station,
		Provision:     provision,
		MetaRecord:    metaRecord,
		Configuration: configuration,
		Location:      location,
	}, nil
}

func (s *HardwareSimulator) initialize() error {
	// Check if meta record exists, if not upload it
	// For now, we assume meta is already uploaded
	// In a real scenario, we might want to check and upload if needed
	return nil
}

func (s *HardwareSimulator) uploadBatch(batchSize int) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Generate readings since last upload
	readings := s.generateReadings(batchSize)

	// Log JSON của từng bản tin
	vietnamTZ, _ := time.LoadLocation("Asia/Ho_Chi_Minh")
	for i, reading := range readings {
		// Format thời gian theo GMT+7
		recordTime := time.Unix(reading.Readings.Time, 0).In(vietnamTZ)
		readingJSON := map[string]interface{}{
			"station_id":   s.StationInfo.Station.ID,
			"station_name": s.StationInfo.Station.Name,
			"reading_num":  reading.Readings.Reading,
			"meta_number":  reading.Readings.Meta,
			"time":         recordTime.Format(time.RFC3339),
			"time_unix":    reading.Readings.Time,
			"time_gmt7":    recordTime.Format("2006-01-02T15:04:05+07:00"),
			"sensor_count": len(reading.Readings.SensorGroups[0].Readings),
			"location": map[string]interface{}{
				"longitude": reading.Readings.Location.Longitude,
				"latitude":  reading.Readings.Location.Latitude,
				"altitude":  reading.Readings.Location.Altitude,
			},
			"sensors": func() []map[string]interface{} {
				sensors := make([]map[string]interface{}, 0)
				for _, sg := range reading.Readings.SensorGroups {
					for _, r := range sg.Readings {
						sensorData := map[string]interface{}{
							"sensor": r.Sensor,
						}
						if r.GetCalibrated() != nil {
							sensorData["value"] = r.GetCalibratedValue()
							sensorData["type"] = "calibrated"
						} else if r.GetUncalibrated() != nil {
							sensorData["value"] = r.GetUncalibratedValue()
							sensorData["type"] = "uncalibrated"
						}
						sensors = append(sensors, sensorData)
					}
				}
				return sensors
			}(),
		}
		jsonBytes, _ := json.Marshal(readingJSON)
		log.Printf("[Station %d: %s] 📤 Reading %d/%d JSON: %s",
			s.StationInfo.Station.ID, s.StationInfo.Station.Name, i+1, len(readings), string(jsonBytes))
	}

	// Encode readings
	dataFile := proto.NewBuffer(make([]byte, 0))
	for _, reading := range readings {
		if err := dataFile.EncodeMessage(reading); err != nil {
			return fmt.Errorf("failed to encode reading: %w", err)
		}
	}

	// Upload
	ingestion, err := s.uploadIngestion("data", dataFile.Bytes())
	if err != nil {
		return err
	}

	elapsed := time.Since(s.LastUpload)
	s.LastUpload = time.Now()

	log.Printf("[Station %d: %s] ✅ Uploaded %d readings (Ingestion ID: %d, elapsed: %v, total: %d)",
		s.StationInfo.Station.ID, s.StationInfo.Station.Name, len(readings), ingestion.ID, elapsed, s.ReadingNum)

	return nil
}

func (s *HardwareSimulator) generateReadings(count int) []*pb.DataRecord {
	readings := make([]*pb.DataRecord, 0, count)

	// Sử dụng thời gian hiện tại GMT+7 (Vietnam timezone)
	vietnamTZ, _ := time.LoadLocation("Asia/Ho_Chi_Minh")
	now := time.Now().In(vietnamTZ)

	// Tạo random seed dựa trên station ID + timestamp để mỗi station có dữ liệu khác nhau
	// và mỗi lần chạy cũng khác nhau
	seed := int64(s.StationInfo.Station.ID)*1000000000 + now.UnixNano()

	// Get location from station info
	var baseLongitude, baseLatitude float32
	if s.StationInfo.Location != nil {
		baseLongitude = float32(s.StationInfo.Location.Longitude())
		baseLatitude = float32(s.StationInfo.Location.Latitude())
	} else {
		// Default to Hanoi if no location
		baseLongitude = 105.8412
		baseLatitude = 21.0285
	}

	// Base values cho mỗi station (khác nhau dựa trên station ID)
	stationOffset := float32(s.StationInfo.Station.ID%100) / 10.0 // 0-9.9 offset
	baseDepth := 8.0 + stationOffset                              // Mỗi station có base depth khác nhau
	baseBattery := 70.0 + stationOffset*2.0                       // Battery level khác nhau
	baseHumidity := 50.0 + stationOffset*3.0                      // Humidity khác nhau
	basePressure := 101.3 + stationOffset*0.1                     // Pressure khác nhau
	baseTemp := 20.0 + stationOffset*1.5                          // Temperature khác nhau

	for i := 0; i < count; i++ {
		// Mỗi bản tin sử dụng thời gian hiện tại (GMT+7)
		// Nếu có nhiều readings trong batch, mỗi reading cách nhau 1 giây
		recordTime := now.Add(time.Duration(i) * time.Second)

		// Tạo random seed mới cho mỗi reading để đảm bảo tính ngẫu nhiên
		readingSeed := seed + int64(i)*1000 + int64(s.ReadingNum)
		readingRand := rand.New(rand.NewSource(readingSeed))

		// Simulate depth: varies with time (tide simulation) + random variation
		hour := float32(recordTime.Hour())
		minute := float32(recordTime.Minute())
		// Tidal variation theo giờ (sin wave)
		tideVariation := 2.0 * float32(sin(float64(hour*2*3.14159/24)))
		// Thêm variation nhỏ theo phút
		minuteVariation := 0.5 * float32(sin(float64(minute*2*3.14159/60)))
		tideBase := baseDepth + tideVariation + minuteVariation

		// Add random variation and occasional "flood" events
		var depthInches float32
		if readingRand.Float32() < 0.05 { // 5% chance of flood event
			floodAmount := 8.0 + readingRand.Float32()*4.0 // 8-12 inches above normal
			depthInches = tideBase + floodAmount + readingRand.Float32()*2.0 - 1.0
		} else {
			// Random variation lớn hơn
			depthInches = tideBase + readingRand.Float32()*2.0 - 1.0 // -1 to +1 inch variation
		}

		// Ensure depth is never negative
		if depthInches < 0 {
			depthInches = 0.1 + readingRand.Float32()*0.5
		}

		// Random GPS variation (mỗi reading khác nhau)
		gpsVariation := (readingRand.Float32() - 0.5) * 0.002 // ±0.001 degree variation
		longitude := baseLongitude + gpsVariation
		latitude := baseLatitude + gpsVariation*0.8 // Latitude variation nhỏ hơn một chút

		// Random altitude (thay đổi theo thời gian và random)
		altitude := 5.0 + readingRand.Float32()*3.0 - 1.5 // 3.5-8.5 meters

		// Use meta record number from database
		metaRecordNumber := uint64(s.StationInfo.MetaRecord.Number)

		// Generate sensor values với random variation lớn hơn
		// Sensor 0: depth (calibrated) - đã tính ở trên
		sensor0Depth := depthInches

		// Sensor 1: depthUnfiltered - có noise lớn hơn
		sensor1Depth := depthInches + (readingRand.Float32()-0.5)*1.5
		if sensor1Depth < 0 {
			sensor1Depth = 0.1
		}

		// Sensor 2: distance - tính từ depth với random variation
		sensor2Distance := depthInches*25.4 + (readingRand.Float32()-0.5)*5.0 // mm
		if sensor2Distance < 0 {
			sensor2Distance = 0.1
		}

		// Sensor 3: battery - giảm dần theo thời gian + random variation
		// Battery giảm nhẹ theo số readings
		batteryDrain := float32(s.ReadingNum) * 0.001 // Giảm 0.1% mỗi 100 readings
		sensor3Battery := baseBattery - batteryDrain + (readingRand.Float32()-0.5)*3.0
		if sensor3Battery < 0 {
			sensor3Battery = 0.1
		}
		if sensor3Battery > 100 {
			sensor3Battery = 100
		}

		// Sensor 4: tideFeet - từ tideBase với random
		sensor4Tide := (tideBase / 12.0) + (readingRand.Float32()-0.5)*0.2 // feet

		// Sensor 5: humidity - thay đổi theo thời gian + random
		hourHumidity := float32(sin(float64(hour*2*3.14159/24))) * 10.0 // Variation theo giờ
		sensor5Humidity := baseHumidity + hourHumidity + (readingRand.Float32()-0.5)*8.0
		if sensor5Humidity < 0 {
			sensor5Humidity = 0.1
		}
		if sensor5Humidity > 100 {
			sensor5Humidity = 100
		}

		// Sensor 6: pressure - thay đổi nhẹ theo thời gian + random
		pressureVariation := (readingRand.Float32() - 0.5) * 3.0 // ±1.5 kPa
		sensor6Pressure := basePressure + pressureVariation

		// Sensor 7: altitude - random variation
		sensor7Altitude := altitude + (readingRand.Float32()-0.5)*2.0
		if sensor7Altitude < 0 {
			sensor7Altitude = 0.1
		}

		// Sensor 8: temperature - thay đổi theo giờ + random
		hourTemp := float32(sin(float64(hour*2*3.14159/24))) * 5.0 // Variation theo giờ
		sensor8Temp := baseTemp + hourTemp + (readingRand.Float32()-0.5)*4.0

		// Sensor 9: sdError - thỉnh thoảng có lỗi
		var sensor9Error float32
		if readingRand.Float32() < 0.02 { // 2% chance of error
			sensor9Error = 1.0 + readingRand.Float32()*2.0 // 1-3 error code
		} else {
			sensor9Error = 0.0
		}

		reading := &pb.DataRecord{
			Readings: &pb.Readings{
				Time:    int64(recordTime.Unix()),
				Reading: s.ReadingNum,
				Meta:    metaRecordNumber, // Use meta record number from DB
				Flags:   0,
				Location: &pb.DeviceLocation{
					Fix:        1,
					Time:       int64(recordTime.Unix()),
					Longitude:  longitude,
					Latitude:   latitude,
					Altitude:   altitude,
					Satellites: 6 + uint32(readingRand.Intn(4)), // 6-9 satellites
				},
				SensorGroups: []*pb.SensorGroup{
					{
						Module: 0,
						Time:   int64(recordTime.Unix()),
						Readings: []*pb.SensorAndValue{
							// FIXED: Sử dụng đúng số lượng sensors từ DB (10 sensors, ordering 0-9)
							{Sensor: 0, Calibrated: &pb.SensorAndValue_CalibratedValue{CalibratedValue: sensor0Depth}},
							{Sensor: 1, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{UncalibratedValue: sensor1Depth}},
							{Sensor: 2, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{UncalibratedValue: sensor2Distance}},
							{Sensor: 3, Calibrated: &pb.SensorAndValue_CalibratedValue{CalibratedValue: sensor3Battery}},
							{Sensor: 4, Calibrated: &pb.SensorAndValue_CalibratedValue{CalibratedValue: sensor4Tide}},
							{Sensor: 5, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{UncalibratedValue: sensor5Humidity}},
							{Sensor: 6, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{UncalibratedValue: sensor6Pressure}},
							{Sensor: 7, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{UncalibratedValue: sensor7Altitude}},
							{Sensor: 8, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{UncalibratedValue: sensor8Temp}},
							{Sensor: 9, Uncalibrated: &pb.SensorAndValue_UncalibratedValue{UncalibratedValue: sensor9Error}}, // sdError
						},
					},
				},
			},
		}

		readings = append(readings, reading)
		s.ReadingNum++
	}

	return readings
}

func (s *HardwareSimulator) uploadIngestion(dataType string, data []byte) (*IngestionResponse, error) {
	url := fmt.Sprintf("%s/ingestion", s.APIURL)

	req, err := http.NewRequest("POST", url, bytes.NewReader(data))
	if err != nil {
		return nil, err
	}

	// Set headers exactly as hardware would
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", s.Token))
	req.Header.Set("Content-Type", common.FkDataBinaryContentType)
	req.Header.Set("Content-Length", fmt.Sprintf("%d", len(data)))
	req.Header.Set("Fk-DeviceId", hex.EncodeToString(s.StationInfo.Station.DeviceID))
	req.Header.Set("Fk-Generation", hex.EncodeToString(s.StationInfo.Provision.GenerationID))
	req.Header.Set("Fk-Type", dataType)

	// For meta, blocks should be "1,1" (first block, last block)
	// For data, blocks should be "1,<reading_number>"
	blocksValue := fmt.Sprintf("1,%d", s.ReadingNum)
	if dataType == "meta" {
		blocksValue = "1,1"
	}
	req.Header.Set("Fk-Blocks", blocksValue)

	log.Printf("[Station %d: %s] Uploading %s to %s (blocks: %s, size: %d bytes)",
		s.StationInfo.Station.ID, s.StationInfo.Station.Name, dataType, url, blocksValue, len(data))

	resp, err := s.Client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("upload failed: status %d, body: %s, url: %s", resp.StatusCode, string(bodyBytes), url)
	}

	var result IngestionResponse
	if err := json.Unmarshal(bodyBytes, &result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w, body: %s", err, string(bodyBytes))
	}

	return &result, nil
}

func startHTTPServer(port string) {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("/status", func(w http.ResponseWriter, r *http.Request) {
		last := ""
		if v := simState.lastUpload.Load(); v != nil {
			if t, ok := v.(time.Time); ok {
				last = t.Format(time.RFC3339)
			}
		}
		resp := map[string]interface{}{
			"running":     simState.running.Load(),
			"started_at":  simState.started.Format(time.RFC3339),
			"stations":    simState.stations,
			"interval":    simState.interval.String(),
			"batch_size":  simState.batchSize,
			"uploads":     simState.uploads.Load(),
			"last_upload": last,
			"version":     "sim-v1",
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	})
	addr := ":" + port
	log.Printf("HTTP server listening on %s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("HTTP server error: %v", err)
	}
}

type IngestionResponse struct {
	ID       int64  `json:"id"`
	UploadID string `json:"upload_id"`
}

func sin(x float64) float64 {
	// Simple sine approximation using Taylor series
	// Normalize to [0, 2π]
	for x < 0 {
		x += 2 * 3.141592653589793
	}
	for x > 2*3.141592653589793 {
		x -= 2 * 3.141592653589793
	}
	// Taylor series: sin(x) ≈ x - x³/6 + x⁵/120
	return x - (x*x*x)/6 + (x*x*x*x*x)/120
}

// normalizeAPIURL removes any path or query string from the URL, keeping only scheme + host + port
func normalizeAPIURL(rawURL string) (string, error) {
	// If URL doesn't have scheme, add http://
	if !strings.HasPrefix(rawURL, "http://") && !strings.HasPrefix(rawURL, "https://") {
		rawURL = "http://" + rawURL
	}

	parsed, err := url.Parse(rawURL)
	if err != nil {
		return "", fmt.Errorf("failed to parse URL: %w", err)
	}

	// Rebuild URL with only scheme, host, and port
	normalized := url.URL{
		Scheme: parsed.Scheme,
		Host:   parsed.Host,
	}

	return normalized.String(), nil
}

// fetchToken performs POST /login and extracts the Bearer token
func fetchToken(apiURL, email, password string) (string, error) {
	loginURL := fmt.Sprintf("%s/login", strings.TrimRight(apiURL, "/"))

	reqBody := map[string]string{
		"email":    email,
		"password": password,
	}
	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("failed to encode login request: %w", err)
	}

	req, err := http.NewRequest("POST", loginURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return "", fmt.Errorf("failed to create login request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("login request failed: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)

	// Check status code
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		return "", fmt.Errorf("login failed: status %d, body: %s", resp.StatusCode, string(body))
	}

	// Priority 1: Check Authorization header (most common for this API)
	authHeader := resp.Header.Get("Authorization")
	if authHeader != "" {
		if strings.HasPrefix(authHeader, "Bearer ") {
			token := strings.TrimPrefix(authHeader, "Bearer ")
			log.Printf("✅ Token found in Authorization header")
			return token, nil
		}
		// Sometimes it's just the token without "Bearer " prefix
		log.Printf("✅ Token found in Authorization header (no Bearer prefix)")
		return authHeader, nil
	}

	// Priority 2: Check custom token header
	if tokenHeader := resp.Header.Get("X-Auth-Token"); tokenHeader != "" {
		log.Printf("✅ Token found in X-Auth-Token header")
		return tokenHeader, nil
	}

	// Priority 3: Try to parse body as JSON (if body exists)
	if len(body) > 0 {
		var loginResp struct {
			Token string `json:"token"`
		}
		if err := json.Unmarshal(body, &loginResp); err == nil && loginResp.Token != "" {
			log.Printf("✅ Token found in response body")
			return loginResp.Token, nil
		}
	}

	// No token found anywhere
	return "", fmt.Errorf("no token found in Authorization header, X-Auth-Token header, or response body (status %d)", resp.StatusCode)
}
