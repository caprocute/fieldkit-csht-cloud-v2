package handlers

import (
	"github.com/montanaflynn/stats"
)

var (
	AggregateNames = []string{"24h", "6h", "1h", "10m", "1m"}
)

type AggregationFunction interface {
	Apply(values []float64) (float64, error)
}

type AverageFunction struct {
}

func (f *AverageFunction) Apply(values []float64) (float64, error) {
	return stats.Mean(values)
}

type MaximumFunction struct {
}

func (f *MaximumFunction) Apply(values []float64) (float64, error) {
	return stats.Max(values)
}

type AggregateSensorKey struct {
	SensorKey string
	ModuleID  int64
}
