package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"

	_ "github.com/lib/pq"

	"gitlab.com/fieldkit/cloud/server/common/logging"
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
)

func main() {
	var (
		dbURL    = flag.String("db", "", "PostgreSQL connection URL (required)")
		stationID = flag.Int("station", 0, "Station ID to check (0 = check all stations)")
	)
	flag.Parse()

	if *dbURL == "" {
		fmt.Fprintf(os.Stderr, "Error: -db flag is required\n")
		flag.Usage()
		os.Exit(1)
	}

	logging.Configure(false, "check_station_sensors")

	ctx := context.Background()

	db, err := sqlxcache.Open(ctx, "postgres", *dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	log.Println("🔍 Checking station sensors and data...")
	if *stationID > 0 {
		log.Printf("   Station ID: %d\n", *stationID)
	} else {
		log.Println("   All stations")
	}
	log.Println("")

	// Query 1: Check station configuration and sensors
	type StationSensorRow struct {
		StationID     int32  `db:"station_id"`
		StationName   string `db:"station_name"`
		ModuleID      int64  `db:"module_id"`
		ModuleName    string `db:"module_name"`
		SensorIndex   int32  `db:"sensor_index"`
		SensorName    string `db:"sensor_name"`
		SensorKey     string `db:"sensor_key"`
		SensorInternal bool  `db:"sensor_internal"`
		ConfigID      int64  `db:"config_id"`
		VisibleConfigID *int64 `db:"visible_config_id"`
	}

	query := `
		SELECT
			s.id AS station_id,
			s.name AS station_name,
			sm.id AS module_id,
			sm.name AS module_name,
			ms.sensor_index,
			ms.name AS sensor_name,
			ms.key AS sensor_key,
			sm_internal.internal AS sensor_internal,
			sc.id AS config_id,
			vc.configuration_id AS visible_config_id
		FROM fieldkit.station AS s
		JOIN fieldkit.provision AS p ON (s.device_id = p.device_id)
		JOIN fieldkit.station_configuration AS sc ON (p.id = sc.provision_id)
		JOIN fieldkit.station_module AS sm ON (sc.id = sm.configuration_id)
		JOIN fieldkit.module_sensor AS ms ON (sm.id = ms.module_id)
		LEFT JOIN fieldkit.sensor_meta AS sm_internal ON (ms.key = sm_internal.full_key)
		LEFT JOIN fieldkit.visible_configuration AS vc ON (s.id = vc.station_id)
	`
	args := []interface{}{}
	argIndex := 1
	if *stationID > 0 {
		query += fmt.Sprintf(" WHERE s.id = $%d", argIndex)
		args = append(args, *stationID)
		argIndex++
	}
	query += ` ORDER BY s.id, sm.id, ms.sensor_index`

	rows := []StationSensorRow{}
	if err := db.SelectContext(ctx, &rows, query, args...); err != nil {
		log.Fatalf("Failed to query station sensors: %v", err)
	}

	if len(rows) == 0 {
		log.Println("❌ No sensors found for station(s)")
		return
	}

	// Group by station
	stationsMap := make(map[int32][]StationSensorRow)
	for _, row := range rows {
		stationsMap[row.StationID] = append(stationsMap[row.StationID], row)
	}

	for stationID, sensors := range stationsMap {
		log.Printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		log.Printf("📍 Station ID: %d (%s)", stationID, sensors[0].StationName)
		if sensors[0].VisibleConfigID != nil {
			log.Printf("   ✅ Visible Configuration: %d", *sensors[0].VisibleConfigID)
		} else {
			log.Printf("   ❌ No visible configuration")
		}
		log.Printf("   📊 Total sensors: %d", len(sensors))
		log.Println("")

		// Check sensor data in TSDB
		type SensorDataRow struct {
			SensorKey string  `db:"sensor_key"`
			Count     int64   `db:"count"`
			MinTime   *string `db:"min_time"`
			MaxTime   *string `db:"max_time"`
		}

		sensorKeys := make([]string, 0, len(sensors))
		for _, s := range sensors {
			sensorKeys = append(sensorKeys, s.SensorKey)
		}

		dataQuery := `
			SELECT
				ms.key AS sensor_key,
				COUNT(sd.value) AS count,
				MIN(sd.time)::text AS min_time,
				MAX(sd.time)::text AS max_time
			FROM fieldkit.sensor_data AS sd
			JOIN fieldkit.station_module AS sm ON (sd.module_id = sm.id)
			JOIN fieldkit.module_sensor AS ms ON (sm.id = ms.module_id AND sd.sensor_id = ms.sensor_index)
			WHERE sd.station_id = $1
			GROUP BY ms.key
			ORDER BY ms.key
		`

		dataRows := []SensorDataRow{}
		if err := db.SelectContext(ctx, &dataRows, dataQuery, stationID); err != nil {
			log.Printf("   ⚠️  Failed to query sensor data: %v", err)
		}

		dataMap := make(map[string]SensorDataRow)
		for _, dr := range dataRows {
			dataMap[dr.SensorKey] = dr
		}

		// Display sensors
		for _, sensor := range sensors {
			internalStatus := "✅"
			if sensor.SensorInternal {
				internalStatus = "❌ INTERNAL"
			}

			dataInfo := "❌ No data"
			if data, ok := dataMap[sensor.SensorKey]; ok {
				if data.Count > 0 {
					dataInfo = fmt.Sprintf("✅ %d records (from %s to %s)", data.Count, 
						func() string {
							if data.MinTime != nil {
								return *data.MinTime
							}
							return "N/A"
						}(),
						func() string {
							if data.MaxTime != nil {
								return *data.MaxTime
							}
							return "N/A"
						}())
				}
			}

			log.Printf("   Sensor %d: %s (%s) %s | %s", 
				sensor.SensorIndex, sensor.SensorName, sensor.SensorKey, internalStatus, dataInfo)
		}

		log.Println("")
	}

	// Summary
	log.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	log.Printf("📊 Summary: Checked %d station(s), %d total sensors", len(stationsMap), len(rows))
}

