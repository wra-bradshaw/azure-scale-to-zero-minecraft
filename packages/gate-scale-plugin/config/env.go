package config

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/will/mc-server/packages/gate-scale-plugin/scaler"
)

func FromEnv() (scaler.Config, error) {
	cfg := scaler.Config{
		MinecraftServerName:   getenv("MC_SERVER_NAME", "minecraft"),
		WaitingServerName:     getenv("WAITING_SERVER_NAME", "waiting"),
		MinecraftHost:         os.Getenv("MC_HOST"),
		MinecraftPort:         getenvInt("MC_PORT", 25565),
		WakeTimeout:           getenvDuration("WAKE_TIMEOUT", 8*time.Minute),
		WakePollInterval:      getenvDuration("WAKE_POLL_INTERVAL", 5*time.Second),
		TransferDelay:         getenvDuration("TRANSFER_DELAY", 0),
		TransferRetryInterval: getenvDuration("TRANSFER_RETRY_INTERVAL", 2*time.Second),
		TransferMaxAttempts:   getenvInt("TRANSFER_MAX_ATTEMPTS", 5),
		FailureCooldown:       getenvDuration("WAKE_FAILURE_COOLDOWN", 1*time.Minute),
	}
	if cfg.MinecraftHost == "" {
		return cfg, fmt.Errorf("MC_HOST is required")
	}
	return cfg, nil
}

func getenv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func getenvInt(key string, fallback int) int {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func getenvDuration(key string, fallback time.Duration) time.Duration {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	parsed, err := time.ParseDuration(value)
	if err != nil {
		return fallback
	}
	return parsed
}
