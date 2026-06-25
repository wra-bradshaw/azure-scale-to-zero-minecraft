package gateadapter

import (
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/robinbraemer/event"
	"github.com/will/mc-server/packages/gate-scale-plugin/scaler"
	"go.minekube.com/common/minecraft/component"
	gateproxy "go.minekube.com/gate/pkg/edition/java/proxy"
)

type Adapter struct {
	proxy        *gateproxy.Proxy
	orchestrator *scaler.Orchestrator
	allowed      map[string]struct{}
}

func New(proxy *gateproxy.Proxy, orchestrator *scaler.Orchestrator, allowedPlayers ...string) *Adapter {
	allowed := make(map[string]struct{}, len(allowedPlayers))
	for _, player := range allowedPlayers {
		player = strings.ToLower(strings.TrimSpace(player))
		if player != "" {
			allowed[player] = struct{}{}
		}
	}
	return &Adapter{proxy: proxy, orchestrator: orchestrator, allowed: allowed}
}

func AllowedPlayersFromEnv() []string {
	return splitPlayers(os.Getenv("GATE_ALLOWED_PLAYERS"))
}

func (a *Adapter) Register() {
	event.Subscribe(a.proxy.Event(), 0, a.onPreLogin)
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

func (a *Adapter) onPreLogin(e *gateproxy.PreLoginEvent) {
	if len(a.allowed) == 0 {
		return
	}
	if _, ok := a.allowed[strings.ToLower(e.Username())]; ok {
		return
	}
	e.Deny(&component.Text{Content: "You are not whitelisted on this server."})
}

func splitPlayers(value string) []string {
	var players []string
	for _, player := range strings.Split(value, ",") {
		player = strings.TrimSpace(player)
		if player != "" {
			players = append(players, player)
		}
	}
	return players
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
