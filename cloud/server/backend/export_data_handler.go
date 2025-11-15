package backend

import (
	"context"
	"encoding/csv"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"time"

	"github.com/pkg/profile"

	"gitlab.com/fieldkit/cloud/server/common/sqlxcache"
	"gitlab.com/fieldkit/cloud/server/data"
	pb "gitlab.com/fieldkit/libraries/data-protocol"

	"gitlab.com/fieldkit/cloud/server/backend/repositories"
	"gitlab.com/fieldkit/cloud/server/common/logging"
	"gitlab.com/fieldkit/cloud/server/files"
	"gitlab.com/fieldkit/cloud/server/messages"
)

const (
	SecondsBetweenProgressUpdates = 1.0 / 2.0
)

type ExportDataHandler struct {
	db                  *sqlxcache.DB
	files               files.FileArchive
	metrics             *logging.Metrics
	updatedAt           time.Time
	bytesExpectedToRead int64
	bytesRead           int64
}

func NewExportDataHandler(db *sqlxcache.DB, files files.FileArchive, metrics *logging.Metrics) *ExportDataHandler {
	return &ExportDataHandler{
		db:                  db,
		files:               files,
		metrics:             metrics,
		updatedAt:           time.Now(),
		bytesExpectedToRead: 0,
		bytesRead:           0,
	}
}

func (h *ExportDataHandler) progress(ctx context.Context, de *data.DataExport, progress WalkProgress) error {
	// Important to always update this, or bytes get lost.
	h.bytesRead += progress.read
	// I like state being consistent, so we do this here also.
	de.Progress = (float64(h.bytesRead) / float64(h.bytesExpectedToRead)) * 100.0

	elapsed := time.Since(h.updatedAt)
	if elapsed.Seconds() < SecondsBetweenProgressUpdates {
		return nil
	}

	h.updatedAt = time.Now()

	r, err := repositories.NewExportRepository(h.db)
	if err != nil {
		return err
	}
	if _, err := r.UpdateDataExport(ctx, de); err != nil {
		return err
	}

	return nil
}

func (h *ExportDataHandler) Handle(ctx context.Context, m *messages.ExportData) error {
	log := Logger(ctx).Sugar().Named("exporting").With("data_export_id", m.ID).With("user_id", m.UserID).With("formatter", m.Format)

	log.Infow("processing")

	if false {
		defer profile.Start().Stop()
	}

	r, err := repositories.NewExportRepository(h.db)
	if err != nil {
		return err
	}

	de, err := r.QueryByID(ctx, m.ID)
	if err != nil {
		return err
	}

	rawParams := &RawQueryParams{}
	if err := json.Unmarshal(de.Args, rawParams); err != nil {
		return err
	}

	qp, err := rawParams.BuildQueryParams()
	if err != nil {
		return fmt.Errorf("invalid query params: %w", err)
	}

	log.Infow("parameters", "start", qp.Start, "end", qp.End, "sensors", qp.Sensors, "stations", qp.Stations)

	ir := repositories.NewIngestionRepository(h.db)

	ingestions, err := ir.QueryByStationID(ctx, qp.Stations[0])
	if err != nil {
		return err
	}

	sizeOfSinglePass := int64(0)
	urls := make([]string, 0, len(ingestions))
	for _, ingestion := range ingestions {
		urls = append(urls, ingestion.URL)
		sizeOfSinglePass += ingestion.Size
	}

	h.bytesExpectedToRead = sizeOfSinglePass * 2

	readFunc := func(ctx context.Context, reader io.Reader) error {
		metadata := make(map[string]string)
		af, err := h.files.Archive(ctx, "text/csv", metadata, reader)
		if err != nil {
			log.Errorw("archiver:error", "error", err)
			return err
		} else {
			log.Infow("archiver:done", "key", af.Key, "bytes", af.BytesRead)
		}

		now := time.Now()
		size := int32(af.BytesRead)

		de.DownloadURL = &af.URL
		de.CompletedAt = &now
		de.Progress = 100
		de.Size = &size
		if _, err := r.UpdateDataExport(ctx, de); err != nil {
			return err
		}

		return nil
	}

	progressFunc := func(ctx context.Context, progress WalkProgress) error {
		return h.progress(ctx, de, progress)
	}

	writeFunc := func(ctx context.Context, writer io.Writer) error {
		exporter := NewCsvExporter(h.files, h.metrics, writer, progressFunc)

		if err := exporter.Prepare(ctx, urls); err != nil {
			return fmt.Errorf("preparing: exporting failed: %w", err)
		}

		if err := exporter.Export(ctx, urls); err != nil {
			return fmt.Errorf("writing: exporting failed: %w", err)
		}

		return nil
	}

	async := NewAsyncFileWriter(readFunc, writeFunc)
	if err := async.Start(ctx); err != nil {
		return err
	}

	if err := async.Wait(ctx); err != nil {
		return err
	}

	return nil
}

type CanExport interface {
	Prepare(ctx context.Context, urls []string) error
	Export(ctx context.Context, urls []string) error
}

type JsonLinesExporter struct {
	writer io.Writer
	walker *FkbWalker
}

func NewJsonLinesExporter(files files.FileArchive, metrics *logging.Metrics, writer io.Writer, progress OnWalkProgress) (self *JsonLinesExporter) {
	self = &JsonLinesExporter{
		writer: writer,
	}
	self.walker = NewFkbWalker(files, metrics, self, progress, true)
	return
}

func (e *JsonLinesExporter) Prepare(ctx context.Context, urls []string) error {
	return nil
}

func (e *JsonLinesExporter) Export(ctx context.Context, urls []string) error {
	for _, url := range urls {
		if _, err := e.walker.WalkUrl(ctx, url); err != nil {
			return fmt.Errorf("export %v failed: %w", url, err)
		}
	}

	return nil
}

func (e *JsonLinesExporter) OnSignedMeta(ctx context.Context, signedRecord *pb.SignedRecord, rawRecord *pb.DataRecord, bytes []byte) error {
	log := Logger(ctx).Sugar()

	log.Infow("signed-meta", "record_number", signedRecord.Record, "record", rawRecord)

	return e.write(ctx, rawRecord)
}

func (e *JsonLinesExporter) OnMeta(ctx context.Context, recordNumber int64, rawRecord *pb.DataRecord, bytes []byte) error {
	log := Logger(ctx).Sugar()

	log.Infow("meta", "record_number", recordNumber, "record", rawRecord)

	return e.write(ctx, rawRecord)
}

func (e *JsonLinesExporter) OnData(ctx context.Context, rawRecord *pb.DataRecord, rawMetaUnused *pb.DataRecord, bytes []byte) error {
	for _, sensorGroup := range rawRecord.Readings.SensorGroups {
		for _, reading := range sensorGroup.Readings {
			if calibrated, ok := reading.Calibrated.(*pb.SensorAndValue_CalibratedValue); ok {
				if math.IsNaN(float64(calibrated.CalibratedValue)) {
					reading.Calibrated = &pb.SensorAndValue_CalibratedNull{}
				}
			}
		}
	}

	return e.write(ctx, rawRecord)
}

func (e *JsonLinesExporter) write(_ context.Context, value interface{}) (err error) {
	b, err := json.Marshal(value)
	if err != nil {
		return err
	}
	if _, err := e.writer.Write(b); err != nil {
		return err
	}

	if _, err := io.WriteString(e.writer, "\n"); err != nil {
		return err
	}

	return nil
}

func (e *JsonLinesExporter) OnDone(ctx context.Context) (err error) {
	return nil
}

type records struct {
	meta    *pb.DataRecord
	data    *pb.DataRecord
	modules map[string]bool
}

type CsvExporter struct {
	writer        *csv.Writer
	walker        *FkbWalker
	preparing     *preparingCsv
	prepared      *preparingCsv
	row           []string
	records       *records
	bytesRead     int64
	expectedBytes int64
}

type fieldFunc func(*records) string
type optionalFieldFunc func(*records) *string

type csvField struct {
	name string
	get  optionalFieldFunc
}

type fieldSet struct {
	kind   string
	fields []*csvField
}

func newFieldSet(kind string) *fieldSet {
	return &fieldSet{
		kind:   kind,
		fields: make([]*csvField, 0),
	}
}

type uniqueLayoutKey struct {
	metaId   int64
	moduleId string
}

func (p *fieldSet) addField(name string, get optionalFieldFunc) {
	p.fields = append(p.fields, &csvField{name: name, get: get})
}

type preparingCsv struct {
	fields    *fieldSet
	metas     map[int64]*pb.DataRecord
	conflicts map[string]map[string]bool
	modules   map[uniqueLayoutKey]*fieldSet
	order     []uniqueLayoutKey
	compacted []*fieldSet
}

func (p *preparingCsv) addField(name string, get fieldFunc) {
	p.fields.addField(name, func(r *records) *string {
		value := get(r)
		return &value
	})
}

func NewCsvExporter(files files.FileArchive, metrics *logging.Metrics, writer io.Writer, progress OnWalkProgress) (self *CsvExporter) {
	self = &CsvExporter{
		writer:        csv.NewWriter(writer),
		records:       &records{},
		row:           nil,
		bytesRead:     0,
		expectedBytes: 0,
		preparing: &preparingCsv{
			fields:    newFieldSet("fixed"),
			metas:     make(map[int64]*pb.DataRecord),
			conflicts: make(map[string]map[string]bool),
			modules:   make(map[uniqueLayoutKey]*fieldSet),
			order:     make([]uniqueLayoutKey, 0),
		},
	}
	self.walker = NewFkbWalker(files, metrics, self, progress, true)
	return
}

func (e *CsvExporter) Prepare(ctx context.Context, urls []string) error {
	e.preparing.addField("unix_time", func(r *records) string {
		return fmt.Sprintf("%v", r.data.Readings.Time)
	})
	e.preparing.addField("time", func(r *records) string {
		t := time.Unix(r.data.Readings.Time, 0)
		return fmt.Sprintf("%v", t)
	})
	e.preparing.addField("data_record", func(r *records) string {
		return fmt.Sprintf("%v", r.data.Readings.Reading)
	})
	e.preparing.addField("meta_record", func(r *records) string {
		return fmt.Sprintf("%v", r.data.Readings.Meta)
	})
	e.preparing.addField("uptime", func(r *records) string {
		return fmt.Sprintf("%v", r.data.Readings.Uptime)
	})
	e.preparing.addField("gps", func(r *records) string {
		if loc := r.data.Readings.Location; loc != nil {
			return fmt.Sprintf("%v", loc.Fix)
		}
		return ""
	})
	e.preparing.addField("latitude", func(r *records) string {
		if loc := r.data.Readings.Location; loc != nil {
			return fmt.Sprintf("%v", loc.Latitude)
		}
		return ""
	})
	e.preparing.addField("longitude", func(r *records) string {
		if loc := r.data.Readings.Location; loc != nil {
			return fmt.Sprintf("%v", loc.Longitude)
		}
		return ""
	})
	e.preparing.addField("altitude", func(r *records) string {
		if loc := r.data.Readings.Location; loc != nil {
			return fmt.Sprintf("%v", loc.Altitude)
		}
		return ""
	})
	e.preparing.addField("gps_time", func(r *records) string {
		if loc := r.data.Readings.Location; loc != nil {
			return fmt.Sprintf("%v", loc.Time)
		}
		return ""
	})
	e.preparing.addField("note", func(r *records) string {
		return ""
	})

	for _, url := range urls {
		if _, err := e.walker.WalkUrl(ctx, url); err != nil {
			return fmt.Errorf("prepare %v failed: %w", url, err)
		}
	}

	e.prepared = e.preparing
	e.preparing = nil

	return nil
}

const CompactFieldSets = true

func (e *CsvExporter) compactFieldSets(ctx context.Context) error {
	unassigned := make(map[uniqueLayoutKey]*fieldSet)
	compacted := make([]*fieldSet, 0)
	for id, fs := range e.prepared.modules {
		unassigned[id] = fs
	}

	// The general idea here is to loop over all the module field sets, in the
	// order they appeared in the data. For each of them we check the remaining,
	// unassigned field sets to see if they can share columns in the final CSV.
	// Modules can share columns if:
	// 1. They are of the same kind, and therefore have the same number of columns.
	// 2. They were never installed together on the station.
	// For those can can be compacted, we generate a field set that delegates to
	// the first field set that returns a value.
	for _, id := range e.prepared.order {
		if fs, ok := unassigned[id]; ok {
			assignedIds := make([]uniqueLayoutKey, 0)
			assignedIds = append(assignedIds, id)
			candidates := make([]*fieldSet, 1)
			candidates[0] = fs

			if CompactFieldSets {
				conflicts := e.prepared.conflicts[id.moduleId]
				for maybeId, maybe := range unassigned {
					if maybeId != id {
						if maybe.kind == fs.kind {
							if len(maybe.fields) != len(fs.fields) {
								return fmt.Errorf("same kind different fields")
							}
							if conflicts == nil || !conflicts[maybeId.moduleId] {
								candidates = append(candidates, maybe)
								assignedIds = append(assignedIds, maybeId)
							}
						}
					}
				}
			}

			for _, id := range assignedIds {
				delete(unassigned, id)
			}

			// Check to see if two fieldsets are sharing a set of columns, if so
			// for column values we check to see which of the fieldsets returns
			// a value and return that one. Note that they should never *both*
			// return a value because of the conflict check. This could be relaxed.
			if len(candidates) > 1 {
				numberFields := len(fs.fields)
				fields := make([]*csvField, numberFields)
				for i := 0; i < numberFields; i += 1 {
					fields[i] = &csvField{
						name: fs.fields[i].name,
						get: (func(c []*fieldSet, i int) optionalFieldFunc {
							return func(r *records) *string {
								for _, fs := range c {
									value := fs.fields[i].get(r)
									if value != nil {
										return value
									}
								}
								return nil
							}
						})(candidates, i),
					}
				}
				combined := &fieldSet{
					kind:   fs.kind,
					fields: fields,
				}
				compacted = append(compacted, combined)
			} else {
				compacted = append(compacted, fs)
			}
		}
	}
	e.prepared.compacted = compacted

	return nil
}

func (e *CsvExporter) Export(ctx context.Context, urls []string) error {
	log := Logger(ctx).Sugar()

	if err := e.compactFieldSets(ctx); err != nil {
		return err
	}

	for key, _ := range e.prepared.modules {
		log.Infow("prepared", "module", key, "module_id", key.moduleId, "meta_id", key.metaId)
	}

	log.Infow("prepared", "conflicts", e.prepared.conflicts)
	log.Infow("prepared", "module_ids", e.prepared.order)
	log.Infow("prepared", "compacted", e.prepared.compacted)

	header := make([]string, 0, len(e.prepared.fields.fields))
	for _, field := range e.prepared.fields.fields {
		header = append(header, field.name)
	}
	for _, fs := range e.prepared.compacted {
		for _, field := range fs.fields {
			header = append(header, field.name)
		}
	}
	if err := e.writer.Write(header); err != nil {
		return err
	}

	for _, url := range urls {
		if _, err := e.walker.WalkUrl(ctx, url); err != nil {
			return fmt.Errorf("export %v failed: %w", url, err)
		}
	}

	return nil
}

func (e *CsvExporter) prepare(ctx context.Context, metaId int64, rawRecord *pb.DataRecord) error {
	log := Logger(ctx).Sugar()

	if rawRecord.Metadata != nil {
		modulesInRow := []string{}
		for _, module := range rawRecord.Modules {
			modulesInRow = append(modulesInRow, hex.EncodeToString(module.Id))
		}

		for loopIndex, loopModule := range rawRecord.Modules {
			// Capture loop variables in locals to avoid this common pitfall:
			// https://go.dev/wiki/CommonMistakes#using-goroutines-on-loop-iterator-variables
			moduleIndex := loopIndex
			module := loopModule

			id := hex.EncodeToString(module.Id)

			// Track which modules "conflict" in the sense that they were both
			// on the station at one once. I guess they could be considered
			// siblings?
			if _, ok := e.preparing.conflicts[id]; !ok {
				e.preparing.conflicts[id] = make(map[string]bool)
			}
			for _, otherId := range modulesInRow {
				if otherId != id {
					e.preparing.conflicts[id][otherId] = true
				}
			}

			uniqueLayout := uniqueLayoutKey{
				moduleId: id,
				metaId:   metaId,
			}

			if _, ok := e.preparing.modules[uniqueLayout]; ok {
				continue
			}

			log.Infow("module", "module_id", id, "meta_id", metaId, "module_name", module.Name, "index", moduleIndex, "position", module.Position)

			fields := newFieldSet(module.Name)

			// Wraps a field getter in a check for the module's presence for
			// this row, if the module wasn't present when this row was
			// generated then return nil for no-value.
			checkForModule := func(get fieldFunc) optionalFieldFunc {
				return (func(key uniqueLayoutKey) optionalFieldFunc {
					return func(r *records) *string {
						if _, ok := r.modules[key.moduleId]; ok {
							// We can only use this "getter" if the field is in the position that it thinks.
							// This depends on the meta record. Field accessors are per (metaId, moduleId)
							// combination, so there should be another one that'll find the right value. The
							// scenario here is that a module was on the station and then was moved to another
							// bay, and a second module placed in the same position.
							if r.data.Readings.Meta == uint64(key.metaId) {
								value := get(r)
								return &value

							} else {
								return nil
							}
						} else {
							return nil
						}
					}
				})(uniqueLayout)
			}

			fields.addField("module_index", checkForModule(func(r *records) string {
				return fmt.Sprintf("%d", moduleIndex)
			}))
			fields.addField("module_position", checkForModule(func(r *records) string {
				return fmt.Sprintf("%d", module.Position)
			}))
			fields.addField("module_name", checkForModule(func(r *records) string {
				return module.Name
			}))
			fields.addField("module_id", checkForModule(func(r *records) string {
				return hex.EncodeToString(module.Id)
			}))

			for sensorIndex, sensor := range module.Sensors {
				fields.addField(sensor.Name, (func(moduleIndex, sensorIndex int) optionalFieldFunc {
					return checkForModule(func(r *records) string {
						if moduleIndex >= len(r.data.Readings.SensorGroups) {
							return ""
						}

						sensorGroup := r.data.Readings.SensorGroups[moduleIndex]
						if sensorIndex >= len(sensorGroup.Readings) {
							return ""
						}
						sensor := sensorGroup.Readings[sensorIndex]
						if sensor.GetCalibratedNull() {
							return ""
						}
						return fmt.Sprintf("%v", sensor.GetCalibratedValue())
					})
				})(moduleIndex, sensorIndex))

				fields.addField(fmt.Sprintf("%s_raw_v", sensor.Name), (func(moduleIndex, sensorIndex int) optionalFieldFunc {
					return checkForModule(func(r *records) string {
						if moduleIndex >= len(r.data.Readings.SensorGroups) {
							return ""
						}

						sensorGroup := r.data.Readings.SensorGroups[moduleIndex]
						if sensorIndex >= len(sensorGroup.Readings) {
							return ""
						}
						sensor := sensorGroup.Readings[sensorIndex]
						if sensor.GetUncalibratedNull() {
							return ""
						}
						return fmt.Sprintf("%v", sensor.GetUncalibratedValue())
					})
				})(moduleIndex, sensorIndex))
			}

			e.preparing.modules[uniqueLayout] = fields
			e.preparing.order = append(e.preparing.order, uniqueLayout)
		}
	}

	return nil
}

func (e *CsvExporter) OnSignedMeta(ctx context.Context, signedRecord *pb.SignedRecord, rawRecord *pb.DataRecord, bytes []byte) error {
	return e.OnMeta(ctx, int64(signedRecord.Record), rawRecord, bytes)
}

func (e *CsvExporter) OnMeta(ctx context.Context, recordNumber int64, rawRecord *pb.DataRecord, bytes []byte) error {
	if e.preparing != nil {
		e.preparing.metas[recordNumber] = rawRecord

		if err := e.prepare(ctx, recordNumber, rawRecord); err != nil {
			return err
		}
	}

	return nil
}

func (e *CsvExporter) OnData(ctx context.Context, rawRecord *pb.DataRecord, rawMetaUnused *pb.DataRecord, bytes []byte) error {
	if e.prepared != nil {
		meta, ok := e.prepared.metas[int64(rawRecord.Readings.Meta)]
		if !ok {
			return fmt.Errorf("missing meta: %v", rawRecord.Readings.Meta)
		}

		e.records.data = rawRecord
		if e.records.modules == nil || e.records.meta != meta {
			e.records.meta = meta
			e.records.modules = make(map[string]bool)
			for _, module := range e.records.meta.Modules {
				e.records.modules[hex.EncodeToString(module.Id)] = true
			}
		}

		e.row = make([]string, 0, len(e.prepared.fields.fields))

		for _, field := range e.prepared.fields.fields {
			value := field.get(e.records)
			if value != nil {
				e.row = append(e.row, *value)
			} else {
				e.row = append(e.row, "")
			}
		}

		for _, fs := range e.prepared.compacted {
			for _, field := range fs.fields {
				value := field.get(e.records)
				if value != nil {
					e.row = append(e.row, *value)
				} else {
					e.row = append(e.row, "")
				}
			}
		}

		if err := e.writer.Write(e.row); err != nil {
			return err
		}
	}

	return nil
}

func (e *CsvExporter) OnDone(ctx context.Context) (err error) {
	return nil
}

func ExportQueryParams(de *data.DataExport) (*QueryParams, error) {
	rawParams := &RawQueryParams{}
	if err := json.Unmarshal(de.Args, rawParams); err != nil {
		return nil, err
	}

	return rawParams.BuildQueryParams()
}
