//go:build windows

package platform

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"

	"fyne.io/fyne/v2"
	"github.com/go-ole/go-ole"
	"github.com/go-ole/go-ole/oleutil"
	"github.com/sqweek/dialog"
	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/registry"
)

const ExeName = "cosmodrome.exe"
const appName = "Cosmodrome"

func GetDefaultInstallDir() string {
	programFiles := os.Getenv("ProgramFiles")
	if programFiles == "" {
		programFiles = `C:\Program Files`
	}
	return filepath.Join(programFiles, appName)
}

func DetectExistingInstall() (string, bool) {
	// first check registry for install location
	if dir, found := readRegistryKeyToFindInstallDir(); found {
		return dir, true
	}

	// check if running from an existing installation directory
	exePath, err := os.Executable()
	if err == nil {
		exeDir := filepath.Dir(exePath)
		if _, err := os.Stat(filepath.Join(exeDir, ExeName)); err == nil {
			return exeDir, true
		}
		// check parent directory too
		parentDir := filepath.Dir(exeDir)
		if _, err := os.Stat(filepath.Join(parentDir, ExeName)); err == nil {
			return parentDir, true
		}
	}

	// check default install location
	defaultDir := GetDefaultInstallDir()
	if _, err := os.Stat(filepath.Join(defaultDir, ExeName)); err == nil {
		return defaultDir, true
	}
	return defaultDir, false
}

func KillRunningInstances(installDir string) {
	cmd := exec.Command("taskkill", "/F", "/IM", ExeName)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	cmd.Run()

	// also check for any processes running from the installDir and kill those too (in case the exe name was changed or something)
	cmd = exec.Command("powershell", "-Command", fmt.Sprintf(`Get-Process -FilePath "%s\%s" -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID } | ForEach-Object { $_.Kill() }`, installDir, ExeName))
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	cmd.Run()
}

func CreateEntry(installDir, exePath string) error {
	startMenuDir := filepath.Join(os.Getenv("ProgramData"), "Microsoft", "Windows", "Start Menu", "Programs")
	if err := createShortcut(filepath.Join(startMenuDir, appName+".lnk"), exePath, installDir); err != nil {
		return fmt.Errorf("start menu shortcut failed: %w", err)
	}
	desktopDir := filepath.Join(os.Getenv("PUBLIC"), "Desktop")
	if err := createShortcut(filepath.Join(desktopDir, appName+".lnk"), exePath, installDir); err != nil {
		return fmt.Errorf("desktop shortcut failed: %w", err)
	}
	return nil
}

func RegisterInstallPath(installDir string) error {
	path := installDir
	if strings.HasSuffix(path, ExeName) {
		path = path[:len(path)-len(ExeName)]
	}

	k, err := registry.OpenKey(registry.CURRENT_USER, `Software\Cosmodrome`, registry.SET_VALUE)
	if err == nil {
		defer k.Close()
		if err := k.SetStringValue("path", path); err != nil {
			return err
		}
	} else {
		k, _, err = registry.CreateKey(registry.CURRENT_USER, `Software\Cosmodrome`, registry.SET_VALUE)
		if err != nil {
			return err
		}
		defer k.Close()
		if err := k.SetStringValue("path", path); err != nil {
			return err
		}
	}

	return nil

}


func PostExtract(_ string) error {
	return nil
}

func IsAdmin() bool {
	_, err := os.Open("\\\\.\\PHYSICALDRIVE0")
	return err == nil
}

func RunAsAdmin() {
	exe, err := os.Executable()
	if err != nil {
		return
	}

	cwd, _ := os.Getwd()

	verb := "runas"
	verbPtr, _ := syscall.UTF16PtrFromString(verb)
	exePtr, _ := syscall.UTF16PtrFromString(exe)
	cwdPtr, _ := syscall.UTF16PtrFromString(cwd)

	windows.ShellExecute(0, verbPtr, exePtr, nil, cwdPtr, windows.SW_NORMAL)
}

func BrowseForDirectory(_ fyne.Window, callback func(string)) {
	go func() {
		selected, err := dialog.Directory().Title("Select Installation Directory").Browse()
		if err != nil || selected == "" {
			return
		}
		callback(selected)
	}()
}

func createShortcut(shortcutPath, targetPath, workingDir string) error {
	ole.CoInitializeEx(0, ole.COINIT_APARTMENTTHREADED|ole.COINIT_SPEED_OVER_MEMORY)
	defer ole.CoUninitialize()

	oleShellObject, err := oleutil.CreateObject("WScript.Shell")
	if err != nil {
		return err
	}
	defer oleShellObject.Release()

	wshell, err := oleShellObject.QueryInterface(ole.IID_IDispatch)
	if err != nil {
		return err
	}
	defer wshell.Release()

	shortcutVariant, err := oleutil.CallMethod(wshell, "CreateShortcut", shortcutPath)
	if err != nil {
		return err
	}

	shortcut := shortcutVariant.ToIDispatch()
	defer shortcut.Release()

	oleutil.PutProperty(shortcut, "TargetPath", targetPath)
	oleutil.PutProperty(shortcut, "WorkingDirectory", workingDir)
	oleutil.PutProperty(shortcut, "Description", appName)
	oleutil.PutProperty(shortcut, "IconLocation", targetPath+",0")

	_, err = oleutil.CallMethod(shortcut, "Save")
	return err
}

func readRegistryKeyToFindInstallDir() (string, bool) {
	k, err := registry.OpenKey(registry.CURRENT_USER, `Software\Cosmodrome`, registry.QUERY_VALUE)
	if err != nil {
		return "", false
	}
	defer k.Close()

	path, _, err := k.GetStringValue("path")
	if err != nil {
		return "", false
	}
	return path, true
}
