package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"

	_ "github.com/lib/pq"

	"gitlab.com/fieldkit/cloud/server/common/logging"
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
)

func main() {
	var (
		dbURL    = flag.String("db", "", "PostgreSQL connection URL (required)")
		stationID = flag.Int("station", 0, "Station ID to check (0 = check all)")
	)
	flag.Parse()

	if *dbURL == "" {
		fmt.Fprintf(os.Stderr, "Error: -db flag is required\n")
		flag.Usage()
		os.Exit(1)
	}

	// Khởi tạo logger
	logging.Configure(false, "check_sensors")

	ctx := context.Background()

	// Kết nối database
	db, err := sqlxcache.Open(ctx, "postgres", *dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	log.Println("🔍 Checking sensors for stations...")
	if *stationID > 0 {
		log.Printf("   Checking station ID: %d\n", *stationID)
	} else {
		log.Println("   Checking all stations")
	}
	log.Println("")

	// Trước tiên, kiểm tra chi tiết từng station
	checkStationDetails(ctx, db, *stationID)
	log.Println("")

	// Query để kiểm tra sensors (giống như QueryStationSensors)
	query := `
		SELECT
			q.station_id,
			q.station_name,
			q.module_id,
			q.module_hardware_id,
			q.module_key,
			agg_sensor.id AS sensor_id,
			q.full_sensor_key AS sensor_key,
			q.sensor_read_at
		FROM (
			SELECT
				station.id AS station_id,
				station.name AS station_name,
				station_module.id AS module_id,
				ENCODE(station_module.hardware_id, 'base64') AS module_hardware_id,
				station_module.name AS module_key,
				station_module.name || '.' || module_sensor.name AS full_sensor_key,
				module_sensor.reading_time AS sensor_read_at
			FROM fieldkit.station AS station
			LEFT JOIN fieldkit.visible_configuration AS vc ON (vc.station_id = station.id)
			LEFT JOIN fieldkit.configuration_module AS config_module ON (vc.configuration_id = config_module.configuration_id)
			LEFT JOIN fieldkit.station_module AS station_module ON (config_module.module_id = station_module.id)
			LEFT JOIN fieldkit.module_sensor AS module_sensor ON (module_sensor.module_id = station_module.id)
			WHERE 1=1
	`

	args := []interface{}{}
	argIndex := 1
	if *stationID > 0 {
		query += fmt.Sprintf(" AND station.id = $%d", argIndex)
		args = append(args, *stationID)
		argIndex++
	}

	query += `
			ORDER BY sensor_read_at DESC
		) AS q
		LEFT JOIN fieldkit.aggregated_sensor AS agg_sensor ON (agg_sensor.key = q.full_sensor_key)
		ORDER BY q.station_id, q.module_id, q.full_sensor_key
	`

	type SensorRow struct {
		StationID       int32   `db:"station_id"`
		StationName     string  `db:"station_name"`
		ModuleID        *int64  `db:"module_id"`
		ModuleHardwareID *string `db:"module_hardware_id"`
		ModuleKey       *string `db:"module_key"`
		SensorID        *int64  `db:"sensor_id"`
		SensorKey       *string `db:"sensor_key"`
		SensorReadAt    *string `db:"sensor_read_at"`
	}

	rows := []SensorRow{}
	if err := db.SelectContext(ctx, &rows, query, args...); err != nil {
		log.Fatalf("Failed to query sensors: %v", err)
	}

	if len(rows) == 0 {
		log.Println("❌ No sensors found")
		log.Println("")
		log.Println("💡 Possible causes:")
		log.Println("   1. No visible_configuration for station")
		log.Println("   2. No station_module created from meta ingestion")
		log.Println("   3. No module_sensor created from meta ingestion")
		log.Println("")
		log.Println("🔧 Solution: Run process_meta tool to trigger meta processing")
		return
	}

	// Group by station
	currentStationID := int32(0)
	sensorCount := 0
	for _, row := range rows {
		if row.StationID != currentStationID {
			if currentStationID > 0 {
				log.Printf("   Total: %d sensors\n", sensorCount)
				log.Println("")
			}
			currentStationID = row.StationID
			sensorCount = 0
			log.Printf("📍 Station %d: %s", row.StationID, row.StationName)
			log.Println("   " + strings.Repeat("-", 60))
		}

		if row.ModuleID == nil {
			log.Printf("   ⚠️  Sensor key: %s (no module_id - will not show in UI)", 
				stringValue(row.SensorKey))
			continue
		}

		sensorCount++
		log.Printf("   ✅ Module: %s (ID: %d, Hardware: %s)", 
			stringValue(row.ModuleKey), 
			*row.ModuleID,
			stringValue(row.ModuleHardwareID))
		log.Printf("      Sensor: %s (ID: %d)", 
			stringValue(row.SensorKey),
			int64Value(row.SensorID))
		if row.SensorReadAt != nil {
			log.Printf("      Last reading: %s", *row.SensorReadAt)
		}
	}

	if currentStationID > 0 {
		log.Printf("   Total: %d sensors\n", sensorCount)
	}

	log.Println("")
	
	// Count unique stations
	stationMap := make(map[int32]bool)
	for _, row := range rows {
		stationMap[row.StationID] = true
	}
	log.Printf("📊 Summary: Found sensors for %d station(s)", len(stationMap))
}

func stringValue(s *string) string {
	if s == nil {
		return "<nil>"
	}
	return *s
}

func int64Value(i *int64) int64 {
	if i == nil {
		return 0
	}
	return *i
}

func checkStationDetails(ctx context.Context, db *sqlxcache.DB, stationID int) {
	type StationDetailRow struct {
		StationID       int32  `db:"station_id"`
		StationName     string `db:"station_name"`
		HasProvision    bool   `db:"has_provision"`
		HasConfig       bool   `db:"has_config"`
		HasModule       bool   `db:"has_module"`
		HasSensor       bool   `db:"has_sensor"`
		ConfigCount     int    `db:"config_count"`
		ModuleCount     int    `db:"module_count"`
		SensorCount     int    `db:"sensor_count"`
		MetaIngestionID *int64 `db:"meta_ingestion_id"`
		MetaIngestionTime *string `db:"meta_ingestion_time"`
	}

	query := `
		SELECT
			s.id AS station_id,
			s.name AS station_name,
			EXISTS(SELECT 1 FROM fieldkit.provision WHERE device_id = s.device_id) AS has_provision,
			EXISTS(SELECT 1 FROM fieldkit.visible_configuration WHERE station_id = s.id) AS has_config,
			EXISTS(
				SELECT 1 FROM fieldkit.visible_configuration vc
				JOIN fieldkit.configuration_module cm ON (vc.configuration_id = cm.configuration_id)
				WHERE vc.station_id = s.id
			) AS has_module,
			EXISTS(
				SELECT 1 FROM fieldkit.visible_configuration vc
				JOIN fieldkit.configuration_module cm ON (vc.configuration_id = cm.configuration_id)
				JOIN fieldkit.station_module sm ON (cm.module_id = sm.id)
				JOIN fieldkit.module_sensor ms ON (ms.module_id = sm.id)
				WHERE vc.station_id = s.id
			) AS has_sensor,
			COUNT(DISTINCT vc.configuration_id) AS config_count,
			COUNT(DISTINCT cm.module_id) AS module_count,
			COUNT(DISTINCT ms.id) AS sensor_count,
			(SELECT id FROM fieldkit.ingestion WHERE device_id = s.device_id AND type = 'meta' ORDER BY time DESC LIMIT 1) AS meta_ingestion_id,
			(SELECT time::text FROM fieldkit.ingestion WHERE device_id = s.device_id AND type = 'meta' ORDER BY time DESC LIMIT 1) AS meta_ingestion_time
		FROM fieldkit.station AS s
		LEFT JOIN fieldkit.visible_configuration AS vc ON (vc.station_id = s.id)
		LEFT JOIN fieldkit.configuration_module AS cm ON (vc.configuration_id = cm.configuration_id)
		LEFT JOIN fieldkit.station_module AS sm ON (cm.module_id = sm.id)
		LEFT JOIN fieldkit.module_sensor AS ms ON (ms.module_id = sm.id)
	`

	args := []interface{}{}
	argIndex := 1
	if stationID > 0 {
		query += fmt.Sprintf(" WHERE s.id = $%d", argIndex)
		args = append(args, stationID)
		argIndex++
	}

	query += ` GROUP BY s.id, s.name ORDER BY s.id`

	rows := []StationDetailRow{}
	if err := db.SelectContext(ctx, &rows, query, args...); err != nil {
		log.Printf("⚠️  Failed to check station details: %v", err)
		return
	}

	if len(rows) == 0 {
		log.Println("❌ No stations found")
		return
	}

	log.Println("📋 Station Details:")
	log.Println(strings.Repeat("=", 80))

	for _, row := range rows {
		log.Printf("📍 Station %d: %s", row.StationID, row.StationName)
		
		if !row.HasProvision {
			log.Println("   ❌ Missing: provision")
		} else {
			log.Println("   ✅ Has: provision")
		}

		if !row.HasConfig {
			log.Println("   ❌ Missing: visible_configuration")
		} else {
			log.Printf("   ✅ Has: visible_configuration (%d config(s))", row.ConfigCount)
		}

		if !row.HasModule {
			log.Println("   ❌ Missing: station_module")
		} else {
			log.Printf("   ✅ Has: station_module (%d module(s))", row.ModuleCount)
		}

		if !row.HasSensor {
			log.Println("   ❌ Missing: module_sensor")
		} else {
			log.Printf("   ✅ Has: module_sensor (%d sensor(s))", row.SensorCount)
		}

		if row.MetaIngestionID != nil {
			log.Printf("   📦 Meta ingestion: ID=%d, Time=%s", 
				*row.MetaIngestionID, 
				stringValue(row.MetaIngestionTime))
			
			// Kiểm tra xem meta ingestion đã được xử lý chưa
			var hasConfigFromMeta bool
			checkQuery := `
				SELECT EXISTS(
					SELECT 1 FROM fieldkit.station_configuration sc
					JOIN fieldkit.provision p ON (sc.provision_id = p.id)
					WHERE p.device_id = (SELECT device_id FROM fieldkit.station WHERE id = $1)
					AND sc.meta_record_id IS NOT NULL
				)
			`
			if err := db.GetContext(ctx, &hasConfigFromMeta, checkQuery, row.StationID); err == nil {
				if !hasConfigFromMeta {
					log.Println("   ⚠️  Meta ingestion chưa được xử lý (chưa tạo station_configuration)")
					log.Println("   💡 Solution: Chạy ./bin/process_meta để trigger processing")
				} else {
					log.Println("   ✅ Meta ingestion đã được xử lý")
				}
			}
		} else {
			log.Println("   ⚠️  No meta ingestion found")
		}

		log.Println("")
	}
}

