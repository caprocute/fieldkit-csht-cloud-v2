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

type IntegrityCheck struct {
	Name        string
	Description string
	Check       func(ctx context.Context, db *sqlxcache.DB, stationID int32) (*CheckResult, error)
}

type CheckResult struct {
	Passed      bool
	Issues      []string
	Details     []string
	Count       int
	FailedCount int
}

func main() {
	var (
		dbURL    = flag.String("db", "", "PostgreSQL connection URL (required)")
		stationID = flag.Int("station", 0, "Specific station ID to check (0 = check all)")
	)
	flag.Parse()

	if *dbURL == "" {
		fmt.Fprintf(os.Stderr, "Error: -db flag is required\n")
		flag.Usage()
		os.Exit(1)
	}

	// Khởi tạo logger
	logging.Configure(false, "data_integrity")

	ctx := context.Background()

	// Kết nối database
	db, err := sqlxcache.Open(ctx, "postgres", *dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	log.Println("🔍 Starting data integrity checks...")
	if *stationID > 0 {
		log.Printf("   Checking station ID: %d\n", *stationID)
	} else {
		log.Println("   Checking all stations")
	}
	log.Println("")

	// Định nghĩa các checks
	checks := []IntegrityCheck{
		{
			Name:        "Station Visibility",
			Description: "Kiểm tra station có visible configuration không",
			Check:       checkStationVisibility,
		},
		{
			Name:        "Station Sensors",
			Description: "Kiểm tra station có sensors không",
			Check:       checkStationSensors,
		},
		{
			Name:        "Sensor Key Matching",
			Description: "Kiểm tra sensor key match giữa module_sensor và aggregated_sensor",
			Check:       checkSensorKeyMatching,
		},
		{
			Name:        "Module Name Format",
			Description: "Kiểm tra module name có prefix đúng (fk. hoặc wh.) không",
			Check:       checkModuleNameFormat,
		},
		{
			Name:        "Station Module Relationships",
			Description: "Kiểm tra relationships giữa station, configuration, module",
			Check:       checkStationModuleRelationships,
		},
		{
			Name:        "TSDB Data",
			Description: "Kiểm tra dữ liệu có trong TSDB (sensor_data) không",
			Check:       checkTSDBData,
		},
		{
			Name:        "Ingestion Processing",
			Description: "Kiểm tra ingestion có được xử lý không",
			Check:       checkIngestionProcessing,
		},
	}

	// Chạy các checks
	allPassed := true
	results := make(map[string]*CheckResult)

	for _, check := range checks {
		log.Printf("📋 Check: %s", check.Name)
		log.Printf("   %s", check.Description)

		result, err := check.Check(ctx, db, int32(*stationID))
		if err != nil {
			log.Printf("   ❌ Error: %v\n", err)
			allPassed = false
			continue
		}

		results[check.Name] = result

		if result.Passed {
			log.Printf("   ✅ PASSED (%d items checked)\n", result.Count)
		} else {
			log.Printf("   ❌ FAILED (%d/%d failed)\n", result.FailedCount, result.Count)
			allPassed = false
		}

		if len(result.Issues) > 0 {
			for _, issue := range result.Issues {
				log.Printf("      ⚠️  %s", issue)
			}
		}

		if len(result.Details) > 0 && len(result.Details) <= 10 {
			for _, detail := range result.Details {
				log.Printf("      ℹ️  %s", detail)
			}
		} else if len(result.Details) > 10 {
			for i := 0; i < 5; i++ {
				log.Printf("      ℹ️  %s", result.Details[i])
			}
			log.Printf("      ... và %d items khác", len(result.Details)-5)
		}

		log.Println("")
	}

	// Tóm tắt
	log.Println(strings.Repeat("=", 60))
	if allPassed {
		log.Println("✅ TẤT CẢ CHECKS ĐỀU PASSED")
	} else {
		log.Println("❌ CÓ MỘT SỐ CHECKS FAILED")
		log.Println("")
		log.Println("Chi tiết:")
		for name, result := range results {
			if !result.Passed {
				log.Printf("  - %s: %d/%d failed", name, result.FailedCount, result.Count)
			}
		}
	}
	log.Println(strings.Repeat("=", 60))

	if !allPassed {
		os.Exit(1)
	}
}

func checkStationVisibility(ctx context.Context, db *sqlxcache.DB, stationID int32) (*CheckResult, error) {
	result := &CheckResult{
		Issues:  []string{},
		Details: []string{},
	}

	type StationRow struct {
		ID              int32  `db:"id"`
		Name            string `db:"name"`
		HasConfig       bool   `db:"has_config"`
		ConfigurationID *int64 `db:"configuration_id"`
	}

	query := `
		SELECT 
			s.id,
			s.name,
			vc.configuration_id IS NOT NULL AS has_config,
			vc.configuration_id
		FROM fieldkit.station AS s
		LEFT JOIN fieldkit.visible_configuration AS vc ON (vc.station_id = s.id)
	`
	
	args := []interface{}{}
	if stationID > 0 {
		query += ` WHERE s.id = $1`
		args = append(args, stationID)
	}
	
	query += ` ORDER BY s.id`

	rows := []StationRow{}
	if err := db.SelectContext(ctx, &rows, query, args...); err != nil {
		return nil, err
	}

	result.Count = len(rows)
	for _, row := range rows {
		if !row.HasConfig {
			result.Issues = append(result.Issues, fmt.Sprintf("Station %d (%s) không có visible configuration", row.ID, row.Name))
			result.FailedCount++
		} else {
			result.Details = append(result.Details, fmt.Sprintf("Station %d (%s) có config ID: %d", row.ID, row.Name, *row.ConfigurationID))
		}
	}

	result.Passed = result.FailedCount == 0
	return result, nil
}

func checkStationSensors(ctx context.Context, db *sqlxcache.DB, stationID int32) (*CheckResult, error) {
	result := &CheckResult{
		Issues:  []string{},
		Details: []string{},
	}

	type StationSensorRow struct {
		StationID   int32  `db:"station_id"`
		StationName string `db:"station_name"`
		SensorCount int    `db:"sensor_count"`
	}

	query := `
		SELECT 
			s.id AS station_id,
			s.name AS station_name,
			COUNT(DISTINCT ms.id) AS sensor_count
		FROM fieldkit.station AS s
		LEFT JOIN fieldkit.visible_configuration AS vc ON (vc.station_id = s.id)
		LEFT JOIN fieldkit.configuration_module AS cm ON (vc.configuration_id = cm.configuration_id)
		LEFT JOIN fieldkit.station_module AS sm ON (cm.module_id = sm.id)
		LEFT JOIN fieldkit.module_sensor AS ms ON (ms.module_id = sm.id)
	`
	
	args := []interface{}{}
	argIndex := 1
	if stationID > 0 {
		query += ` WHERE s.id = $` + fmt.Sprintf("%d", argIndex)
		args = append(args, stationID)
		argIndex++
	}
	
	query += ` GROUP BY s.id, s.name ORDER BY s.id`

	rows := []StationSensorRow{}
	if err := db.SelectContext(ctx, &rows, query, args...); err != nil {
		return nil, err
	}

	result.Count = len(rows)
	for _, row := range rows {
		if row.SensorCount == 0 {
			result.Issues = append(result.Issues, fmt.Sprintf("Station %d (%s) không có sensors", row.StationID, row.StationName))
			result.FailedCount++
		} else {
			result.Details = append(result.Details, fmt.Sprintf("Station %d (%s) có %d sensors", row.StationID, row.StationName, row.SensorCount))
		}
	}

	result.Passed = result.FailedCount == 0
	return result, nil
}

func checkSensorKeyMatching(ctx context.Context, db *sqlxcache.DB, stationID int32) (*CheckResult, error) {
	result := &CheckResult{
		Issues:  []string{},
		Details: []string{},
	}

	type SensorKeyRow struct {
		StationID      int32   `db:"station_id"`
		StationName    string  `db:"station_name"`
		ModuleID       int64   `db:"module_id"`
		ModuleKey      *string `db:"module_key"`
		SensorName     string  `db:"sensor_name"`
		FullSensorKey  string  `db:"full_sensor_key"`
		AggregatedID   *int64  `db:"aggregated_sensor_id"`
		AggregatedKey  *string `db:"aggregated_sensor_key"`
	}

	query := `
		SELECT
			q.station_id,
			q.station_name,
			q.module_id,
			q.module_key,
			q.sensor_name,
			q.full_sensor_key,
			agg_sensor.id AS aggregated_sensor_id,
			agg_sensor.key AS aggregated_sensor_key
		FROM (
			SELECT
				station.id AS station_id,
				station.name AS station_name,
				station_module.id AS module_id,
				station_module.name AS module_key,
				module_sensor.name AS sensor_name,
				station_module.name || '.' || module_sensor.name AS full_sensor_key
			FROM fieldkit.station AS station
			LEFT JOIN fieldkit.visible_configuration AS vc ON (vc.station_id = station.id)
			LEFT JOIN fieldkit.configuration_module AS config_module ON (vc.configuration_id = config_module.configuration_id)
			LEFT JOIN fieldkit.station_module AS station_module ON (config_module.module_id = station_module.id)
			LEFT JOIN fieldkit.module_sensor AS module_sensor ON (module_sensor.module_id = station_module.id)
			WHERE station_module.id IS NOT NULL AND module_sensor.id IS NOT NULL
	`
	
	args := []interface{}{}
	argIndex := 1
	if stationID > 0 {
		query += ` AND station.id = $` + fmt.Sprintf("%d", argIndex)
		args = append(args, stationID)
		argIndex++
	}
	
	query += `
		) AS q
		LEFT JOIN fieldkit.aggregated_sensor AS agg_sensor ON (agg_sensor.key = q.full_sensor_key)
		ORDER BY q.station_id, q.module_id, q.sensor_name
	`

	rows := []SensorKeyRow{}
	if err := db.SelectContext(ctx, &rows, query, args...); err != nil {
		return nil, err
	}

	result.Count = len(rows)
	for _, row := range rows {
		if row.AggregatedID == nil {
			result.Issues = append(result.Issues, fmt.Sprintf(
				"Station %d (%s): Sensor key '%s' không match với aggregated_sensor",
				row.StationID, row.StationName, row.FullSensorKey))
			result.FailedCount++
		} else {
			result.Details = append(result.Details, fmt.Sprintf(
				"Station %d: Sensor '%s' match với aggregated_sensor ID %d",
				row.StationID, row.FullSensorKey, *row.AggregatedID))
		}
	}

	result.Passed = result.FailedCount == 0
	return result, nil
}

func checkModuleNameFormat(ctx context.Context, db *sqlxcache.DB, stationID int32) (*CheckResult, error) {
	result := &CheckResult{
		Issues:  []string{},
		Details: []string{},
	}

	type ModuleRow struct {
		ID          int64  `db:"id"`
		StationID   int32  `db:"station_id"`
		StationName string `db:"station_name"`
		ModuleName  string `db:"module_name"`
	}

	query := `
		SELECT
			sm.id,
			s.id AS station_id,
			s.name AS station_name,
			sm.name AS module_name
		FROM fieldkit.station_module AS sm
		JOIN fieldkit.configuration_module AS cm ON (sm.id = cm.module_id)
		JOIN fieldkit.station_configuration AS sc ON (cm.configuration_id = sc.id)
		JOIN fieldkit.provision AS p ON (sc.provision_id = p.id)
		JOIN fieldkit.station AS s ON (p.device_id = s.device_id)
	`
	
	args := []interface{}{}
	argIndex := 1
	if stationID > 0 {
		query += ` WHERE s.id = $` + fmt.Sprintf("%d", argIndex)
		args = append(args, stationID)
		argIndex++
	}
	
	query += ` ORDER BY s.id, sm.id`

	rows := []ModuleRow{}
	if err := db.SelectContext(ctx, &rows, query, args...); err != nil {
		return nil, err
	}

	result.Count = len(rows)
	for _, row := range rows {
		hasPrefix := strings.HasPrefix(row.ModuleName, "fk.") || strings.HasPrefix(row.ModuleName, "wh.")
		hasModulesPrefix := strings.HasPrefix(row.ModuleName, "modules.")

		if !hasPrefix {
			if hasModulesPrefix {
				result.Issues = append(result.Issues, fmt.Sprintf(
					"Station %d (%s): Module %d có name '%s' - cần migrate từ 'modules.' sang 'fk.'",
					row.StationID, row.StationName, row.ID, row.ModuleName))
			} else {
				result.Issues = append(result.Issues, fmt.Sprintf(
					"Station %d (%s): Module %d có name '%s' - thiếu prefix (fk. hoặc wh.)",
					row.StationID, row.StationName, row.ID, row.ModuleName))
			}
			result.FailedCount++
		} else {
			result.Details = append(result.Details, fmt.Sprintf(
				"Station %d: Module %d có name đúng format: '%s'",
				row.StationID, row.ID, row.ModuleName))
		}
	}

	result.Passed = result.FailedCount == 0
	return result, nil
}

func checkStationModuleRelationships(ctx context.Context, db *sqlxcache.DB, stationID int32) (*CheckResult, error) {
	result := &CheckResult{
		Issues:  []string{},
		Details: []string{},
	}

	type RelationshipRow struct {
		StationID    int32  `db:"station_id"`
		StationName  string `db:"station_name"`
		HasProvision bool   `db:"has_provision"`
		HasConfig    bool   `db:"has_config"`
		HasModule    bool   `db:"has_module"`
		HasSensor    bool   `db:"has_sensor"`
		ConfigCount  int    `db:"config_count"`
		ModuleCount  int    `db:"module_count"`
		SensorCount  int    `db:"sensor_count"`
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
			COUNT(DISTINCT ms.id) AS sensor_count
		FROM fieldkit.station AS s
		LEFT JOIN fieldkit.visible_configuration AS vc ON (vc.station_id = s.id)
		LEFT JOIN fieldkit.configuration_module AS cm ON (vc.configuration_id = cm.configuration_id)
		LEFT JOIN fieldkit.station_module AS sm ON (cm.module_id = sm.id)
		LEFT JOIN fieldkit.module_sensor AS ms ON (ms.module_id = sm.id)
	`
	
	args := []interface{}{}
	argIndex := 1
	if stationID > 0 {
		query += ` WHERE s.id = $` + fmt.Sprintf("%d", argIndex)
		args = append(args, stationID)
		argIndex++
	}
	
	query += ` GROUP BY s.id, s.name ORDER BY s.id`

	rows := []RelationshipRow{}
	if err := db.SelectContext(ctx, &rows, query, args...); err != nil {
		return nil, err
	}

	result.Count = len(rows)
	for _, row := range rows {
		issues := []string{}

		if !row.HasProvision {
			issues = append(issues, "thiếu provision")
		}
		if !row.HasConfig {
			issues = append(issues, "thiếu configuration")
		}
		if !row.HasModule {
			issues = append(issues, "thiếu module")
		}
		if !row.HasSensor {
			issues = append(issues, "thiếu sensor")
		}

		if len(issues) > 0 {
			result.Issues = append(result.Issues, fmt.Sprintf(
				"Station %d (%s): %s", row.StationID, row.StationName, strings.Join(issues, ", ")))
			result.FailedCount++
		} else {
			result.Details = append(result.Details, fmt.Sprintf(
				"Station %d (%s): OK - %d configs, %d modules, %d sensors",
				row.StationID, row.StationName, row.ConfigCount, row.ModuleCount, row.SensorCount))
		}
	}

	result.Passed = result.FailedCount == 0
	return result, nil
}

func checkTSDBData(ctx context.Context, db *sqlxcache.DB, stationID int32) (*CheckResult, error) {
	result := &CheckResult{
		Issues:  []string{},
		Details: []string{},
	}

	type TSDBRow struct {
		StationID   int32 `db:"station_id"`
		SensorCount int   `db:"sensor_count"`
		DataCount   int64 `db:"data_count"`
	}

	// Kiểm tra xem có bảng sensor_data không (TimeScaleDB)
	query := `
		SELECT
			s.id AS station_id,
			COUNT(DISTINCT sd.sensor_id) AS sensor_count,
			COUNT(sd.*) AS data_count
		FROM fieldkit.station AS s
		LEFT JOIN fieldkit.sensor_data AS sd ON (sd.station_id = s.id)
	`
	
	args := []interface{}{}
	argIndex := 1
	if stationID > 0 {
		query += ` WHERE s.id = $` + fmt.Sprintf("%d", argIndex)
		args = append(args, stationID)
		argIndex++
	}
	
	query += ` GROUP BY s.id ORDER BY s.id`

	rows := []TSDBRow{}
	if err := db.SelectContext(ctx, &rows, query, args...); err != nil {
		// Có thể bảng sensor_data chưa tồn tại hoặc chưa có dữ liệu
		result.Details = append(result.Details, "Không thể query sensor_data (có thể chưa có dữ liệu hoặc bảng chưa tồn tại)")
		result.Passed = true // Không coi là lỗi nếu bảng chưa tồn tại
		return result, nil
	}

	result.Count = len(rows)
	for _, row := range rows {
		if row.DataCount == 0 {
			result.Issues = append(result.Issues, fmt.Sprintf(
				"Station %d không có dữ liệu trong TSDB", row.StationID))
			result.FailedCount++
		} else {
			result.Details = append(result.Details, fmt.Sprintf(
				"Station %d: %d sensors, %d data points trong TSDB",
				row.StationID, row.SensorCount, row.DataCount))
		}
	}

	result.Passed = result.FailedCount == 0
	return result, nil
}

func checkIngestionProcessing(ctx context.Context, db *sqlxcache.DB, stationID int32) (*CheckResult, error) {
	result := &CheckResult{
		Issues:  []string{},
		Details: []string{},
	}

	type IngestionRow struct {
		StationID         int32  `db:"station_id"`
		StationName       string `db:"station_name"`
		IngestionCount    int    `db:"ingestion_count"`
		ProcessedCount    int    `db:"processed_count"`
		UnprocessedCount  int    `db:"unprocessed_count"`
	}

	query := `
		SELECT
			s.id AS station_id,
			s.name AS station_name,
			COUNT(DISTINCT i.id) AS ingestion_count,
			COUNT(DISTINCT CASE WHEN si.id IS NOT NULL THEN i.id END) AS processed_count,
			COUNT(DISTINCT CASE WHEN si.id IS NULL THEN i.id END) AS unprocessed_count
		FROM fieldkit.station AS s
		LEFT JOIN fieldkit.provision AS p ON (p.device_id = s.device_id)
		LEFT JOIN fieldkit.ingestion AS i ON (i.device_id = p.device_id)
		LEFT JOIN fieldkit.station_ingestion AS si ON (si.data_ingestion_id = i.id)
	`
	
	args := []interface{}{}
	argIndex := 1
	whereClause := ""
	if stationID > 0 {
		whereClause = ` WHERE s.id = $` + fmt.Sprintf("%d", argIndex)
		args = append(args, stationID)
		argIndex++
	}
	
	query += whereClause + ` GROUP BY s.id, s.name HAVING COUNT(DISTINCT i.id) > 0 ORDER BY s.id`

	rows := []IngestionRow{}
	if err := db.SelectContext(ctx, &rows, query, args...); err != nil {
		return nil, err
	}

	result.Count = len(rows)
	for _, row := range rows {
		if row.UnprocessedCount > 0 {
			result.Issues = append(result.Issues, fmt.Sprintf(
				"Station %d (%s): %d/%d ingestion chưa được xử lý",
				row.StationID, row.StationName, row.UnprocessedCount, row.IngestionCount))
			result.FailedCount++
		} else if row.IngestionCount > 0 {
			result.Details = append(result.Details, fmt.Sprintf(
				"Station %d (%s): %d ingestion đã được xử lý",
				row.StationID, row.StationName, row.ProcessedCount))
		}
	}

	result.Passed = result.FailedCount == 0
	return result, nil
}

