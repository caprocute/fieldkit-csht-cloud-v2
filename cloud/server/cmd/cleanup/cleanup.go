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
		dbURL   = flag.String("db", "", "PostgreSQL connection URL (required)")
		confirm = flag.Bool("confirm", false, "Confirm deletion (required for safety)")
	)
	flag.Parse()

	if *dbURL == "" {
		fmt.Fprintf(os.Stderr, "Error: -db flag is required\n")
		flag.Usage()
		os.Exit(1)
	}

	if !*confirm {
		fmt.Fprintf(os.Stderr, "❌ ERROR: This will delete ALL users and ALL related data!\n")
		fmt.Fprintf(os.Stderr, "   Use -confirm flag to proceed\n")
		os.Exit(1)
	}

	// Khởi tạo logger
	logging.Configure(false, "cleanup")

	ctx := context.Background()

	// Kết nối database
	db, err := sqlxcache.Open(ctx, "postgres", *dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	log.Println("⚠️  WARNING: This will delete ALL users and ALL related data!")
	log.Println("")

	// Lấy danh sách tất cả user IDs trước khi xóa
	var userIDs []int32
	if err := db.SelectContext(ctx, &userIDs, `SELECT id FROM fieldkit.user ORDER BY id`); err != nil {
		log.Fatalf("Failed to query user IDs: %v", err)
	}

	if len(userIDs) == 0 {
		log.Println("No users found to delete")
		return
	}

	log.Printf("Found %d users to delete", len(userIDs))
	log.Println("")

	// Xóa tất cả dữ liệu liên quan đến users
	// Thứ tự xóa quan trọng để tránh vi phạm foreign key constraints
	queries := []struct {
		name  string
		query string
	}{
		// 1. Xóa project invites và followers
		{"project_invite", `DELETE FROM fieldkit.project_invite`},
		{"project_follower", `DELETE FROM fieldkit.project_follower`},
		{"project_user", `DELETE FROM fieldkit.project_user`},

		// 2. Xóa notes và media (phải xóa links trước)
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

		// 3. Xóa data events và exports
		{"data_event", `DELETE FROM fieldkit.data_event WHERE user_id IN (SELECT id FROM fieldkit.user)`},
		{"data_export", `DELETE FROM fieldkit.data_export WHERE user_id IN (SELECT id FROM fieldkit.user)`},

		// 4. Xóa discussion posts và moderation requests
		{"moderation_request (reported_by)", `DELETE FROM fieldkit.moderation_request WHERE reported_by IN (SELECT id FROM fieldkit.user)`},
		{"moderation_request (acknowledged_by)", `UPDATE fieldkit.moderation_request SET acknowledged_by = NULL WHERE acknowledged_by IN (SELECT id FROM fieldkit.user)`},
		{"discussion_post", `DELETE FROM fieldkit.discussion_post WHERE user_id IN (SELECT id FROM fieldkit.user)`},

		// 5. Xóa project updates
		{"project_update", `DELETE FROM fieldkit.project_update WHERE author_id IN (SELECT id FROM fieldkit.user)`},

		// 6. Xóa bookmarks (sửa tên bảng thành bookmarks)
		{"bookmarks", `DELETE FROM fieldkit.bookmarks WHERE user_id IN (SELECT id FROM fieldkit.user)`},

		// 7. Xóa station notes
		{"station_note", `DELETE FROM fieldkit.station_note WHERE user_id IN (SELECT id FROM fieldkit.user)`},

		// 8. Xóa TTN schema
		{"ttn_schema", `DELETE FROM fieldkit.ttn_schema WHERE owner_id IN (SELECT id FROM fieldkit.user)`},

		// 9. Xóa moderator
		{"moderator", `DELETE FROM fieldkit.moderator WHERE user_id IN (SELECT id FROM fieldkit.user)`},

		// 10. Xóa station-related data (phải xóa theo thứ tự)
		// 10.1. Xóa sensor data (TSDB - TimeScaleDB)
		{"sensor_data", `DELETE FROM fieldkit.sensor_data WHERE station_id IN (SELECT id FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user))`},

		// 10.2. Xóa module_sensor (phải xóa trước station_module)
		{"module_sensor", `DELETE FROM fieldkit.module_sensor WHERE module_id IN (SELECT sm.id FROM fieldkit.station_module sm JOIN fieldkit.configuration_module cm ON (sm.id = cm.module_id) JOIN fieldkit.station_configuration sc ON (cm.configuration_id = sc.id) JOIN fieldkit.provision p ON (sc.provision_id = p.id) JOIN fieldkit.station s ON (p.device_id = s.device_id) WHERE s.owner_id IN (SELECT id FROM fieldkit.user))`},

		// 10.3. Xóa configuration_module
		{"configuration_module", `DELETE FROM fieldkit.configuration_module WHERE configuration_id IN (SELECT sc.id FROM fieldkit.station_configuration sc JOIN fieldkit.provision p ON (sc.provision_id = p.id) JOIN fieldkit.station s ON (p.device_id = s.device_id) WHERE s.owner_id IN (SELECT id FROM fieldkit.user))`},

		// 10.4. Xóa station_module
		{"station_module", `DELETE FROM fieldkit.station_module WHERE id IN (SELECT sm.id FROM fieldkit.station_module sm JOIN fieldkit.configuration_module cm ON (sm.id = cm.module_id) JOIN fieldkit.station_configuration sc ON (cm.configuration_id = sc.id) JOIN fieldkit.provision p ON (sc.provision_id = p.id) JOIN fieldkit.station s ON (p.device_id = s.device_id) WHERE s.owner_id IN (SELECT id FROM fieldkit.user))`},

		// 10.5. Xóa visible_configuration TRƯỚC station_configuration (để tránh foreign key constraint)
		{"visible_configuration", `DELETE FROM fieldkit.visible_configuration WHERE station_id IN (SELECT id FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user))`},

		// 10.6. Xóa station_configuration (sau khi đã xóa visible_configuration)
		{"station_configuration", `DELETE FROM fieldkit.station_configuration WHERE provision_id IN (SELECT p.id FROM fieldkit.provision p JOIN fieldkit.station s ON (p.device_id = s.device_id) WHERE s.owner_id IN (SELECT id FROM fieldkit.user))`},

		// 10.7. Xóa data_record (liên quan đến provision)
		{"data_record", `DELETE FROM fieldkit.data_record WHERE provision_id IN (SELECT p.id FROM fieldkit.provision p JOIN fieldkit.station s ON (p.device_id = s.device_id) WHERE s.owner_id IN (SELECT id FROM fieldkit.user))`},

		// 10.8. Xóa meta_record (liên quan đến provision)
		{"meta_record", `DELETE FROM fieldkit.meta_record WHERE provision_id IN (SELECT p.id FROM fieldkit.provision p JOIN fieldkit.station s ON (p.device_id = s.device_id) WHERE s.owner_id IN (SELECT id FROM fieldkit.user))`},

		// 10.9. Xóa project_station
		{"project_station", `DELETE FROM fieldkit.project_station WHERE station_id IN (SELECT id FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user))`},

		// 10.10. Xóa station_activity
		{"station_activity", `DELETE FROM fieldkit.station_activity WHERE station_id IN (SELECT id FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user))`},

		// 10.11. Xóa station_ingestion
		{"station_ingestion", `DELETE FROM fieldkit.station_ingestion WHERE uploader_id IN (SELECT id FROM fieldkit.user)`},

		// 10.12. Xóa station photo reference
		{"station photo", `UPDATE fieldkit.station SET photo_id = NULL WHERE owner_id IN (SELECT id FROM fieldkit.user)`},

		// 11. Xóa ingestion queue và ingestion
		{"ingestion_queue", `DELETE FROM fieldkit.ingestion_queue WHERE ingestion_id IN (SELECT id FROM fieldkit.ingestion WHERE user_id IN (SELECT id FROM fieldkit.user))`},
		{"ingestion", `DELETE FROM fieldkit.ingestion WHERE user_id IN (SELECT id FROM fieldkit.user)`},

		// 12. Xóa provision (sau khi đã xóa meta_record, data_record, station_configuration)
		{"provision", `DELETE FROM fieldkit.provision WHERE device_id IN (SELECT device_id FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user))`},

		// 13. Xóa station (sau khi đã xóa tất cả dữ liệu liên quan)
		{"station", `DELETE FROM fieldkit.station WHERE owner_id IN (SELECT id FROM fieldkit.user)`},

		// 14. Xóa project (sau khi đã xóa project_user, project_station)
		{"project", `DELETE FROM fieldkit.project WHERE id NOT IN (SELECT DISTINCT project_id FROM fieldkit.project_user WHERE project_id IS NOT NULL)`},

		// 15. Xóa tokens
		{"recovery_token", `DELETE FROM fieldkit.recovery_token WHERE user_id IN (SELECT id FROM fieldkit.user)`},
		{"validation_token", `DELETE FROM fieldkit.validation_token WHERE user_id IN (SELECT id FROM fieldkit.user)`},
		{"refresh_token", `DELETE FROM fieldkit.refresh_token WHERE user_id IN (SELECT id FROM fieldkit.user)`},

		// 16. Xóa notifications
		{"notification", `DELETE FROM fieldkit.notification WHERE user_id IN (SELECT id FROM fieldkit.user)`},

		// 17. Cuối cùng xóa users
		{"user", `DELETE FROM fieldkit.user`},
	}

	totalDeleted := 0
	for _, q := range queries {
		log.Printf("Deleting %s...", q.name)
		result, err := db.ExecContext(ctx, q.query)
		if err != nil {
			log.Fatalf("❌ Failed to delete %s: %v", q.name, err)
		}
		rowsAffected, _ := result.RowsAffected()
		if rowsAffected > 0 {
			log.Printf("  ✅ Deleted %d rows from %s", rowsAffected, q.name)
			totalDeleted += int(rowsAffected)
		} else {
			log.Printf("  ℹ️  No rows to delete from %s", q.name)
		}
	}

	log.Println("")
	log.Println(strings.Repeat("=", 60))
	log.Printf("✅ Successfully deleted all %d users and their associated data", len(userIDs))
	log.Printf("   Total rows deleted: %d", totalDeleted)
	log.Println(strings.Repeat("=", 60))
}

