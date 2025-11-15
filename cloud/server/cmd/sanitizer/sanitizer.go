package main

import (
	"context"
	"flag"
	"strings"
	"time"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"

	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"

	"github.com/kelseyhightower/envconfig"

	"github.com/bxcodec/faker/v3"

	"gitlab.com/fieldkit/cloud/server/common/logging"
	"gitlab.com/fieldkit/cloud/server/data"
)

type Options struct {
	PostgresURL     string `split_words:"true" default:"postgres://fieldkit:password@127.0.0.1/fieldkit?sslmode=disable" required:"true"`
	Password        string
	WaitForDatabase bool
}

func shouldAnonyomize(user *data.User) bool {
	if strings.Contains(user.Email, "jacob@conservify.org") || strings.Contains(user.Email, "jacob@fieldkit.org") {
		return false
	}

	if strings.Contains(user.Email, "katekuehl@gmail.com") {
		return false
	}

	if strings.Contains(user.Email, "pete@conservify.org") || strings.Contains(user.Email, "pete@fieldkit.org") {
		return false
	}

	return true
}

func sanitize(outerCtx context.Context, db *sqlxcache.DB, options *Options) error {
	log := logging.Logger(outerCtx).Sugar()

	db.WithNewOwnedTransaction(outerCtx, func(ctx context.Context, tx *sqlx.Tx) error {
		users := []*data.User{}
		if err := db.SelectContext(ctx, &users, `SELECT * FROM fieldkit.user ORDER BY id`); err != nil {
			return err
		}

		for _, user := range users {
			user.SetPassword(options.Password)

			if shouldAnonyomize(user) {
				user.Name = faker.Name()
				user.Bio = faker.Sentence()
				user.Email = faker.Email()
			} else {
				log.Infow("keeping", "user_id", user.ID, "email", user.Email)
			}

			if _, err := db.NamedExecContext(ctx, `UPDATE fieldkit.user SET password = :password, name = :name, username = :email, email = :email, bio = :bio, media_url = NULL WHERE id = :id`, user); err != nil {
				return err
			}
		}

		if _, err := db.ExecContext(ctx, `UPDATE fieldkit.station SET location = NULL, location_name = NULL, place_native = NULL`); err != nil {
			return err
		}

		if _, err := db.ExecContext(ctx, `UPDATE fieldkit.meta_record SET raw = '{}', pb = NULL`); err != nil {
			return err
		}

		if _, err := db.ExecContext(ctx, `DELETE FROM fieldkit.gue_jobs`); err != nil {
			return err
		}

		if _, err := db.ExecContext(ctx, `DELETE FROM fieldkit.invite_token`); err != nil {
			return err
		}

		if _, err := db.ExecContext(ctx, `DELETE FROM fieldkit.recovery_token`); err != nil {
			return err
		}

		if _, err := db.ExecContext(ctx, `DELETE FROM fieldkit.refresh_token`); err != nil {
			return err
		}

		if _, err := db.ExecContext(ctx, `DELETE FROM fieldkit.validation_token`); err != nil {
			return err
		}

		if _, err := db.ExecContext(ctx, `DELETE FROM fieldkit.twitter_oauth`); err != nil {
			return err
		}

		if _, err := db.ExecContext(ctx, `DELETE FROM fieldkit.twitter_account`); err != nil {
			return err
		}

		if _, err := db.ExecContext(ctx, `DELETE FROM fieldkit.project_invite`); err != nil {
			return err
		}

		return tx.Commit()
	})

	return nil
}

func main() {
	ctx := context.Background()
	options := &Options{
		WaitForDatabase: true,
	}

	flag.BoolVar(&options.WaitForDatabase, "waiting", false, "")
	flag.StringVar(&options.Password, "password", "asdfasdfasdf", "")

	flag.Parse()

	logging.Configure(false, "sanitizer")

	log := logging.Logger(ctx).Sugar()

	if err := envconfig.Process("FIELDKIT", options); err != nil {
		panic(err)
	}

	for {
		db, err := sqlxcache.Open(ctx, "postgres", options.PostgresURL)
		if err != nil {
			if !options.WaitForDatabase {
				panic(err)
			} else {
				log.Infow("error", "error", err)
				time.Sleep(1 * time.Second)
				continue
			}
		}

		if err := sanitize(ctx, db, options); err != nil {
			panic(err)
		}

		break
	}

	log.Infow("done")
}
