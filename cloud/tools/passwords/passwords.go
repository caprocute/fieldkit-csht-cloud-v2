package main

import (
	"context"
	"encoding/hex"
	"flag"
	"log"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/kelseyhightower/envconfig"
	"golang.org/x/crypto/bcrypt"

	_ "github.com/lib/pq"
)

type Config struct {
	PostgresURL string `split_words:"true" default:"postgres://localhost/fieldkit?sslmode=disable" required:"true"`
}

type Options struct {
	Password string
	SetAll   bool
	Show     bool
}

func main() {
	ctx := context.Background()

	config := &Config{}
	if err := envconfig.Process("FIELDKIT", config); err != nil {
		panic(err)
	}

	options := &Options{}
	flag.StringVar(&options.Password, "password", "", "")
	flag.BoolVar(&options.SetAll, "set-all", false, "set-all")
	flag.BoolVar(&options.Show, "show", false, "show")
	flag.Parse()

	if options.Password != "" {
		hashed, err := generateHashFromPassword(strings.TrimSpace(options.Password))
		if err != nil {
			panic(err)
		}

		if options.Show {
			log.Printf("%v %v", options.Password, hex.EncodeToString(hashed))
		}

		if options.SetAll {
			pgxcfg, err := pgxpool.ParseConfig(config.PostgresURL)
			if err != nil {
				panic(err)
			}

			dbpool, err := pgxpool.NewWithConfig(ctx, pgxcfg)
			if err != nil {
				panic(err)
			}

			res, err := dbpool.Exec(ctx, "UPDATE fieldkit.user SET password = $1", hashed)
			if err != nil {
				panic(err)
			}

			log.Printf("%v rows affected", res.RowsAffected())
		}
	} else {
		flag.Usage()
	}
}

func generateHashFromPassword(password string) ([]byte, error) {
	return bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
}
