package tests

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	support "gitlab.com/fieldkit/cloud/migrations/support"
)

var (
	registered bool
)

func tryMigrate(url string) error {
	path, err := findMigrationsPath("primary")
	if err != nil {
		return err
	}

	log.Printf("trying to migrate...")
	log.Printf("postgres = %s", url)
	log.Printf("migrations = %s", path)

	migrator := support.NewMigrator(url, path)

	if !registered {
		if err := migrator.Load(); err != nil {
			return err
		}

		registered = true
	}

	if err := migrator.Run([]string{"", "migrate"}); err != nil {
		return err
	}

	return nil
}

func findMigrationsPath(relative string) (string, error) {
	path, err := os.Getwd()
	if err != nil {
		return "", fmt.Errorf("unable to find migrations directory: %w", err)
	}

	for {
		test := filepath.Join(path, "migrations")
		if _, err := os.Stat(test); !os.IsNotExist(err) {
			return filepath.Join(test, relative), nil
		}

		path = filepath.Dir(path)
	}
}
