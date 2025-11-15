package backend

import (
	"bytes"
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	"github.com/golang/protobuf/proto"

	pbdata "gitlab.com/fieldkit/libraries/data-protocol"
)

func ExtractMeta(ctx context.Context, path string) (*MetaScanner, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("opening file: %w", err)
	}

	defer file.Close()

	ms := NewMetaScanner()

	if err := Decode(ctx, file, ms); err != nil {
		return nil, fmt.Errorf("decoding: %w", err)
	}

	if ms.DeviceId != nil {
		log.Printf("DeviceId: %s", hex.EncodeToString(*ms.DeviceId))
	}
	if ms.GenerationId != nil {
		log.Printf("GenerationId: %s", hex.EncodeToString(*ms.GenerationId))
	}
	if ms.DeviceName != nil {
		log.Printf("DeviceName: %s", *ms.DeviceName)
	}
	if ms.FirstRecord != nil {
		log.Printf("FirstRecord: %d", *ms.FirstRecord)
	}
	if ms.LastRecord != nil {
		log.Printf("LastRecord: %d", *ms.LastRecord)
	}

	log.Printf("Visited: %d", ms.Visited)

	return ms, nil
}

func (ms *MetaScanner) Valid() error {
	if ms.DeviceId == nil {
		return fmt.Errorf("missing: device id")
	}
	if ms.GenerationId == nil {
		return fmt.Errorf("missing: generation id")
	}
	if ms.DeviceName == nil {
		return fmt.Errorf("missing: device name")
	}
	if ms.FirstRecord == nil {
		return fmt.Errorf("missing: first record")
	}
	if ms.LastRecord == nil {
		return fmt.Errorf("missing: last record")
	}

	return nil
}

type MetaScanner struct {
	DeviceId     *[]byte
	DeviceName   *string
	GenerationId *[]byte
	Visited      uint64
	FirstRecord  *uint64
	LastRecord   *uint64
}

func NewMetaScanner() *MetaScanner {
	return &MetaScanner{}
}

func (ms *MetaScanner) OnRecord(ctx context.Context, record *pbdata.DataRecord) error {
	if record.Metadata != nil {
		if record.Metadata.DeviceId != nil {
			if ms.DeviceId == nil {
				ms.DeviceId = &record.Metadata.DeviceId
			} else {
				if !bytes.Equal(*ms.DeviceId, record.Metadata.DeviceId) {
					return fmt.Errorf("multiple device ids in file")
				}
			}
		}
		if record.Metadata.Generation != nil {
			if ms.GenerationId == nil {
				ms.GenerationId = &record.Metadata.Generation
			} else {
				if !bytes.Equal(*ms.GenerationId, record.Metadata.Generation) {
					return fmt.Errorf("multiple generations in file")
				}
			}
		}
	}

	if record.Identity != nil {
		if record.Identity.Name != "" {
			if ms.DeviceName == nil {
				ms.DeviceName = &record.Identity.Name
			} else {
				if *ms.DeviceName != record.Identity.Name {
					return fmt.Errorf("multiple names in file (%s vs %s)", *ms.DeviceName, record.Identity.Name)
				}
			}
		}
	}

	number, err := getRecordNumber(record)
	if err != nil {
		return err
	}

	if number != nil {
		if ms.FirstRecord == nil {
			ms.FirstRecord = number
		}
		if ms.LastRecord == nil || *ms.LastRecord < *number {
			ms.LastRecord = number
		} else {
			return fmt.Errorf("non-monotonic record")
		}
	}

	ms.Visited += 1

	return nil
}

func getRecordNumber(record *pbdata.DataRecord) (*uint64, error) {
	if record.Readings != nil {
		if record.Readings.Reading == 0 {
			// Sanity check. This should never happen, as we'll need a meta
			// record first, so we can't have a zero reading record.
			return nil, fmt.Errorf("zero readings record")
		}
		return &record.Readings.Reading, nil
	}
	if record.Metadata != nil {
		return &record.Metadata.Record, nil
	}
	// All records from modern firmware should have a number. There are hacks we
	// can fallback in if we ever see an old file in here.
	return nil, fmt.Errorf("no record number")
}

type RecordVisitor interface {
	OnRecord(ctx context.Context, record *pbdata.DataRecord) error
}

func Decode(ctx context.Context, reader io.Reader, visitor RecordVisitor) error {
	unmarshalFunc := UnmarshalFunc(func(b []byte) (proto.Message, error) {
		var record pbdata.DataRecord
		err := proto.Unmarshal(b, &record)
		if err != nil {
			return nil, err
		}

		if err := visitor.OnRecord(ctx, &record); err != nil {
			log.Printf("error: %s", err)

			replyJson, err := json.MarshalIndent(&record, "", "  ")
			if err != nil {
				return nil, err
			}

			fmt.Println(string(replyJson))

			return nil, err
		}

		return nil, nil
	})

	_, _, err := ReadLengthPrefixedCollection(ctx, MaximumDataRecordLength, reader, unmarshalFunc)
	if err != nil {
		return err
	}

	return nil
}

func UploadWithToken(ctx context.Context, url string, token string, path string) (*MetaScanner, error) {
	ms, err := ExtractMeta(ctx, path)
	if err != nil {
		return nil, err
	}

	if err := ms.Valid(); err != nil {
		return nil, err
	}

	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}

	stat, err := file.Stat()
	if err != nil {
		return nil, err
	}

	defer file.Close()

	req, err := http.NewRequest("POST", fmt.Sprintf("%s/ingestion", url), file)
	if err != nil {
		return nil, err
	}

	req.ContentLength = stat.Size()

	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("Authorization", token)
	req.Header.Set("Fk-Blocks", fmt.Sprintf("%d,%d", *ms.FirstRecord, *ms.LastRecord))
	req.Header.Set("Fk-DeviceId", hex.EncodeToString(*ms.DeviceId))
	req.Header.Set("Fk-DeviceName", *ms.DeviceName)
	req.Header.Set("Fk-Generation", hex.EncodeToString(*ms.GenerationId))
	req.Header.Set("Fk-Type", "data")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}

	defer resp.Body.Close()

	return ms, nil
}
