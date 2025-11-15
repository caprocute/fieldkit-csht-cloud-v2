package querying

import (
	"context"
	"time"

	"gitlab.com/fieldkit/cloud/server/backend"
	"gitlab.com/fieldkit/cloud/server/data"
)

type StationTailInfo struct {
	BucketSize    int `json:"bucketSize"`
	BucketSamples int `json:"bucketSamples"`
}

type SensorTailData struct {
	Data     []*backend.DataRow         `json:"data"`
	Stations map[int32]*StationTailInfo `json:"stations"`
}

type AggregateInfo struct {
	Name     string    `json:"name"`
	Interval int32     `json:"interval"`
	Complete bool      `json:"complete"`
	Start    time.Time `json:"start"`
	End      time.Time `json:"end"`
}

type QueriedData struct {
	Data          []*backend.DataRow    `json:"data"`
	BucketSize    int                   `json:"bucketSize"`
	BucketSamples int                   `json:"bucketSamples"`
	DataEnd       *data.NumericWireTime `json:"dataEnd"`
}

type StationLastTime struct {
	Last *data.NumericWireTime `json:"last"`
}

type RecentlyAggregated struct {
	Windows  map[time.Duration][]*backend.DataRow `json:"windows"`
	Stations map[int32]*StationLastTime           `json:"stations"`
}

func NewRecentlyAggregated() *RecentlyAggregated {
	return &RecentlyAggregated{
		Windows:  make(map[time.Duration][]*backend.DataRow),
		Stations: make(map[int32]*StationLastTime),
	}
}

type DataBackend interface {
	QueryData(ctx context.Context, qp *backend.QueryParams) (*QueriedData, error)
	QueryTail(ctx context.Context, stationIDs []int32) (*SensorTailData, error)
	QueryRecentlyAggregated(ctx context.Context, stationIDs []int32, windows []time.Duration) (*RecentlyAggregated, error)
}
