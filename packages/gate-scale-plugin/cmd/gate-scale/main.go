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
			var workload scaler.WorkloadClient
			switch cfg.ScalerMode {
			case "local":
				workload = scaler.NoopWorkloadClient{Logger: slog.Default()}
			case "azure":
				workload = scaler.AzureContainerAppClient{
					SubscriptionID:   cfg.AzureSubscriptionID,
					ResourceGroup:    cfg.AzureResourceGroup,
					ContainerAppName: cfg.AzureContainerAppName,
					WakeHost:         cfg.MinecraftHost,
					WakePort:         cfg.MinecraftPort,
				}
			}
			orchestrator := scaler.NewOrchestrator(
				cfg,
				workload,
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
