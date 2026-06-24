package scaler

import (
	"context"
	"log/slog"
)

type NoopWorkloadClient struct {
	Logger *slog.Logger
}

func (c NoopWorkloadClient) EnsureRunning(context.Context) error {
	logger := c.Logger
	if logger == nil {
		logger = slog.Default()
	}
	logger.Info("local scaler wake requested; skipping external workload wake")
	return nil
}
