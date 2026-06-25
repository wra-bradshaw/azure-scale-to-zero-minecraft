package scaler

import (
	"bufio"
	"bytes"
	"context"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"time"
)

const drainingStatusMarker = "mc-server-state=draining"

type MinecraftStatusHealthChecker struct {
	Host    string
	Port    int
	Timeout time.Duration
}

func (h MinecraftStatusHealthChecker) Healthy(ctx context.Context) bool {
	timeout := h.Timeout
	if timeout <= 0 {
		timeout = 2 * time.Second
	}

	address := fmt.Sprintf("%s:%d", h.Host, h.Port)
	dialer := net.Dialer{Timeout: timeout}
	conn, err := dialer.DialContext(ctx, "tcp", address)
	if err != nil {
		return false
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(timeout))

	if err := writeStatusHandshake(conn, h.Host, h.Port); err != nil {
		return false
	}
	status, err := readStatusResponse(conn)
	if err != nil {
		return false
	}
	return !bytes.Contains(status, []byte(drainingStatusMarker))
}

func writeStatusHandshake(w io.Writer, host string, port int) error {
	var body bytes.Buffer
	writeVarInt(&body, 0)
	writeVarInt(&body, 767)
	writeString(&body, host)
	if err := binary.Write(&body, binary.BigEndian, uint16(port)); err != nil {
		return err
	}
	writeVarInt(&body, 1)

	if err := writePacket(w, body.Bytes()); err != nil {
		return err
	}
	return writePacket(w, []byte{0})
}

func readStatusResponse(r io.Reader) ([]byte, error) {
	reader := bufio.NewReader(r)
	packetLength, err := readVarInt(reader)
	if err != nil {
		return nil, err
	}
	if packetLength <= 0 {
		return nil, fmt.Errorf("empty minecraft status response")
	}
	packetID, err := readVarInt(reader)
	if err != nil {
		return nil, err
	}
	if packetID != 0 {
		return nil, fmt.Errorf("unexpected minecraft status packet id %d", packetID)
	}
	responseLength, err := readVarInt(reader)
	if err != nil {
		return nil, err
	}
	if responseLength <= 0 {
		return nil, fmt.Errorf("empty minecraft status json")
	}
	status := make([]byte, responseLength)
	_, err = io.ReadFull(reader, status)
	return status, err
}

func writePacket(w io.Writer, body []byte) error {
	var packet bytes.Buffer
	writeVarInt(&packet, len(body))
	packet.Write(body)
	_, err := w.Write(packet.Bytes())
	return err
}

func writeString(w io.Writer, value string) {
	writeVarInt(w, len(value))
	_, _ = io.WriteString(w, value)
}

func writeVarInt(w io.Writer, value int) {
	for {
		if value&^0x7F == 0 {
			_, _ = w.Write([]byte{byte(value)})
			return
		}
		_, _ = w.Write([]byte{byte(value&0x7F | 0x80)})
		value >>= 7
	}
}

func readVarInt(r io.ByteReader) (int, error) {
	var value int
	for position := 0; position < 32; position += 7 {
		current, err := r.ReadByte()
		if err != nil {
			return 0, err
		}
		value |= int(current&0x7F) << position
		if current&0x80 == 0 {
			return value, nil
		}
	}
	return 0, fmt.Errorf("minecraft varint is too large")
}
