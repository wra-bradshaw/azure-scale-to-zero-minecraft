package main

import (
	"context"
	"log/slog"

	"go.minekube.com/gate/cmd/gate"
	gateproxy "go.minekube.com/gate/pkg/edition/java/proxy"

	"github.com/will/mc-server/packages/gate-scale-plugin/config"
	"github.com/will/mc-server/packages/gate-scale-plugin/gateadapter"
	"github.com/will/mc-server/packages/gate-scale-plugin/scaler"
)

func main() {
	gateproxy.Plugins = append(gateproxy.Plugins, gateproxy.Plugin{
		Name: "scale-to-zero",
		Init: func(ctx context.Context, proxy *gateproxy.Proxy) error {
			cfg, err := config.FromEnv()
			if err != nil {
				return err
			}

			adapter := gateadapter.New(proxy, nil)
			orchestrator := scaler.NewOrchestrator(
				cfg,
				scaler.TCPWakeClient{Host: cfg.MinecraftHost, Port: cfg.MinecraftPort},
				scaler.MinecraftStatusHealthChecker{Host: cfg.MinecraftHost, Port: cfg.MinecraftPort},
				adapter.WaitingPlayers(),
				slog.Default(),
			)
			adapter = gateadapter.New(proxy, orchestrator)
			adapter.Register()
			return nil
		},
	})

	gate.Execute()
}
