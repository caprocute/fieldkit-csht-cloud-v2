package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	_ "github.com/lib/pq"

	"gitlab.com/fieldkit/cloud/server/common/logging"
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
)

type IngestionDebugInfo struct {
	StationID      int32     `db:"station_id"`
	StationName    string    `db:"station_name"`
	IngestionID    int64     `db:"ingestion_id"`
	IngestionType  string    `db:"ingestion_type"`
	IngestionTime  time.Time `db:"ingestion_time"`
	DeviceID       string    `db:"device_id"`
	UploadID       string    `db:"upload_id"`
	QueueID        *int64    `db:"queue_id"`
	Queued         *time.Time `db:"queued"`
	Attempted      *time.Time `db:"attempted"`
	Completed      *time.Time `db:"completed"`
	TotalRecords   *int64     `db:"total_records"`
	OtherErrors    *int64     `db:"other_errors"`
	MetaErrors     *int64     `db:"meta_errors"`
	DataErrors     *int64     `db:"data_errors"`
	StationIngestionID *int64 `db:"station_ingestion_id"`
	HasStationIngestion bool  `db:"has_station_ingestion"`
	Status         string    `db:"status"`
}

func main() {
	var (
		dbURL    = flag.String("db", "", "PostgreSQL connection URL (required)")
		stationID = flag.Int("station", 0, "Specific station ID to debug (0 = all stations)")
		verbose  = flag.Bool("verbose", false, "Show detailed information")
	)
	flag.Parse()

	if *dbURL == "" {
		fmt.Fprintf(os.Stderr, "Error: -db flag is required\n")
		flag.Usage()
		os.Exit(1)
	}

	// Khởi tạo logger
	logging.Configure(false, "ingestion_debug")

	ctx := context.Background()

	// Kết nối database
	db, err := sqlxcache.Open(ctx, "postgres", *dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	log.Println("🔍 Debugging Ingestion Processing...")
	if *stationID > 0 {
		log.Printf("   Station ID: %d\n", *stationID)
	} else {
		log.Println("   All stations")
	}
	log.Println("")

	// Query ingestion debug info
	query := `
		SELECT
			s.id AS station_id,
			s.name AS station_name,
			i.id AS ingestion_id,
			i.type AS ingestion_type,
			i.time AS ingestion_time,
			ENCODE(i.device_id, 'hex') AS device_id,
			i.upload_id,
			q.id AS queue_id,
			q.queued,
			q.attempted,
			q.completed,
			q.total_records,
			q.other_errors,
			q.meta_errors,
			q.data_errors,
			si.id AS station_ingestion_id,
			(si.id IS NOT NULL) AS has_station_ingestion,
			CASE
				WHEN i.type = 'meta' AND si.id IS NULL THEN 'ℹ️  Meta (no station_ingestion needed)'
				WHEN i.type = 'meta' AND q.id IS NULL THEN '⚠️  Meta (not queued)'
				WHEN i.type = 'data' AND si.id IS NOT NULL THEN '✅ Data Processed'
				WHEN i.type = 'data' AND q.completed IS NOT NULL THEN '⚠️  Data Completed but no station_ingestion'
				WHEN i.type = 'data' AND q.attempted IS NOT NULL THEN '🔄 Data In Progress'
				WHEN i.type = 'data' AND q.id IS NOT NULL THEN '⏳ Data Queued'
				WHEN i.type = 'data' THEN '❌ Data Not Queued'
				ELSE '❓ Unknown'
			END AS status
		FROM fieldkit.station AS s
		JOIN fieldkit.provision AS p ON (p.device_id = s.device_id)
		JOIN fieldkit.ingestion AS i ON (i.device_id = p.device_id)
		LEFT JOIN fieldkit.ingestion_queue AS q ON (q.ingestion_id = i.id)
		LEFT JOIN fieldkit.station_ingestion AS si ON (si.data_ingestion_id = i.id)
	`
	
	args := []interface{}{}
	argIndex := 1
	if *stationID > 0 {
		query += ` WHERE s.id = $` + fmt.Sprintf("%d", argIndex)
		args = append(args, *stationID)
		argIndex++
	}
	
	query += ` ORDER BY s.id, i.type, i.time DESC`

	rows := []IngestionDebugInfo{}
	if err := db.SelectContext(ctx, &rows, query, args...); err != nil {
		log.Fatalf("Failed to query ingestion debug info: %v", err)
	}

	if len(rows) == 0 {
		log.Println("❌ No ingestion records found")
		return
	}

	log.Printf("📊 Found %d ingestion records\n", len(rows))
	log.Println("")

	// Group by station
	currentStationID := int32(0)
	for _, row := range rows {
		if row.StationID != currentStationID {
			if currentStationID != 0 {
				log.Println("")
			}
			currentStationID = row.StationID
			log.Printf("📍 Station %d: %s", row.StationID, row.StationName)
			log.Println(strings.Repeat("-", 80))
		}

		log.Printf("  Ingestion ID: %d (%s)", row.IngestionID, row.IngestionType)
		log.Printf("    Time: %s", row.IngestionTime.Format(time.RFC3339))
		log.Printf("    Device ID: %s", row.DeviceID)
		log.Printf("    Upload ID: %s", row.UploadID)
		log.Printf("    Status: %s", row.Status)

		if row.QueueID != nil {
			log.Printf("    Queue ID: %d", *row.QueueID)
			if row.Queued != nil {
				log.Printf("    Queued: %s", row.Queued.Format(time.RFC3339))
			}
			if row.Attempted != nil {
				log.Printf("    Attempted: %s", row.Attempted.Format(time.RFC3339))
			}
			if row.Completed != nil {
				log.Printf("    Completed: %s", row.Completed.Format(time.RFC3339))
			}
			if row.TotalRecords != nil {
				log.Printf("    Total Records: %d", *row.TotalRecords)
			}
			if row.OtherErrors != nil && *row.OtherErrors > 0 {
				log.Printf("    ⚠️  Other Errors: %d", *row.OtherErrors)
			}
			if row.MetaErrors != nil && *row.MetaErrors > 0 {
				log.Printf("    ⚠️  Meta Errors: %d", *row.MetaErrors)
			}
			if row.DataErrors != nil && *row.DataErrors > 0 {
				log.Printf("    ⚠️  Data Errors: %d", *row.DataErrors)
			}
		} else {
			log.Printf("    ❌ NOT IN QUEUE - Ingestion chưa được thêm vào queue!")
		}

		if row.IngestionType == "meta" {
			// Meta ingestion không cần station_ingestion
			if row.HasStationIngestion {
				log.Printf("    ℹ️  Station Ingestion ID: %d (unexpected for meta)", *row.StationIngestionID)
			} else {
				log.Printf("    ℹ️  No Station Ingestion (normal for meta ingestion)")
			}
		} else {
			// Data ingestion cần station_ingestion
			if row.HasStationIngestion {
				log.Printf("    ✅ Station Ingestion ID: %d", *row.StationIngestionID)
			} else {
				log.Printf("    ❌ No Station Ingestion - Data ingestion chưa được xử lý!")
			}
		}

		if *verbose {
			// Kiểm tra chi tiết hơn
			if !row.HasStationIngestion && row.QueueID != nil {
				log.Printf("    🔍 Debugging...")
				
				// Kiểm tra xem có provision không
				var provisionCount int
				if err := db.GetContext(ctx, &provisionCount, `
					SELECT COUNT(*) FROM fieldkit.provision WHERE device_id = DECODE($1, 'hex')
				`, row.DeviceID); err == nil {
					log.Printf("      Provision count: %d", provisionCount)
				}

				// Kiểm tra xem có meta_record không (cho meta ingestion)
				if row.IngestionType == "meta" {
					var metaRecordCount int
					if err := db.GetContext(ctx, &metaRecordCount, `
						SELECT COUNT(*) FROM fieldkit.meta_record mr
						JOIN fieldkit.provision p ON (mr.provision_id = p.id)
						WHERE p.device_id = DECODE($1, 'hex')
					`, row.DeviceID); err == nil {
						log.Printf("      Meta Record count: %d", metaRecordCount)
					}
				}

				// Kiểm tra xem có data_record không (cho data ingestion)
				if row.IngestionType == "data" {
					var dataRecordCount int
					if err := db.GetContext(ctx, &dataRecordCount, `
						SELECT COUNT(*) FROM fieldkit.data_record dr
						JOIN fieldkit.provision p ON (dr.provision_id = p.id)
						WHERE p.device_id = DECODE($1, 'hex')
					`, row.DeviceID); err == nil {
						log.Printf("      Data Record count: %d", dataRecordCount)
					}
				}
			}
		}

		log.Println("")
	}

	// Tóm tắt
	log.Println(strings.Repeat("=", 80))
	log.Println("📊 Summary:")
	
	summary := make(map[string]int)
	for _, row := range rows {
		summary[row.Status]++
	}
	
	for status, count := range summary {
		log.Printf("  %s: %d", status, count)
	}
	
	// Đếm unprocessed (chỉ đếm data ingestion)
	unprocessedData := 0
	totalData := 0
	for _, row := range rows {
		if row.IngestionType == "data" {
			totalData++
			if !row.HasStationIngestion {
				unprocessedData++
			}
		}
	}
	
	if unprocessedData > 0 {
		log.Printf("\n⚠️  Unprocessed data ingestions: %d/%d", unprocessedData, totalData)
		log.Printf("   (Meta ingestions không cần station_ingestion, chỉ data ingestion mới cần)")
	} else if totalData > 0 {
		log.Printf("\n✅ All data ingestions processed!")
	}
	
	log.Println(strings.Repeat("=", 80))
}

