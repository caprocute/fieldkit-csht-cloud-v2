package main

import (
	"bytes"
	"crypto/sha1"
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
	"strings"
	"time"

	"github.com/golang/protobuf/proto"
	"golang.org/x/crypto/blake2b"

	"gitlab.com/fieldkit/cloud/server/common"
	pb "gitlab.com/fieldkit/libraries/data-protocol"
)

const (
	// FIXED: Sử dụng giá trị từ DB (module_meta table)
	// wh.floodnet có manufacturer=0, kinds={0}
	FloodNetManufacturer = 0x00 // 0 (từ DB: manufacturer=0)
	FloodNetModuleKind   = 0x00 // 0 (từ DB: kinds={0})
)

func main() {
	var (
		apiURL     = flag.String("api", "http://localhost:8080", "API base URL")
		token      = flag.String("token", "", "JWT token for authentication (required)")
		deviceID   = flag.String("device-id", "", "Device ID (hex string, auto-generated if empty)")
		stationID  = flag.Int("station-id", 0, "Existing station ID (0 to create new)")
		readings   = flag.Int("readings", 672, "Number of readings to upload (default: 672 = 1 week with 15-minute interval)")
		interval   = flag.Duration("interval", 15*time.Minute, "Interval between uploads")
		continuous = flag.Bool("continuous", false, "Run continuously (simulate real device)")
	)
	flag.Parse()

	if *token == "" {
		fmt.Fprintf(os.Stderr, "Error: -token flag is required\n")
		fmt.Fprintf(os.Stderr, "Get token by logging in via API: POST %s/login\n", *apiURL)
		flag.Usage()
		os.Exit(1)
	}

	// Normalize API URL: remove any path or query string, keep only scheme + host + port
	normalizedAPIURL, err := normalizeAPIURL(*apiURL)
	if err != nil {
		log.Fatalf("Invalid API URL: %v", err)
	}
	log.Printf("Using API URL: %s", normalizedAPIURL)

	client := &APIClient{
		BaseURL: normalizedAPIURL,
		Token:   *token,
		Client:  http.DefaultClient,
	}

	// Generate or use provided device ID
	var deviceIDBytes []byte
	if *deviceID == "" {
		hasher := sha1.New()
		hasher.Write([]byte(fmt.Sprintf("floodnet-device-%d", time.Now().UnixNano())))
		deviceIDBytes = hasher.Sum(nil)
		log.Printf("Generated device ID: %s", hex.EncodeToString(deviceIDBytes))
	} else {
		var err error
		deviceIDBytes, err = hex.DecodeString(*deviceID)
		if err != nil {
			log.Fatalf("Invalid device ID: %v", err)
		}
	}

	generationID := deviceIDBytes

	// Get or create station
	stationIDInt := int32(*stationID)
	if stationIDInt == 0 {
		station, err := client.CreateStation(deviceIDBytes, "FloodNet Test Station")
		if err != nil {
			log.Fatalf("Failed to create station: %v", err)
		}
		stationIDInt = station.ID
		log.Printf("Created station: %s (ID: %d)", station.Name, station.ID)
	} else {
		log.Printf("Using existing station ID: %d", stationIDInt)
	}

	// Create meta record
	metaRecord, _, err := createFloodNetMetaRecord(deviceIDBytes, generationID, "FloodNet Test Station")
	if err != nil {
		log.Fatalf("Failed to create meta record: %v", err)
	}

	// Upload meta
	metaFile := proto.NewBuffer(make([]byte, 0))
	if err := metaFile.EncodeMessage(metaRecord); err != nil {
		log.Fatalf("Failed to encode meta: %v", err)
	}

	metaIngestion, err := client.UploadIngestion(deviceIDBytes, generationID, "meta", metaFile.Bytes())
	if err != nil {
		log.Fatalf("Failed to upload meta: %v", err)
	}
	log.Printf("Uploaded meta ingestion: ID=%d, UploadID=%s", metaIngestion.ID, metaIngestion.UploadID)

	if *continuous {
		log.Printf("Running in continuous mode (interval: %v)", *interval)
		log.Println("Press Ctrl+C to stop")
		
		readingNumber := uint64(1)
		ticker := time.NewTicker(*interval)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				// Create batch of readings
				readingsBatch := createReadingsBatch(metaIngestion.ID, readingNumber, *readings)
				
				// Upload data
				dataFile := proto.NewBuffer(make([]byte, 0))
				for _, reading := range readingsBatch {
					if err := dataFile.EncodeMessage(reading); err != nil {
						log.Printf("Error encoding reading: %v", err)
						continue
					}
				}

				dataIngestion, err := client.UploadIngestion(deviceIDBytes, generationID, "data", dataFile.Bytes())
				if err != nil {
					log.Printf("Error uploading data: %v", err)
					continue
				}

				log.Printf("Uploaded %d readings (Ingestion ID: %d)", len(readingsBatch), dataIngestion.ID)
				readingNumber += uint64(len(readingsBatch))
			}
		}
	} else {
		// Single upload
		log.Printf("Creating %d readings...", *readings)
		readingsBatch := createReadingsBatch(metaIngestion.ID, 1, *readings)
		
		dataFile := proto.NewBuffer(make([]byte, 0))
		for _, reading := range readingsBatch {
			if err := dataFile.EncodeMessage(reading); err != nil {
				log.Fatalf("Failed to encode reading: %v", err)
			}
		}

		dataIngestion, err := client.UploadIngestion(deviceIDBytes, generationID, "data", dataFile.Bytes())
		if err != nil {
			log.Fatalf("Failed to upload data: %v", err)
		}

		log.Printf("✅ Uploaded %d readings successfully (Ingestion ID: %d)", len(readingsBatch), dataIngestion.ID)
	}
}

type APIClient struct {
	BaseURL string
	Token   string
	Client  *http.Client
}

type Station struct {
	ID       int32  `json:"id"`
	Name     string `json:"name"`
	DeviceID []byte `json:"deviceId"`
}

type IngestionResponse struct {
	ID       int64  `json:"id"`
	UploadID string `json:"upload_id"`
}

func (c *APIClient) CreateStation(deviceID []byte, name string) (*Station, error) {
	// Create station via API
	// Endpoint: POST /stations (không phải /data/stations)
	url := fmt.Sprintf("%s/stations", c.BaseURL)
	
	payload := map[string]interface{}{
		"name":     name,
		"deviceId": hex.EncodeToString(deviceID),
	}
	
	jsonData, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	
	req, err := http.NewRequest("POST", url, bytes.NewReader(jsonData))
	if err != nil {
		return nil, err
	}
	
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", c.Token))
	req.Header.Set("Content-Type", "application/json")
	
	resp, err := c.Client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("create station failed: status %d, body: %s", resp.StatusCode, string(body))
	}
	
	var result Station
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	
	return &result, nil
}

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
	
	// Calculate blocks based on data type
	blocksValue := "1,1"
	if dataType == "data" {
		// Estimate number of records (rough estimate: ~500 bytes per record)
		estimatedRecords := len(data) / 500
		if estimatedRecords < 1 {
			estimatedRecords = 1
		}
		blocksValue = fmt.Sprintf("1,%d", estimatedRecords)
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
	if err := decodeJSON(resp.Body, &result); err != nil {
		return nil, err
	}

	return &result, nil
}

func createFloodNetMetaRecord(deviceID, generationID []byte, name string) (*pb.SignedRecord, *pb.DataRecord, error) {
	moduleID := hashString(fmt.Sprintf("floodnet-%s", hex.EncodeToString(deviceID)))
	
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
			Record:     1,
		},
		Identity: &pb.Identity{
			Name: name,
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
		Record: 1,
	}

	return signedRecord, metadata, nil
}

func createReadingsBatch(metaID int64, startReading uint64, count int) []*pb.DataRecord {
	readings := make([]*pb.DataRecord, 0, count)
	now := time.Now()
	mrand := rand.New(rand.NewSource(now.UnixNano()))

	for i := 0; i < count; i++ {
		recordTime := now.Add(time.Duration(i) * 15 * time.Minute)
		
		// Simulate realistic depth values
		progress := float32(i) / float32(count)
		var depthInches float32
		if progress < 0.3 {
			depthInches = 8.0 + progress*4.0/0.3
		} else if progress < 0.6 {
			depthInches = 12.0 + (progress-0.3)*6.0/0.3
		} else {
			depthInches = 18.0 - (progress-0.6)*10.0/0.4
		}

		reading := &pb.DataRecord{
			Readings: &pb.Readings{
				Time:    int64(recordTime.Unix()),
				Reading: startReading + uint64(i),
				Meta:    uint64(metaID),
				Flags:   0,
				Location: &pb.DeviceLocation{
					Fix:        1,
					Time:       int64(recordTime.Unix()),
					// Vietnam locations (Hanoi area)
					Longitude:  105.8412,
					Latitude:   21.0285,
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

		readings = append(readings, reading)
	}

	return readings
}

func hashString(seed string) []byte {
	hasher := sha1.New()
	hasher.Write([]byte(seed))
	return hasher.Sum(nil)
}

func decodeJSON(r io.Reader, v interface{}) error {
	return json.NewDecoder(r).Decode(v)
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

