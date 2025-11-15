package main

import (
	"log"
	"os"

	support "gitlab.com/fieldkit/cloud/migrations/support"
)

func main() {
	migrator, err := support.NewMigratorFromEnv()
	if err != nil {
		log.Fatalln(err)
	}

	if err := migrator.Load(); err != nil {
		log.Fatalln(err)
	}

	if err := migrator.Run(os.Args); err != nil {
		log.Fatalln(err)
	}
}
