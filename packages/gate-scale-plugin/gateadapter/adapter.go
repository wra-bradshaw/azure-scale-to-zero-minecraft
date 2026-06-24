package gateadapter

import (
	"context"
	"fmt"

	"github.com/robinbraemer/event"
	"github.com/will/mc-server/packages/gate-scale-plugin/scaler"
	gateproxy "go.minekube.com/gate/pkg/edition/java/proxy"
)

type Adapter struct {
	proxy        *gateproxy.Proxy
	orchestrator *scaler.Orchestrator
}

func New(proxy *gateproxy.Proxy, orchestrator *scaler.Orchestrator) *Adapter {
	return &Adapter{proxy: proxy, orchestrator: orchestrator}
}

func (a *Adapter) Register() {
	event.Subscribe(a.proxy.Event(), 0, a.onChooseInitialServer)
}

func (a *Adapter) WaitingPlayers() scaler.WaitingPlayers {
	return gateWaitingPlayers{proxy: a.proxy}
}

func (a *Adapter) onChooseInitialServer(e *gateproxy.PlayerChooseInitialServerEvent) {
	name := a.orchestrator.ChooseInitialServer(context.Background())
	server := a.proxy.Server(name)
	if server == nil {
		return
	}
	e.SetInitialServer(server)
}

type gateWaitingPlayers struct {
	proxy *gateproxy.Proxy
}

func (p gateWaitingPlayers) PlayersOn(_ context.Context, serverName string) []scaler.WaitingPlayer {
	server := p.proxy.Server(serverName)
	if server == nil {
		return nil
	}

	var players []scaler.WaitingPlayer
	server.Players().Range(func(player gateproxy.Player) bool {
		players = append(players, gatePlayer{proxy: p.proxy, player: player})
		return true
	})
	return players
}

type gatePlayer struct {
	proxy  *gateproxy.Proxy
	player gateproxy.Player
}

func (p gatePlayer) ID() string {
	return p.player.ID().String()
}

func (p gatePlayer) Connect(ctx context.Context, serverName string) error {
	server := p.proxy.Server(serverName)
	if server == nil {
		return fmt.Errorf("server %q is not registered", serverName)
	}
	if ok := p.player.CreateConnectionRequest(server).ConnectWithIndication(ctx); !ok {
		return fmt.Errorf("connection request to %q was not successful", serverName)
	}
	return nil
}
