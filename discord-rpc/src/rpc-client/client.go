package rpcclient

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"os"
	"time"
)

type Client struct {
	ClientID  string
	conn      net.Conn
	connected bool
	user      string
}

func NewClient(clientID string) *Client {
	return &Client{ClientID: clientID}
}

func (c *Client) Connect() error {
	if c.conn != nil {
		c.conn.Close()
		c.conn = nil
	}
	c.connected = false

	conn, err := connectToDiscord()
	if err != nil {
		return err
	}
	c.conn = conn

	if err := c.sendHandshake(); err != nil {
		conn.Close()
		c.conn = nil
		return fmt.Errorf("handshake: %w", err)
	}

	_, payload, err := c.readFrame()
	if err != nil {
		conn.Close()
		c.conn = nil
		return fmt.Errorf("reading READY: %w", err)
	}

	var ready struct {
		Evt  string `json:"evt"`
		Data struct {
			User struct {
				Username string `json:"username"`
			} `json:"user"`
		} `json:"data"`
	}
	if json.Unmarshal(payload, &ready) == nil && ready.Evt == "READY" {
		c.user = ready.Data.User.Username
	}

	c.connected = true
	return nil
}

func (c *Client) Close() {
	if c.conn != nil {
		c.writeFrame(OpClose, []byte(`{}`))
		c.conn.Close()
		c.conn = nil
	}
	c.connected = false
}

// Shutdown clears the Discord activity then closes the connection cleanly.
// It caps the total time at 700ms so callers don't block indefinitely.
func (c *Client) Shutdown() {
	if c.conn == nil {
		return
	}
	c.conn.SetDeadline(time.Now().Add(700 * time.Millisecond))
	c.ClearActivity()
	c.Close()
}

func (c *Client) IsConnected() bool { return c.connected }
func (c *Client) User() string      { return c.user }

// update discord rpc
func (c *Client) SetActivity(activity *Activity) error {
	if !c.connected {
		return fmt.Errorf("not connected")
	}

	args, err := json.Marshal(SetActivityArgs{PID: os.Getpid(), Activity: activity})
	if err != nil {
		return err
	}

	payload, err := json.Marshal(Payload{
		Cmd:   "SET_ACTIVITY",
		Args:  json.RawMessage(args),
		Nonce: fmt.Sprintf("%d", time.Now().UnixNano()),
	})
	if err != nil {
		return err
	}

	if err := c.writeFrame(OpFrame, payload); err != nil {
		c.connected = false
		return err
	}

	// drain response to avoid broken pipe
	c.conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	c.readFrame()
	c.conn.SetReadDeadline(time.Time{})

	return nil
}

func (c *Client) ClearActivity() error {
	return c.SetActivity(nil)
}

func (c *Client) sendHandshake() error {
	payload, err := json.Marshal(HandshakePayload{V: 1, ClientID: c.ClientID})
	if err != nil {
		return err
	}
	return c.writeFrame(OpHandshake, payload)
}

func (c *Client) writeFrame(op int, payload []byte) error {
	header := make([]byte, 8)
	binary.LittleEndian.PutUint32(header[0:4], uint32(op))
	binary.LittleEndian.PutUint32(header[4:8], uint32(len(payload)))
	if _, err := c.conn.Write(header); err != nil {
		return err
	}
	_, err := c.conn.Write(payload)
	return err
}

func (c *Client) readFrame() (int, []byte, error) {
	header := make([]byte, 8)
	if _, err := io.ReadFull(c.conn, header); err != nil {
		return 0, nil, err
	}
	op := int(binary.LittleEndian.Uint32(header[0:4]))
	size := binary.LittleEndian.Uint32(header[4:8])
	payload := make([]byte, size)
	if _, err := io.ReadFull(c.conn, payload); err != nil {
		return 0, nil, err
	}
	return op, payload, nil
}
