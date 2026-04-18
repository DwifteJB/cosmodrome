package main

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	rpc "rmfosho/cosmodrome-discord-rpc/src/rpc-client"
)

const clientID = "1494838902970908713" // TODO: make this configurable

type cacheEntry struct {
	url        string
	uploadedAt time.Time
}

var (
	imageServerURL = "https://api-cosmodrome.rmfosho.me"
	cacheEntryTTL  = 50 * time.Minute // updated at startup from GET /ttl
	coverCache     = map[string]cacheEntry{}
	coverCacheMu   sync.Mutex
)

// gets TTL to see if needs to upload
func fetchServerTTL() {
	resp, err := http.Get(imageServerURL + "/ttl")
	if err != nil {
		return
	}
	defer resp.Body.Close()

	var body struct {
		TTLSeconds int `json:"ttl_seconds"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil || body.TTLSeconds <= 0 {
		return
	}

	cacheEntryTTL = time.Duration(float64(body.TTLSeconds)*0.9) * time.Second
}

func emit(msg rpc.StatusMessage) {
	b, _ := json.Marshal(msg)
	fmt.Fprintln(os.Stdout, string(b))
}

// fetchChallenge retrieves a single-use PoW challenge from the image server.
func fetchChallenge() (ch string, difficulty int, err error) {
	resp, err := http.Get(imageServerURL + "/challenge")
	if err != nil {
		return "", 0, err
	}
	defer resp.Body.Close()

	var body struct {
		Challenge  string `json:"challenge"`
		Difficulty int    `json:"difficulty"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return "", 0, err
	}
	return body.Challenge, body.Difficulty, nil
}

// solvePoW iterates nonces until SHA256(challenge+nonce) starts with
// `difficulty` zero bytes, then returns the winning nonce.
// this is done to prevent bots & spammy clients uploading a ton of images
func solvePoW(ch string, difficulty int) int {
	for nonce := 0; ; nonce++ {
		hash := sha256.Sum256([]byte(fmt.Sprintf("%s%d", ch, nonce)))
		valid := true
		for i := 0; i < difficulty; i++ {
			if hash[i] != 0 {
				valid = false
				break
			}
		}
		if valid {
			return nonce
		}
	}
}

// imageExists does a HEAD request to confirm the URL is still alive on the server.
func imageExists(url string) bool {
	req, err := http.NewRequest(http.MethodHead, url, nil)
	if err != nil {
		return false
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return false
	}
	resp.Body.Close()
	return resp.StatusCode == http.StatusOK
}

// uploadCoverArt caches by artID. On a cache hit it verifies the URL is still
func uploadCoverArt(artID, b64 string) string {
	coverCacheMu.Lock()
	e, ok := coverCache[artID]
	coverCacheMu.Unlock()

	if ok && time.Since(e.uploadedAt) < cacheEntryTTL && imageExists(e.url) {
		return e.url
	}

	// evict stale entry if present
	if ok {
		coverCacheMu.Lock()
		delete(coverCache, artID)
		coverCacheMu.Unlock()
	}

	ch, difficulty, err := fetchChallenge()
	if err != nil {
		return ""
	}
	nonce := solvePoW(ch, difficulty)

	body, _ := json.Marshal(map[string]any{"image": b64, "challenge": ch, "nonce": nonce})
	req, err := http.NewRequest(http.MethodPost, imageServerURL+"/upload", bytes.NewReader(body))
	if err != nil {
		return ""
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return ""
	}

	var result struct {
		URL string `json:"url"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil || result.URL == "" {
		return ""
	}

	coverCacheMu.Lock()
	coverCache[artID] = cacheEntry{url: result.URL, uploadedAt: time.Now()}
	coverCacheMu.Unlock()

	return result.URL
}

func buildActivity(msg rpc.SongUpdate) *rpc.Activity {
	largeImage := "app_logo"

	if imageServerURL != "" && msg.CoverArtID != "" && msg.CoverBase64 != "" {
		if url := uploadCoverArt(msg.CoverArtID, msg.CoverBase64); url != "" {
			largeImage = url
		}
	}

	activity := &rpc.Activity{
		Details: msg.Title,
		State:   msg.Artist,
		Assets: &rpc.Assets{
			LargeImage: largeImage,
			LargeText:  msg.Album,
			SmallImage: "music_icon",
			SmallText:  "Listening on Cosmodrome",
		},
		Type: 2, // for "listening"
	}

	if msg.Duration > 0 && !msg.Paused {
		now := time.Now().Unix()
		activity.Timestamps = &rpc.Timestamps{
			Start: now - msg.Elapsed,
			End:   now - msg.Elapsed + msg.Duration,
		}
	}

	return activity
}

func main() {
	fetchServerTTL()

	client := rpc.NewClient(clientID)

	// tracks whether we've ever successfully connected (CONNECTED vs RECONNECTED)
	var everConnected atomic.Bool

	connectAndEmit := func() bool {
		if err := client.Connect(); err != nil {
			return false
		}
		msgType := "RECONNECTED"
		if everConnected.CompareAndSwap(false, true) {
			msgType = "CONNECTED"
		}
		emit(rpc.StatusMessage{Type: msgType, User: client.User()})
		return true
	}

	// try initial connection immediately
	connectAndEmit()

	// catch SIGTERM (sent by Flutter's Process.kill()) so we can clear activity
	// even if the STOP message never arrives
	go func() {
		sig := make(chan os.Signal, 1)
		signal.Notify(sig, syscall.SIGTERM, os.Interrupt)
		<-sig
		client.Shutdown()
		os.Exit(0)
	}()

	// detect disconnects and reconnect automatically
	go func() {
		ticker := time.NewTicker(5 * time.Second)
		defer ticker.Stop()
		disconnectedEmitted := false
		for range ticker.C {
			if client.IsConnected() {
				if err := client.CheckAlive(); err != nil {
					emit(rpc.StatusMessage{Type: "DISCONNECTED"})
					disconnectedEmitted = true
				} else {
					disconnectedEmitted = false
				}
			} else {
				if !disconnectedEmitted {
					emit(rpc.StatusMessage{Type: "DISCONNECTED"})
					disconnectedEmitted = true
				}
				connectAndEmit()
				if client.IsConnected() {
					disconnectedEmitted = false
				}
			}
		}
	}()

	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024)

	for scanner.Scan() {
		var msg rpc.SongUpdate
		if err := json.Unmarshal(scanner.Bytes(), &msg); err != nil {
			continue
		}

		switch msg.Type {
		case "SET_ACTIVITY":
			activity := buildActivity(msg)
			if err := client.SetActivity(activity); err != nil {
				emit(rpc.StatusMessage{Type: "DISCONNECTED"})
				// try inline reconnect so the current activity is re-sent immediately
				if connectAndEmit() {
					client.SetActivity(activity) //nolint:errcheck
				}
			}

		case "CLEAR_ACTIVITY":
			client.ClearActivity()

		case "STOP":
			client.Shutdown()
			return
		}
	}
}
