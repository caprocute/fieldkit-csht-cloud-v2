package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	_ "github.com/lib/pq"
	"gitlab.com/fieldkit/cloud/server/backend/repositories"
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
	"gitlab.com/fieldkit/cloud/server/data"
)

func main() {
	var (
		dbURL     = flag.String("db", "", "PostgreSQL connection URL (required)")
		stationID = flag.Int("station-id", 0, "Station ID to check (required)")
	)
	flag.Parse()

	if *dbURL == "" {
		fmt.Fprintf(os.Stderr, "Error: -db flag is required\n")
		flag.Usage()
		os.Exit(1)
	}

	if *stationID == 0 {
		fmt.Fprintf(os.Stderr, "Error: -station-id flag is required\n")
		flag.Usage()
		os.Exit(1)
	}

	ctx := context.Background()
	db, err := sqlxcache.Open(ctx, "postgres", *dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	stationRepo := repositories.NewStationRepository(db)

	// 1. Kiểm tra station có tồn tại không
	log.Printf("🔍 Checking station ID: %d", *stationID)
	station, err := stationRepo.QueryStationByID(ctx, int32(*stationID))
	if err != nil {
		log.Printf("❌ Station %d NOT FOUND in database: %v", *stationID, err)
		os.Exit(1)
	}
	log.Printf("✅ Station found: %s (ID: %d)", station.Name, station.ID)

	// 2. Kiểm tra provision
	provisions := []*data.Provision{}
	if err := db.SelectContext(ctx, &provisions, `
		SELECT id, created, updated, generation, device_id
		FROM fieldkit.provision
		WHERE device_id = $1
		ORDER BY updated DESC
	`, station.DeviceID); err != nil {
		log.Printf("⚠️  Warning: Failed to query provision: %v", err)
	} else if len(provisions) == 0 {
		log.Printf("⚠️  Warning: No provision found for station")
	} else {
		log.Printf("✅ Found %d provision(s) for station", len(provisions))
		for i, p := range provisions {
			log.Printf("   Provision %d: ID=%d, Generation=%s, Updated=%s",
				i+1, p.ID, fmt.Sprintf("%x", p.GenerationID)[:16], p.Updated.Format("2006-01-02 15:04:05"))
		}
	}

	// 3. Kiểm tra meta records
	if len(provisions) > 0 {
		provision := provisions[0]
		metaRecords := []*data.MetaRecord{}
		if err := db.SelectContext(ctx, &metaRecords, `
			SELECT id, provision_id, time, number, raw, pb
			FROM fieldkit.meta_record
			WHERE provision_id = $1
			ORDER BY number DESC
		`, provision.ID); err != nil {
			log.Printf("⚠️  Warning: Failed to query meta records: %v", err)
		} else if len(metaRecords) == 0 {
			log.Printf("⚠️  Warning: No meta records found for station")
		} else {
			log.Printf("✅ Found %d meta record(s) for station", len(metaRecords))
			for i, mr := range metaRecords {
				log.Printf("   Meta Record %d: ID=%d, Number=%d, Time=%s",
					i+1, mr.ID, mr.Number, mr.Time.Format("2006-01-02 15:04:05"))
			}
		}
	}

	// 4. Kiểm tra visible_configuration
	var visibleConfigID *int64
	if err := db.GetContext(ctx, &visibleConfigID, `
		SELECT configuration_id FROM fieldkit.visible_configuration WHERE station_id = $1
	`, station.ID); err != nil {
		if err == sql.ErrNoRows {
			log.Printf("❌ CRITICAL: No visible_configuration found for station!")
			log.Printf("   This will cause the API to return empty configurations array")
			log.Printf("   Frontend may show 'Oh snap, this station doesn't appear to have any sensors to show you.'")
		} else {
			log.Printf("⚠️  Warning: Failed to query visible_configuration: %v", err)
		}
	} else {
		log.Printf("✅ Found visible_configuration: configuration_id=%d", *visibleConfigID)
	}

	// 5. Kiểm tra tất cả configurations
	allConfigurations := []struct {
		ID           int64     `db:"id"`
		ProvisionID  int64     `db:"provision_id"`
		MetaRecordID *int64    `db:"meta_record_id"`
		UpdatedAt    time.Time `db:"updated_at"`
	}{}
	if err := db.SelectContext(ctx, &allConfigurations, `
		SELECT id, provision_id, meta_record_id, updated_at
		FROM fieldkit.station_configuration
		WHERE provision_id IN (SELECT id FROM fieldkit.provision WHERE device_id = $1)
		ORDER BY updated_at DESC
	`, station.DeviceID); err != nil {
		log.Printf("⚠️  Warning: Failed to query all configurations: %v", err)
	} else {
		log.Printf("📋 Found %d configuration(s) for station", len(allConfigurations))
		for i, cfg := range allConfigurations {
			isVisible := visibleConfigID != nil && *visibleConfigID == cfg.ID
			marker := "  "
			if isVisible {
				marker = "✅"
			}
			log.Printf("   %s Configuration %d: ID=%d, ProvisionID=%d, MetaRecordID=%v, Updated=%s",
				marker, i+1, cfg.ID, cfg.ProvisionID, cfg.MetaRecordID, cfg.UpdatedAt.Format("2006-01-02 15:04:05"))
		}
		if len(allConfigurations) > 0 && visibleConfigID == nil {
			log.Printf("⚠️  Warning: Station has %d configuration(s) but no visible_configuration is set!", len(allConfigurations))
			log.Printf("   Recommendation: Set visible_configuration to configuration ID %d", allConfigurations[0].ID)
		}
	}

	// 6. Kiểm tra configuration chi tiết (nếu có visible_configuration)
	configuration, provisionFromConfig, err := stationRepo.QueryVisibleConfiguration(ctx, station.ID)
	if err != nil {
		if err.Error() == "no visible configuration for station" {
			log.Printf("❌ CRITICAL: QueryVisibleConfiguration returned 'no visible configuration for station'")
		} else {
			log.Printf("⚠️  Warning: QueryVisibleConfiguration failed: %v", err)
		}
	} else if configuration == nil {
		log.Printf("⚠️  Warning: QueryVisibleConfiguration returned nil configuration")
	} else {
		log.Printf("✅ QueryVisibleConfiguration succeeded: ID=%d, MetaRecordID=%d, ProvisionID=%d",
			configuration.ID, *configuration.MetaRecordID, configuration.ProvisionID)
		if provisionFromConfig != nil {
			log.Printf("   Provision: ID=%d, Generation=%s",
				provisionFromConfig.ID, fmt.Sprintf("%x", provisionFromConfig.GenerationID)[:16])
		}
	}

	// 7. Kiểm tra modules và sensors
	if configuration != nil {
		modules, err := stationRepo.QueryStationModulesByConfigurationID(ctx, configuration.ID)
		if err != nil {
			log.Printf("⚠️  Warning: Failed to query modules: %v", err)
		} else if len(modules) == 0 {
			log.Printf("⚠️  Warning: No modules found for station")
		} else {
			log.Printf("✅ Found %d module(s) for station", len(modules))
			for i, m := range modules {
				log.Printf("   Module %d: ID=%d, Name=%s, HardwareID=%s, Manufacturer=%d, Kind=%d",
					i+1, m.ID, m.Name, fmt.Sprintf("%x", m.HardwareID)[:16], m.Manufacturer, m.Kind)
			}
		}
	}

	// 8. Kiểm tra projects
	projectStations := []*data.ProjectStation{}
	if err := db.SelectContext(ctx, &projectStations, `
		SELECT ps.project_id, ps.station_id
		FROM fieldkit.project_station AS ps
		WHERE ps.station_id = $1
	`, station.ID); err != nil {
		log.Printf("⚠️  Warning: Failed to query projects: %v", err)
	} else if len(projectStations) == 0 {
		log.Printf("⚠️  Warning: Station is not in any project")
	} else {
		log.Printf("✅ Station is in %d project(s)", len(projectStations))
		for i, ps := range projectStations {
			log.Printf("   Project %d: ID=%d", i+1, ps.ProjectID)
		}
	}

	// 9. Kiểm tra owner
	userRepo := repositories.NewUserRepository(db)
	owner, err := userRepo.QueryByID(ctx, station.OwnerID)
	if err != nil {
		log.Printf("⚠️  Warning: Failed to query owner: %v", err)
	} else {
		log.Printf("✅ Station owner: %s (ID: %d, Email: %s, Admin: %v)",
			owner.Name, owner.ID, owner.Email, owner.Admin)
	}

	// 10. Tóm tắt
	log.Printf("\n📋 Summary:")
	log.Printf("   Station ID: %d", station.ID)
	log.Printf("   Station Name: %s", station.Name)
	log.Printf("   Device ID: %s", fmt.Sprintf("%x", station.DeviceID))
	log.Printf("   Owner ID: %d", station.OwnerID)
	log.Printf("   Hidden: %v", station.Hidden)
	if station.Location != nil {
		log.Printf("   Location: %.6f, %.6f", station.Location.Longitude(), station.Location.Latitude())
	} else {
		log.Printf("   Location: <nil>")
	}

	// 11. Endpoint đúng và khuyến nghị
	log.Printf("\n🌐 Correct API Endpoint:")
	log.Printf("   GET /stations/%d", station.ID)
	log.Printf("   (NOT /station/%d)", station.ID)

	// 12. Khuyến nghị sửa lỗi
	if visibleConfigID == nil && len(allConfigurations) > 0 {
		log.Printf("\n🔧 RECOMMENDED FIX:")
		log.Printf("   Run this SQL to set visible_configuration:")
		log.Printf("   INSERT INTO fieldkit.visible_configuration (station_id, configuration_id)")
		log.Printf("   VALUES (%d, %d)", station.ID, allConfigurations[0].ID)
		log.Printf("   ON CONFLICT (station_id) DO UPDATE SET configuration_id = EXCLUDED.configuration_id;")
	}
}
