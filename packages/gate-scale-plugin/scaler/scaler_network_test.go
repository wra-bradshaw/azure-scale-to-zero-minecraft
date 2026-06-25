package scaler

import (
	"bytes"
	"context"
	"net"
	"testing"
	"time"
)

func TestTCPWakeClientEnsureRunningDialsTarget(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Listen() error = %v", err)
	}
	defer listener.Close()

	accepted := make(chan struct{})
	go func() {
		conn, err := listener.Accept()
		if err == nil {
			_ = conn.Close()
			close(accepted)
		}
	}()

	addr := listener.Addr().(*net.TCPAddr)
	client := TCPWakeClient{Host: "127.0.0.1", Port: addr.Port}
	if err := client.EnsureRunning(context.Background()); err != nil {
		t.Fatalf("EnsureRunning() error = %v", err)
	}

	select {
	case <-accepted:
	case <-time.After(time.Second):
		t.Fatal("TCPWakeClient did not connect to target")
	}
}

func TestTCPWakeClientEnsureRunningIgnoresDialFailure(t *testing.T) {
	client := TCPWakeClient{Host: "127.0.0.1", Port: 1}
	if err := client.EnsureRunning(context.Background()); err != nil {
		t.Fatalf("EnsureRunning() error = %v", err)
	}
}

func TestMinecraftStatusHealthCheckerTreatsNormalStatusAsHealthy(t *testing.T) {
	host, port := startStatusServer(t, `{"version":{"name":"Paper","protocol":767},"description":{"text":"ready"}}`)

	checker := MinecraftStatusHealthChecker{Host: host, Port: port, Timeout: time.Second}
	if !checker.Healthy(context.Background()) {
		t.Fatal("Healthy() = false, want true")
	}
}

func TestMinecraftStatusHealthCheckerTreatsDrainingStatusAsUnhealthy(t *testing.T) {
	host, port := startStatusServer(t, `{"version":{"name":"Paper","protocol":767},"description":{"text":"mc-server-state=draining"}}`)

	checker := MinecraftStatusHealthChecker{Host: host, Port: port, Timeout: time.Second}
	if checker.Healthy(context.Background()) {
		t.Fatal("Healthy() = true, want false")
	}
}

func startStatusServer(t *testing.T, status string) (string, int) {
	t.Helper()

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Listen() error = %v", err)
	}
	t.Cleanup(func() {
		_ = listener.Close()
	})

	go func() {
		conn, err := listener.Accept()
		if err != nil {
			return
		}
		defer conn.Close()

		var body bytes.Buffer
		writeVarInt(&body, 0)
		writeString(&body, status)
		_ = writePacket(conn, body.Bytes())
	}()

	addr := listener.Addr().(*net.TCPAddr)
	return "127.0.0.1", addr.Port
}
