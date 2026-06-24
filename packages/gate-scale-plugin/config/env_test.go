package config

import (
	"strings"
	"testing"
	"time"
)

func TestFromEnvRequiresMinecraftHost(t *testing.T) {
	_, err := FromEnv()
	if err == nil {
		t.Fatal("FromEnv() error = nil, want missing MC_HOST")
	}
	if !strings.Contains(err.Error(), "MC_HOST") {
		t.Fatalf("FromEnv() error = %v, want MC_HOST", err)
	}
}

func TestFromEnvDefaults(t *testing.T) {
	t.Setenv("MC_HOST", "minecraft")

	cfg, err := FromEnv()
	if err != nil {
		t.Fatalf("FromEnv() error = %v", err)
	}
	if cfg.MinecraftHost != "minecraft" {
		t.Fatalf("MinecraftHost = %q, want minecraft", cfg.MinecraftHost)
	}
	if cfg.TransferDelay != 0 {
		t.Fatalf("TransferDelay = %s, want 0s", cfg.TransferDelay)
	}
}

func TestFromEnvTransferDelayOverride(t *testing.T) {
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
