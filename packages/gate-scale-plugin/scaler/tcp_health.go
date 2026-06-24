package scaler

import (
	"context"
	"fmt"
	"net"
	"time"
)

type TCPHealthChecker struct {
	Host    string
	Port    int
	Timeout time.Duration
}

func (h TCPHealthChecker) Healthy(ctx context.Context) bool {
	timeout := h.Timeout
	if timeout <= 0 {
		timeout = 2 * time.Second
	}
	dialer := net.Dialer{Timeout: timeout}
	conn, err := dialer.DialContext(ctx, "tcp", fmt.Sprintf("%s:%d", h.Host, h.Port))
	if err != nil {
		return false
	}
	_ = conn.Close()
	return true
}
