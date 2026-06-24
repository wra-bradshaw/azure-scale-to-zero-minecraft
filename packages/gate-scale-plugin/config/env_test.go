package config

import (
	"strings"
	"testing"
	"time"
)

func TestFromEnvLocalModeDoesNotRequireCloudConfig(t *testing.T) {
	t.Setenv("SCALER_MODE", "local")
	t.Setenv("MC_HOST", "minecraft")

	cfg, err := FromEnv()
	if err != nil {
		t.Fatalf("FromEnv() error = %v", err)
	}
	if cfg.ScalerMode != "local" {
		t.Fatalf("ScalerMode = %q, want local", cfg.ScalerMode)
	}
	if cfg.TransferDelay != 5*time.Second {
		t.Fatalf("TransferDelay = %s, want 5s", cfg.TransferDelay)
	}
}

func TestFromEnvAzureModeRequiresContainerAppConfig(t *testing.T) {
	t.Setenv("SCALER_MODE", "azure")
	t.Setenv("MC_HOST", "minecraft")
	t.Setenv("AZURE_SUBSCRIPTION_ID", "sub")
	t.Setenv("AZURE_RESOURCE_GROUP", "rg")
	t.Setenv("AZURE_CONTAINER_APP_NAME", "minecraft")
	t.Setenv("AZURE_CONTAINER_APP_ENVIRONMENT", "mc-env")

	cfg, err := FromEnv()
	if err != nil {
		t.Fatalf("FromEnv() error = %v", err)
	}
	if cfg.ScalerMode != "azure" {
		t.Fatalf("ScalerMode = %q, want azure", cfg.ScalerMode)
	}
	if cfg.AzureContainerAppName != "minecraft" {
		t.Fatalf("AzureContainerAppName = %q, want minecraft", cfg.AzureContainerAppName)
	}
	if cfg.TransferDelay != 0 {
		t.Fatalf("TransferDelay = %s, want 0s", cfg.TransferDelay)
	}
}

func TestFromEnvTransferDelayOverride(t *testing.T) {
	t.Setenv("SCALER_MODE", "local")
	t.Setenv("MC_HOST", "minecraft")
	t.Setenv("TRANSFER_DELAY", "250ms")

	cfg, err := FromEnv()
	if err != nil {
		t.Fatalf("FromEnv() error = %v", err)
	}
	if cfg.TransferDelay != 250*time.Millisecond {
		t.Fatalf("TransferDelay = %s, want 250ms", cfg.TransferDelay)
	}
}

func TestFromEnvAzureModeReportsMissingConfig(t *testing.T) {
	t.Setenv("SCALER_MODE", "azure")
	t.Setenv("MC_HOST", "minecraft")

	_, err := FromEnv()
	if err == nil {
		t.Fatal("FromEnv() error = nil, want missing Azure config")
	}
	if !strings.Contains(err.Error(), "AZURE_SUBSCRIPTION_ID") {
		t.Fatalf("FromEnv() error = %v, want AZURE_SUBSCRIPTION_ID", err)
	}
}

func TestFromEnvRejectsUnknownScalerMode(t *testing.T) {
	t.Setenv("SCALER_MODE", "bogus")
	t.Setenv("MC_HOST", "minecraft")

	_, err := FromEnv()
	if err == nil {
		t.Fatal("FromEnv() error = nil, want invalid scaler mode")
	}
	if !strings.Contains(err.Error(), "SCALER_MODE") {
		t.Fatalf("FromEnv() error = %v, want SCALER_MODE", err)
	}
}
