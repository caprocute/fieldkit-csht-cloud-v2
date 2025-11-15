package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	_ "github.com/lib/pq"
	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
)

func main() {
	var (
		dbURL = flag.String("db", "", "PostgreSQL database URL")
		apiURL = flag.String("api", "", "API base URL (optional, for triggering via API)")
		token = flag.String("token", "", "JWT token (required if using API)")
	)
	flag.Parse()

	if *dbURL == "" {
		log.Fatal("❌ -db flag is required")
	}

	// Trim whitespace from URLs
	*dbURL = strings.TrimSpace(*dbURL)
	if *apiURL != "" {
		*apiURL = strings.TrimSpace(*apiURL)
	}
	if *token != "" {
		*token = strings.TrimSpace(*token)
	}

	ctx := context.Background()

	// Connect to database
	db, err := sqlxcache.Open(ctx, "postgres", *dbURL)
	if err != nil {
		log.Fatalf("❌ Failed to connect to database: %v", err)
	}

	// Query all meta ingestions that haven't been processed
	// (no station_configuration created from them)
	query := `
		SELECT DISTINCT
			i.id AS ingestion_id,
			i.device_id,
			i.type,
			i.time,
			s.id AS station_id,
			s.name AS station_name,
			EXISTS(
				SELECT 1 FROM fieldkit.station_configuration sc
				JOIN fieldkit.provision p ON (sc.provision_id = p.id)
				WHERE p.device_id = i.device_id
			) AS has_configuration
		FROM fieldkit.ingestion AS i
		JOIN fieldkit.station AS s ON (s.device_id = i.device_id)
		WHERE i.type = 'meta'
		AND NOT EXISTS(
			SELECT 1 FROM fieldkit.station_configuration sc
			JOIN fieldkit.provision p ON (sc.provision_id = p.id)
			WHERE p.device_id = i.device_id
		)
		ORDER BY i.time DESC
	`

	type MetaIngestionRow struct {
		IngestionID    int64     `db:"ingestion_id"`
		DeviceID        []byte    `db:"device_id"`
		Type           string    `db:"type"`
		Time           time.Time `db:"time"`
		StationID      int32     `db:"station_id"`
		StationName    string    `db:"station_name"`
		HasConfiguration bool    `db:"has_configuration"`
	}

	rows := []MetaIngestionRow{}
	if err := db.SelectContext(ctx, &rows, query); err != nil {
		log.Fatalf("❌ Failed to query meta ingestions: %v", err)
	}

	if len(rows) == 0 {
		log.Println("✅ No unprocessed meta ingestions found")
		return
	}

	log.Printf("📊 Found %d unprocessed meta ingestions\n", len(rows))
	log.Println("")

	// If API URL and token provided, trigger processing via API
	if *apiURL != "" && *token != "" {
		log.Println("🔄 Triggering processing via API...")
		log.Println("")
		
		successCount := 0
		failCount := 0
		
		for _, row := range rows {
			log.Printf("  Processing meta ingestion ID=%d for station %d (%s)...", 
				row.IngestionID, row.StationID, row.StationName)
			
		// Normalize API URL (remove path/query if present)
		normalizedAPIURL, err := normalizeAPIURL(*apiURL)
		if err != nil {
			log.Printf("    ❌ Failed to normalize API URL: %v", err)
			failCount++
			continue
		}
		
		// Call API to trigger processing
		url := fmt.Sprintf("%s/data/ingestions/%d/process", normalizedAPIURL, row.IngestionID)
		req, err := http.NewRequest("POST", url, nil)
		if err != nil {
			log.Printf("    ❌ Failed to create request: %v", err)
			failCount++
			continue
		}
		
		// Remove "Bearer " prefix if present (code will add it)
		tokenValue := strings.TrimPrefix(*token, "Bearer ")
		req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", tokenValue))
		req.Header.Set("Content-Type", "application/json")
			
			client := &http.Client{Timeout: 30 * time.Second}
			resp, err := client.Do(req)
			if err != nil {
				log.Printf("    ❌ Failed to trigger processing: %v", err)
				failCount++
				continue
			}
			resp.Body.Close()
			
			if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusNoContent {
				log.Printf("    ✅ Triggered processing")
				successCount++
			} else {
				log.Printf("    ❌ Failed: status %d", resp.StatusCode)
				failCount++
			}
			
			// Small delay to avoid overwhelming the API
			time.Sleep(500 * time.Millisecond)
		}
		
		log.Println("")
		log.Printf("📊 Summary: %d succeeded, %d failed", successCount, failCount)
		log.Println("")
		log.Println("⏳ Processing may take a few minutes. Run data_integrity to check status.")
	} else {
		// Just list the ingestions
		log.Println("📋 Unprocessed meta ingestions:")
		for _, row := range rows {
			log.Printf("  - Ingestion ID=%d, Station ID=%d (%s), Time=%s",
				row.IngestionID, row.StationID, row.StationName, row.Time.Format(time.RFC3339))
		}
		log.Println("")
		log.Println("💡 To trigger processing, provide -api and -token flags:")
		log.Println("   ./bin/process_meta -db <db_url> -api <api_url> -token <jwt_token>")
	}
}

// normalizeAPIURL removes any path or query string from the URL
func normalizeAPIURL(rawURL string) (string, error) {
	if !strings.HasPrefix(rawURL, "http://") && !strings.HasPrefix(rawURL, "https://") {
		rawURL = "http://" + rawURL
	}

	parsed, err := url.Parse(rawURL)
	if err != nil {
		return "", fmt.Errorf("failed to parse URL: %w", err)
	}

	normalized := url.URL{
		Scheme: parsed.Scheme,
		Host:   parsed.Host,
	}

	return normalized.String(), nil
}

