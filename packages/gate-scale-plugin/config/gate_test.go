package config

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestGateConfigPathFromArgs(t *testing.T) {
	t.Setenv("GATE_CONFIG", "/env/config.yml")

	tests := []struct {
		name string
		args []string
		want string
	}{
		{name: "long flag", args: []string{"--config", "/etc/gate/config.yml"}, want: "/etc/gate/config.yml"},
		{name: "long flag equals", args: []string{"--config=/etc/gate/config.yml"}, want: "/etc/gate/config.yml"},
		{name: "short flag", args: []string{"-c", "/etc/gate/config.yml"}, want: "/etc/gate/config.yml"},
		{name: "short flag equals", args: []string{"-c=/etc/gate/config.yml"}, want: "/etc/gate/config.yml"},
		{name: "env fallback", args: nil, want: "/env/config.yml"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := GateConfigPath(tt.args); got != tt.want {
				t.Fatalf("GateConfigPath() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestGateConfigPathDefault(t *testing.T) {
	t.Setenv("GATE_CONFIG", "")

	if got := GateConfigPath(nil); got != "config.yml" {
		t.Fatalf("GateConfigPath() = %q, want config.yml", got)
	}
}

func TestFromGateConfigFileReadsAllowedPlayers(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.yml")
	content := []byte(`config:
  bind: 0.0.0.0:25565
scaleToZero:
  allowedPlayers:
    - MrMoose65
    - OtherPlayer
`)
	if err := os.WriteFile(path, content, 0o600); err != nil {
		t.Fatalf("WriteFile() error = %v", err)
	}

	cfg, err := FromGateConfigFile(path)
	if err != nil {
		t.Fatalf("FromGateConfigFile() error = %v", err)
	}
	want := []string{"MrMoose65", "OtherPlayer"}
	if !reflect.DeepEqual(cfg.ScaleToZero.AllowedPlayers, want) {
		t.Fatalf("AllowedPlayers = %#v, want %#v", cfg.ScaleToZero.AllowedPlayers, want)
	}
}
