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
		ScalerMode:            getenv("SCALER_MODE", "azure"),
		AzureSubscriptionID:   os.Getenv("AZURE_SUBSCRIPTION_ID"),
		AzureResourceGroup:    os.Getenv("AZURE_RESOURCE_GROUP"),
		AzureContainerAppName: os.Getenv("AZURE_CONTAINER_APP_NAME"),
		AzureEnvironmentName:  os.Getenv("AZURE_CONTAINER_APP_ENVIRONMENT"),
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
	if cfg.ScalerMode != "local" && cfg.ScalerMode != "azure" {
		return cfg, fmt.Errorf("SCALER_MODE must be local or azure")
	}
	if cfg.ScalerMode == "local" && os.Getenv("TRANSFER_DELAY") == "" {
		cfg.TransferDelay = 5 * time.Second
	}
	if cfg.ScalerMode == "azure" {
		if cfg.AzureSubscriptionID == "" {
			return cfg, fmt.Errorf("AZURE_SUBSCRIPTION_ID is required")
		}
		if cfg.AzureResourceGroup == "" {
			return cfg, fmt.Errorf("AZURE_RESOURCE_GROUP is required")
		}
		if cfg.AzureContainerAppName == "" {
			return cfg, fmt.Errorf("AZURE_CONTAINER_APP_NAME is required")
		}
		if cfg.AzureEnvironmentName == "" {
			return cfg, fmt.Errorf("AZURE_CONTAINER_APP_ENVIRONMENT is required")
		}
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
