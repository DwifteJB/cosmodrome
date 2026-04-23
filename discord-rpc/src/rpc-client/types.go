package rpcclient

import "encoding/json"

const (
	OpHandshake = iota
	OpFrame
	OpClose
	OpPing
	OpPong
)

type Timestamps struct {
	Start int64 `json:"start,omitempty"`
	End   int64 `json:"end,omitempty"`
}

type Assets struct {
	LargeImage string `json:"large_image,omitempty"`
	LargeText  string `json:"large_text,omitempty"`
	SmallImage string `json:"small_image,omitempty"`
	SmallText  string `json:"small_text,omitempty"`
}

type Activity struct {
	Details    string      `json:"details,omitempty"`
	State      string      `json:"state,omitempty"`
	Assets     *Assets     `json:"assets,omitempty"`
	Timestamps *Timestamps `json:"timestamps,omitempty"`
	Type 	  int         `json:"type,omitempty"` // 0=Playing, 1=Streaming, 2=Listening, 3=Watching
}

type Payload struct {
	Cmd   string          `json:"cmd"`
	Args  json.RawMessage `json:"args,omitempty"`
	Evt   string          `json:"evt,omitempty"`
	Nonce string          `json:"nonce,omitempty"`
}

type SetActivityArgs struct {
	PID      int       `json:"pid"`
	Activity *Activity `json:"activity"`
}

type HandshakePayload struct {
	V        int    `json:"v"`
	ClientID string `json:"client_id"`
}

// custom message sent from the flutter app
type SongUpdate struct {
	Type        string `json:"type"`        // SET_ACTIVITY | CLEAR_ACTIVITY | STOP
	Title       string `json:"title"`
	Artist      string `json:"artist"`
	Album       string `json:"album"`
	CoverURL    string `json:"coverUrl"`    // remote http(s) URL for Discord image proxy
	CoverBase64 string `json:"coverBase64"` // base64-encoded image bytes
	CoverArtID  string `json:"coverArtId"`  // stable Subsonic cover art ID (cache key)
	Elapsed     int64  `json:"elapsed"`     // seconds into the track
	Duration    int64  `json:"duration"`    // total track seconds
	Paused      bool   `json:"paused"`
}

// status message sent from the rpc client to the flutter app
type StatusMessage struct {
	Type    string `json:"type"`              // CONNECTED | RECONNECTED | ERROR
	User    string `json:"user,omitempty"`
	Message string `json:"message,omitempty"`
}
