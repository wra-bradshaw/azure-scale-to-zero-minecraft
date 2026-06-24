package scaler

import (
	"context"
	"fmt"
	"net"
	"time"
)

type TCPWakeClient struct {
	Host string
	Port int
}

func (c TCPWakeClient) EnsureRunning(ctx context.Context) error {
	if c.Host == "" || c.Port == 0 {
		return nil
	}
	dialCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	conn, err := (&net.Dialer{}).DialContext(dialCtx, "tcp", fmt.Sprintf("%s:%d", c.Host, c.Port))
	if err == nil {
		_ = conn.Close()
	}
	return nil
}
