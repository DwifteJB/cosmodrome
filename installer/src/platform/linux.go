//go:build !windows

package platform

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"fyne.io/fyne/v2"
	fyneDialog "fyne.io/fyne/v2/dialog"
)

const ExeName = "cosmodrome"
const appName = "Cosmodrome"

func GetDefaultInstallDir() string {
	home, err := os.UserHomeDir()
	if err != nil {
		home = os.Getenv("HOME")
	}
	return filepath.Join(home, ".local", "share", "me.rmfosho.cosmodrome") // use this since uhh one of the plugins in flutter also uses this dir for caching, just makes sense
}

func DetectExistingInstall() (string, bool) {
	// check if running from an existing installation directory
	exePath, err := os.Executable()
	if err == nil {
		exeDir := filepath.Dir(exePath)
		if info, err := os.Stat(filepath.Join(exeDir, ExeName)); err == nil && !info.IsDir() {
			return exeDir, true
		}
		// check parent directory too
		parentDir := filepath.Dir(exeDir)
		if info, err := os.Stat(filepath.Join(parentDir, ExeName)); err == nil && !info.IsDir() {
			return parentDir, true
		}
	}

	// check default install location
	defaultDir := GetDefaultInstallDir()
	if info, err := os.Stat(filepath.Join(defaultDir, ExeName)); err == nil && !info.IsDir() {
		return defaultDir, true
	}
	return defaultDir, false
}

func KillRunningInstances(installDir string) {
	targetPath := filepath.Join(installDir, ExeName)
	pid := fmt.Sprintf("%d", os.Getpid())

	out, err := exec.Command("pgrep", "-f", "^"+targetPath).Output()
	if err != nil {
		return
	}
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if line != "" && line != pid {
			exec.Command("kill", "-9", line).Run()
		}
	}
}

func CreateEntry(installDir, exePath string) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	appDir := filepath.Join(home, ".local", "share", "applications")
	if err := os.MkdirAll(appDir, 0755); err != nil {
		return err
	}

	iconPath := filepath.Join(installDir, "data", "flutter_assets", "assets", "images", "logo.png")

	entry := fmt.Sprintf(`[Desktop Entry]
Name=%s
Exec=%s
Icon=%s
Path=%s
Type=Application
Categories=Music;Player;
Comment=Cosmodrome desktop application
StartupNotify=true
`, appName, exePath, iconPath, installDir)

	if err := os.WriteFile(filepath.Join(appDir, "cosmodrome.desktop"), []byte(entry), 0644); err != nil {
		return err
	}


	return nil
}

// no need to register an install path on linux since we always install to the same location
func RegisterInstallPath(_ string) error {
	return nil
}

// ensure binary is executable and create desktop entry so app appears in launcher
func PostExtract(exePath string) error {
	return os.Chmod(exePath, 0755)
}

// linux we can always write here, so no need to ask for permission
func IsAdmin() bool {
	return true
}

// same here
func RunAsAdmin() {}

func BrowseForDirectory(window fyne.Window, callback func(string)) {
	fyneDialog.ShowFolderOpen(func(uri fyne.ListableURI, err error) {
		if err != nil || uri == nil {
			return
		}
		callback(uri.Path())
	}, window)
}
