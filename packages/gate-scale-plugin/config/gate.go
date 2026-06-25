package config

import (
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

type GateConfig struct {
	ScaleToZero ScaleToZeroConfig `yaml:"scaleToZero"`
}

type ScaleToZeroConfig struct {
	AllowedPlayers []string `yaml:"allowedPlayers"`
}

func GateConfigPath(args []string) string {
	for i := 0; i < len(args); i++ {
		arg := args[i]
		if arg == "--config" || arg == "-c" {
			if i+1 < len(args) {
				return args[i+1]
			}
			continue
		}
		if value, ok := strings.CutPrefix(arg, "--config="); ok {
			return value
		}
		if value, ok := strings.CutPrefix(arg, "-c="); ok {
			return value
		}
	}
	if value := os.Getenv("GATE_CONFIG"); value != "" {
		return value
	}
	return "config.yml"
}

func FromGateConfigFile(path string) (GateConfig, error) {
	var cfg GateConfig
	content, err := os.ReadFile(path)
	if err != nil {
		return cfg, err
	}
	err = yaml.Unmarshal(content, &cfg)
	return cfg, err
}
