package scaler

import (
	"context"
	"errors"
	"log/slog"
	"sync"
	"time"
)

type State string

const (
	StateIdle     State = "idle"
	StateStarting State = "starting"
	StateReady    State = "ready"
	StateFailed   State = "failed"
)

type Config struct {
	MinecraftServerName   string
	WaitingServerName     string
	MinecraftHost         string
	MinecraftPort         int
	WakeTimeout           time.Duration
	WakePollInterval      time.Duration
	TransferDelay         time.Duration
	TransferRetryInterval time.Duration
	TransferMaxAttempts   int
	FailureCooldown       time.Duration
}

type WorkloadClient interface {
	EnsureRunning(context.Context) error
}

type HealthChecker interface {
	Healthy(context.Context) bool
}

type WaitingPlayer interface {
	ID() string
	Connect(context.Context, string) error
}

type WaitingPlayers interface {
	PlayersOn(context.Context, string) []WaitingPlayer
}

type Orchestrator struct {
	cfg      Config
	workload WorkloadClient
	health   HealthChecker
	players  WaitingPlayers
	logger   *slog.Logger

	mu             sync.Mutex
	state          State
	wakeInProgress bool
	lastFailure    time.Time
}

func NewOrchestrator(cfg Config, workload WorkloadClient, health HealthChecker, players WaitingPlayers, logger *slog.Logger) *Orchestrator {
	if cfg.TransferMaxAttempts <= 0 {
		cfg.TransferMaxAttempts = 5
	}
	if cfg.WakeTimeout <= 0 {
		cfg.WakeTimeout = 8 * time.Minute
	}
	if cfg.WakePollInterval <= 0 {
		cfg.WakePollInterval = 5 * time.Second
	}
	if cfg.TransferRetryInterval <= 0 {
		cfg.TransferRetryInterval = 2 * time.Second
	}
	if cfg.FailureCooldown <= 0 {
		cfg.FailureCooldown = time.Minute
	}
	if logger == nil {
		logger = slog.Default()
	}
	return &Orchestrator{
		cfg:      cfg,
		workload: workload,
		health:   health,
		players:  players,
		logger:   logger,
		state:    StateIdle,
	}
}

func (o *Orchestrator) ChooseInitialServer(ctx context.Context) string {
	if o.health.Healthy(ctx) {
		o.setState(StateReady)
		return o.cfg.MinecraftServerName
	}

	if o.shouldStartWake() {
		go o.wake(context.Background())
	}
	return o.cfg.WaitingServerName
}

func (o *Orchestrator) State() State {
	o.mu.Lock()
	defer o.mu.Unlock()
	return o.state
}

func (o *Orchestrator) shouldStartWake() bool {
	o.mu.Lock()
	defer o.mu.Unlock()

	if o.wakeInProgress {
		return false
	}
	if o.state == StateFailed && time.Since(o.lastFailure) < o.cfg.FailureCooldown {
		return false
	}
	o.wakeInProgress = true
	o.state = StateStarting
	return true
}

func (o *Orchestrator) wake(ctx context.Context) error {
	defer func() {
		o.mu.Lock()
		o.wakeInProgress = false
		o.mu.Unlock()
	}()

	wakeCtx, cancel := context.WithTimeout(ctx, o.cfg.WakeTimeout)
	defer cancel()

	if err := o.workload.EnsureRunning(wakeCtx); err != nil {
		o.markFailure("minecraft workload wake failed", err)
		return err
	}

	ticker := time.NewTicker(o.cfg.WakePollInterval)
	defer ticker.Stop()

	for {
		if o.health.Healthy(wakeCtx) {
			o.setState(StateReady)
			if !o.waitBeforeTransfer(wakeCtx) {
				return wakeCtx.Err()
			}
			o.transferWaitingPlayers(wakeCtx)
			return nil
		}

		select {
		case <-wakeCtx.Done():
			err := errors.New("minecraft readiness timed out")
			o.markFailure("minecraft readiness timed out", err)
			return err
		case <-ticker.C:
		}
	}
}

func (o *Orchestrator) waitBeforeTransfer(ctx context.Context) bool {
	if o.cfg.TransferDelay <= 0 {
		return true
	}
	o.logger.Info("waiting before transferring players", "delay", o.cfg.TransferDelay)
	timer := time.NewTimer(o.cfg.TransferDelay)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-timer.C:
		return true
	}
}

func (o *Orchestrator) transferWaitingPlayers(ctx context.Context) {
	if o.players == nil {
		return
	}
	for _, player := range o.players.PlayersOn(ctx, o.cfg.WaitingServerName) {
		o.transferPlayer(ctx, player)
	}
}

func (o *Orchestrator) transferPlayer(ctx context.Context, player WaitingPlayer) {
	for attempt := 1; attempt <= o.cfg.TransferMaxAttempts; attempt++ {
		err := player.Connect(ctx, o.cfg.MinecraftServerName)
		if err == nil {
			o.logger.Info("transferred waiting player", "player", player.ID(), "target", o.cfg.MinecraftServerName)
			return
		}
		o.logger.Warn("transfer failed", "player", player.ID(), "attempt", attempt, "err", err)

		select {
		case <-ctx.Done():
			return
		case <-time.After(o.cfg.TransferRetryInterval):
		}
	}
}

func (o *Orchestrator) setState(state State) {
	o.mu.Lock()
	o.state = state
	o.mu.Unlock()
}

func (o *Orchestrator) markFailure(message string, err error) {
	o.mu.Lock()
	o.state = StateFailed
	o.lastFailure = time.Now()
	o.mu.Unlock()
	o.logger.Warn(message, "err", err)
}
