package scaler

import (
	"context"
	"errors"
	"log/slog"
	"testing"
	"time"
)

func TestChooseInitialServerRoutesHealthyMinecraft(t *testing.T) {
	o := newTestOrchestrator(&fakeHealth{healthy: true}, &fakeWorkload{}, &fakePlayers{})

	got := o.ChooseInitialServer(context.Background())
	if got != "minecraft" {
		t.Fatalf("ChooseInitialServer() = %q, want minecraft", got)
	}
	if o.State() != StateReady {
		t.Fatalf("State() = %q, want ready", o.State())
	}
}

func TestChooseInitialServerRoutesOfflineMinecraftToWaiting(t *testing.T) {
	o := newTestOrchestrator(&fakeHealth{}, &fakeWorkload{}, &fakePlayers{})

	got := o.ChooseInitialServer(context.Background())
	if got != "waiting" {
		t.Fatalf("ChooseInitialServer() = %q, want waiting", got)
	}
}

func TestManyJoinsTriggerOneWake(t *testing.T) {
	workload := &fakeWorkload{block: make(chan struct{})}
	o := newTestOrchestrator(&fakeHealth{}, workload, &fakePlayers{})

	for range 10 {
		if got := o.ChooseInitialServer(context.Background()); got != "waiting" {
			t.Fatalf("ChooseInitialServer() = %q, want waiting", got)
		}
	}
	close(workload.block)
	deadline := time.After(time.Second)
	for {
		if workload.calls == 1 {
			return
		}
		select {
		case <-deadline:
			t.Fatalf("wake calls = %d, want 1", workload.calls)
		default:
			time.Sleep(time.Millisecond)
		}
	}
}

func TestReadinessSuccessTransfersWaitingPlayers(t *testing.T) {
	health := &fakeHealth{healthyAfter: 2}
	player := &fakePlayer{id: "alice"}
	o := newTestOrchestrator(health, &fakeWorkload{}, &fakePlayers{players: []WaitingPlayer{player}})

	if err := o.wake(context.Background()); err != nil {
		t.Fatalf("wake() error = %v", err)
	}
	if player.connectedTo != "minecraft" {
		t.Fatalf("connectedTo = %q, want minecraft", player.connectedTo)
	}
}

func TestReadinessSuccessWaitsBeforeTransferringPlayers(t *testing.T) {
	health := &fakeHealth{healthy: true}
	player := &fakePlayer{id: "alice"}
	o := newTestOrchestrator(health, &fakeWorkload{}, &fakePlayers{players: []WaitingPlayer{player}})
	o.cfg.TransferDelay = 5 * time.Millisecond
	o.cfg.WakeTimeout = time.Second

	start := time.Now()
	if err := o.wake(context.Background()); err != nil {
		t.Fatalf("wake() error = %v", err)
	}
	if elapsed := time.Since(start); elapsed < o.cfg.TransferDelay {
		t.Fatalf("elapsed = %s, want at least %s", elapsed, o.cfg.TransferDelay)
	}
	if player.connectedTo != "minecraft" {
		t.Fatalf("connectedTo = %q, want minecraft", player.connectedTo)
	}
}

func TestReadinessTimeoutLeavesPlayersWaiting(t *testing.T) {
	player := &fakePlayer{id: "alice"}
	o := newTestOrchestrator(&fakeHealth{}, &fakeWorkload{}, &fakePlayers{players: []WaitingPlayer{player}})

	err := o.wake(context.Background())
	if err == nil {
		t.Fatal("wake() error = nil, want timeout")
	}
	if player.connectedTo != "" {
		t.Fatalf("connectedTo = %q, want no transfer", player.connectedTo)
	}
	if o.State() != StateFailed {
		t.Fatalf("State() = %q, want failed", o.State())
	}
}

func TestTransferRetries(t *testing.T) {
	player := &fakePlayer{id: "alice", failConnects: 2}
	o := newTestOrchestrator(&fakeHealth{healthy: true}, &fakeWorkload{}, &fakePlayers{players: []WaitingPlayer{player}})

	if err := o.wake(context.Background()); err != nil {
		t.Fatalf("wake() error = %v", err)
	}
	if player.connectCalls != 3 {
		t.Fatalf("connectCalls = %d, want 3", player.connectCalls)
	}
}

func newTestOrchestrator(health *fakeHealth, workload *fakeWorkload, players *fakePlayers) *Orchestrator {
	cfg := Config{
		MinecraftServerName:   "minecraft",
		WaitingServerName:     "waiting",
		WakeTimeout:           20 * time.Millisecond,
		WakePollInterval:      time.Millisecond,
		TransferRetryInterval: time.Millisecond,
		TransferMaxAttempts:   5,
		FailureCooldown:       time.Millisecond,
	}
	return NewOrchestrator(cfg, workload, health, players, slog.New(slog.DiscardHandler))
}

type fakeWorkload struct {
	calls int
	block chan struct{}
}

func (d *fakeWorkload) EnsureRunning(context.Context) error {
	d.calls++
	if d.block != nil {
		<-d.block
	}
	return nil
}

type fakeHealth struct {
	healthy      bool
	healthyAfter int
	calls        int
}

func (h *fakeHealth) Healthy(context.Context) bool {
	h.calls++
	return h.healthy || (h.healthyAfter > 0 && h.calls >= h.healthyAfter)
}

type fakePlayers struct {
	players []WaitingPlayer
}

func (p *fakePlayers) PlayersOn(context.Context, string) []WaitingPlayer {
	return p.players
}

type fakePlayer struct {
	id           string
	failConnects int
	connectCalls int
	connectedTo  string
}

func (p *fakePlayer) ID() string { return p.id }

func (p *fakePlayer) Connect(_ context.Context, server string) error {
	p.connectCalls++
	if p.connectCalls <= p.failConnects {
		return errors.New("temporary transfer failure")
	}
	p.connectedTo = server
	return nil
}
