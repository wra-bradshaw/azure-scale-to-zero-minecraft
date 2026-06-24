package scaler

import (
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
