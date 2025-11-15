package support

import (
	"context"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"

	"github.com/go-pg/pg/v10/orm"

	"github.com/go-pg/pg/v10"
	migrations "github.com/robinjoseph08/go-pg-migrations/v3"
)

type Migrator struct {
	url  string
	path string
}

func NewMigrator(url, path string) *Migrator {
	return &Migrator{
		url:  url,
		path: path,
	}
}

func NewMigratorFromEnv() (*Migrator, error) {
	path := os.Getenv("MIGRATE_PATH")
	if path == "" {
		return nil, fmt.Errorf("MIGRATE_PATH is requied")
	}

	url := os.Getenv("MIGRATE_DATABASE_URL")
	if url == "" {
		return nil, fmt.Errorf("MIGRATE_DATABASE_URL is requied")
	}

	return &Migrator{
		url:  url,
		path: path,
	}, nil
}

func (m *Migrator) Load() error {
	log.Printf("Scanning %s...", m.path)

	files, err := filepath.Glob(filepath.Join(m.path, "*.up.sql"))
	if err != nil {
		return fmt.Errorf("error scanning migrations: %w", err)
	}

	log.Printf("Found %d migration(s) in %s...", len(files), m.path)

	for _, file := range files {
		data, err := ioutil.ReadFile(file)
		if err != nil {
			return fmt.Errorf("error reading migration: %w", err)
		}

		text := string(data)

		up := func(db orm.DB) error {
			_, err := db.Exec(text)
			return err
		}

		down := func(db orm.DB) error {
			return err
		}

		opts := migrations.MigrationOptions{}

		_, fileOnly := filepath.Split(file)

		migrations.Register(fileOnly, up, down, opts)
	}

	return nil
}

func (m *Migrator) Run(args []string) error {
	o, err := pg.ParseURL(m.url)
	if err != nil {
		return fmt.Errorf("invalid url: %s (%w)", m.url, err)
	}

	o.OnConnect = func(ctx context.Context, conn *pg.Conn) error {
		log.Printf("Creating schema...")

		if _, err := conn.ExecContext(ctx, "CREATE SCHEMA IF NOT EXISTS fieldkit"); err != nil {
			return fmt.Errorf("error creating: %w", err)
		}

		var n int
		_, err := conn.QueryContext(ctx, pg.Scan(&n), "SELECT COUNT(rolname) FROM pg_roles WHERE rolname = 'fieldkit'")
		if err != nil {
			return fmt.Errorf("error granting: %w", err)
		}
		if n > 0 {
			log.Printf("Granting permissions...")

			if _, err := conn.ExecContext(ctx, "GRANT USAGE ON SCHEMA fieldkit TO fieldkit"); err != nil {
				return fmt.Errorf("error granting: %w", err)
			}

			if _, err := conn.ExecContext(ctx, "GRANT CREATE ON SCHEMA fieldkit TO fieldkit"); err != nil {
				return fmt.Errorf("error granting: %w", err)
			}
		} else {
			log.Printf("Role missing, skipping GRANT...")
		}

		log.Printf("Configure search_path...")

		if _, err := conn.ExecContext(ctx, "SET search_path TO fieldkit, public;"); err != nil {
			return fmt.Errorf("error granting: %w", err)
		}

		log.Printf("Preparation done!")

		return nil
	}

	db := pg.Connect(o)

	if err := migrations.Run(db, m.path, args); err != nil {
		return fmt.Errorf("migration error: %w", err)
	}

	return nil
}
