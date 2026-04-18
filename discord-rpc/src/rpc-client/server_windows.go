//go:build windows

package rpcclient

import (
	"fmt"
	"net"

	"gopkg.in/natefinch/npipe.v2"
)

func connectToDiscord() (net.Conn, error) {
	for i := 0; i <= 9; i++ {
		path := fmt.Sprintf(`\\.\pipe\discord-ipc-%d`, i)
		conn, err := npipe.Dial(path)
		if err == nil {
			return conn, nil
		}
	}
	return nil, fmt.Errorf("discord ipc pipe not found - is discord running??")
}
