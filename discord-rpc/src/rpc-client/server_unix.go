//go:build !windows

package rpcclient

import (
	"fmt"
	"net"
	"os"
	"strings"
)

var ipcPathTemplates = []string{
	// macos
	"${TMPDIR}/discord-ipc-",

	// linux
	"${XDG_RUNTIME_DIR}/discord-ipc-",
	"${TMP}/discord-ipc-",
	"${TEMP}/discord-ipc-",
	"/tmp/discord-ipc-",
	"/run/user/{uid}/discord-ipc-",
	"/run/user/{uid}/snap.discord/discord-ipc-",
	"/run/user/{uid}/flatpak/app/com.discordapp.Discord/current/discord-ipc-",
	"/run/user/1000/snap.discord/discord-ipc-",
	"/run/user/1000/.flatpak/com.discordapp.Discord/xdg-run/discord-ipc-",
}

func expandPath(tmpl string) string {
	path := tmpl
	for {
		start := strings.Index(path, "${")
		if start == -1 {
			break
		}
		end := strings.Index(path[start:], "}")
		if end == -1 {
			break
		}
		end += start
		varValue := os.Getenv(path[start+2 : end])
		path = path[:start] + varValue + path[end+1:]
	}
	return strings.ReplaceAll(path, "{uid}", fmt.Sprintf("%d", os.Getuid()))
}

func connectToDiscord() (net.Conn, error) {
	for i := 0; i <= 9; i++ {
		for _, tmpl := range ipcPathTemplates {
			path := expandPath(tmpl) + fmt.Sprintf("%d", i)
			if _, err := os.Stat(path); err != nil {
				continue
			}
			conn, err := net.Dial("unix", path)
			if err == nil {
				return conn, nil
			}
		}
	}
	return nil, fmt.Errorf("discord ipc socket not found - is Discord running??")
}
