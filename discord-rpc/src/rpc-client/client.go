package rpcclient

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"os"
	"sync"
	"time"
)

type Client struct {
	ClientID  string
	conn      net.Conn
	connected bool
	user      string
	mu        sync.Mutex
}

func NewClient(clientID string) *Client {
	return &Client{ClientID: clientID}
}

func (c *Client) Connect() error {
	c.mu.Lock()
	defer c.mu.Unlock()

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
	c.mu.Lock()
	defer c.mu.Unlock()
	c.closeLocked()
}

// Shutdown clears the Discord activity then closes the connection cleanly.
// It caps the total time at 700ms so callers don't block indefinitely.
func (c *Client) Shutdown() {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.conn == nil {
		return
	}
	c.conn.SetDeadline(time.Now().Add(700 * time.Millisecond))
	c.setActivityLocked(nil) //nolint:errcheck
	c.closeLocked()
}

func (c *Client) IsConnected() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.connected
}

func (c *Client) User() string {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.user
}

// returns nil if thhe connection is alive, or an error if the peer has closed it.
func (c *Client) CheckAlive() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if !c.connected || c.conn == nil {
		return fmt.Errorf("not connected")
	}
	c.conn.SetReadDeadline(time.Now().Add(10 * time.Millisecond))
	defer c.conn.SetReadDeadline(time.Time{})
	_, _, err := c.readFrame()
	if err != nil {
		if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
			return nil // alive, just no pending data
		}
		c.connected = false
		return err
	}
	return nil
}

func (c *Client) SetActivity(activity *Activity) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.setActivityLocked(activity)
}

func (c *Client) ClearActivity() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.setActivityLocked(nil)
}

func (c *Client) setActivityLocked(activity *Activity) error {
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

func (c *Client) closeLocked() {
	if c.conn != nil {
		c.writeFrame(OpClose, []byte(`{}`)) //nolint:errcheck
		c.conn.Close()
		c.conn = nil
	}
	c.connected = false
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
