package scaler

import (
	"context"
	"log/slog"
	"testing"
)

func TestNoopWorkloadClientEnsureRunning(t *testing.T) {
	client := NoopWorkloadClient{Logger: slog.New(slog.DiscardHandler)}

	if err := client.EnsureRunning(context.Background()); err != nil {
		t.Fatalf("EnsureRunning() error = %v", err)
	}
}
