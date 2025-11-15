package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"

	_ "github.com/lib/pq"

	pb "gitlab.com/fieldkit/libraries/data-protocol"

	"gitlab.com/fieldkit/cloud/server/backend/handlers"
	"gitlab.com/fieldkit/cloud/server/backend/repositories"
	"gitlab.com/fieldkit/cloud/server/common/logging"
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
	"gitlab.com/fieldkit/cloud/server/data"
)

func main() {
	var (
		dbURL    = flag.String("db", "", "PostgreSQL connection URL (required)")
		stationID = flag.Int("station", 0, "Station ID to fix (0 = fix all stations)")
	)
	flag.Parse()

	if *dbURL == "" {
		fmt.Fprintf(os.Stderr, "Error: -db flag is required\n")
		flag.Usage()
		os.Exit(1)
	}

	// Khởi tạo logger
	logging.Configure(false, "fix_meta_processing")

	ctx := context.Background()

	// Kết nối database
	db, err := sqlxcache.Open(ctx, "postgres", *dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	log.Println("🔧 Fixing meta processing for stations...")
	if *stationID > 0 {
		log.Printf("   Fixing station ID: %d\n", *stationID)
	} else {
		log.Println("   Fixing all stations")
	}
	log.Println("")

	// Query meta_records chưa có station_configuration
	query := `
		SELECT DISTINCT
			mr.id AS meta_record_id,
			mr.provision_id,
			mr.raw::text AS raw,
			mr.pb,
			s.id AS station_id,
			s.name AS station_name,
			p.device_id,
			EXISTS(
				SELECT 1 FROM fieldkit.station_configuration sc
				WHERE sc.provision_id = mr.provision_id
				AND sc.meta_record_id = mr.id
			) AS has_configuration
		FROM fieldkit.meta_record AS mr
		JOIN fieldkit.provision AS p ON (mr.provision_id = p.id)
		JOIN fieldkit.station AS s ON (s.device_id = p.device_id)
		WHERE NOT EXISTS(
			SELECT 1 FROM fieldkit.station_configuration sc
			WHERE sc.provision_id = mr.provision_id
			AND sc.meta_record_id = mr.id
		)
	`

	args := []interface{}{}
	argIndex := 1
	if *stationID > 0 {
		query += fmt.Sprintf(" AND s.id = $%d", argIndex)
		args = append(args, *stationID)
		argIndex++
	}

	query += ` ORDER BY s.id, mr.id`

	type MetaRecordRow struct {
		MetaRecordID   int64  `db:"meta_record_id"`
		ProvisionID    int64  `db:"provision_id"`
		Raw            string `db:"raw"`
		PB             []byte `db:"pb"`
		StationID      int32  `db:"station_id"`
		StationName    string `db:"station_name"`
		DeviceID       []byte `db:"device_id"`
		HasConfiguration bool `db:"has_configuration"`
	}

	rows := []MetaRecordRow{}
	if err := db.SelectContext(ctx, &rows, query, args...); err != nil {
		log.Fatalf("Failed to query meta records: %v", err)
	}

	if len(rows) == 0 {
		log.Println("✅ No unprocessed meta records found")
		return
	}

	log.Printf("📊 Found %d unprocessed meta records\n", len(rows))
	log.Println("")

	// Load repositories
	stationRepo := repositories.NewStationRepository(db)
	handler := handlers.NewStationModelRecordHandler(db)

	successCount := 0
	failCount := 0

	for _, row := range rows {
		log.Printf("🔧 Processing meta_record ID=%d for station %d (%s)...", 
			row.MetaRecordID, row.StationID, row.StationName)

		// Load provision
		var provision data.Provision
		if err := db.GetContext(ctx, &provision, `SELECT * FROM fieldkit.provision WHERE id = $1`, row.ProvisionID); err != nil {
			log.Printf("    ❌ Failed to load provision: %v", err)
			failCount++
			continue
		}

		// Load meta_record
		var metaRecord data.MetaRecord
		if err := db.GetContext(ctx, &metaRecord, `SELECT * FROM fieldkit.meta_record WHERE id = $1`, row.MetaRecordID); err != nil {
			log.Printf("    ❌ Failed to load meta_record: %v", err)
			failCount++
			continue
		}

		// Unmarshal raw JSON để extract metadata.modules
		var rawData map[string]interface{}
		if err := json.Unmarshal([]byte(row.Raw), &rawData); err != nil {
			log.Printf("    ❌ Failed to unmarshal raw JSON: %v", err)
			failCount++
			continue
		}

		// Extract metadata.modules
		var modules []*pb.ModuleInfo
		if metadata, ok := rawData["metadata"].(map[string]interface{}); ok {
			if modulesData, ok := metadata["modules"].([]interface{}); ok {
				// Convert []interface{} to []*pb.ModuleInfo
				modulesJSON, err := json.Marshal(modulesData)
				if err != nil {
					log.Printf("    ❌ Failed to marshal modules: %v", err)
					failCount++
					continue
				}
				if err := json.Unmarshal(modulesJSON, &modules); err != nil {
					log.Printf("    ❌ Failed to unmarshal modules: %v", err)
					failCount++
					continue
				}
			}
		}

		if len(modules) == 0 {
			log.Printf("    ⚠️  No modules found in metadata")
			failCount++
			continue
		}

		// Tạo rawMeta với Modules field
		rawMeta := &pb.DataRecord{
			Modules: modules,
		}

		// Gọi handler OnMeta
		if err := handler.OnMeta(ctx, &provision, rawMeta, &metaRecord); err != nil {
			log.Printf("    ❌ Failed to process meta: %v", err)
			failCount++
			continue
		}

		// Query configuration vừa tạo
		configuration, err := stationRepo.QueryStationConfigurationByMetaID(ctx, metaRecord.ID)
		if err != nil {
			log.Printf("    ⚠️  Failed to query configuration: %v", err)
		} else if configuration != nil {
			// Set visible configuration
			if err := stationRepo.UpsertVisibleConfiguration(ctx, row.StationID, configuration.ID); err != nil {
				log.Printf("    ⚠️  Failed to set visible configuration: %v", err)
			} else {
				log.Printf("    ✅ Created configuration (ID: %d) and set as visible", configuration.ID)
			}
		}

		successCount++
		log.Println("")
	}

	log.Println("")
	log.Printf("📊 Summary: %d succeeded, %d failed", successCount, failCount)
}

