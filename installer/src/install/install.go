package install

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"rmfosho/cosmodrome_installer/src/platform"
	"rmfosho/cosmodrome_installer/src/zip"
)

// interface for reporting progress to the UI
type Reporter interface {
	AppName() string
	InstallDir() string
	ActionWord() string
	SetStatus(string)
	SetProgress(float64)
	Log(string)
	FinishWithError()
	FinishSuccess()
}

func Run(r Reporter, zipData []byte) {
	installDir := r.InstallDir()
	exePath := filepath.Join(installDir, platform.ExeName)
	actionWord := r.ActionWord()
	actionLower := strings.ToLower(actionWord)

	r.SetStatus("Killing any instances found...")
	platform.KillRunningInstances(installDir)
	r.SetProgress(5)

	r.SetStatus("Creating directory...")
	r.SetProgress(10)
	r.Log(fmt.Sprintf("Directory: %s", installDir))

	if _, err := os.Stat(installDir); err == nil {
		r.Log("Removing existing files...")
		if err := os.RemoveAll(installDir); err != nil {
			r.Log(fmt.Sprintf("Could not remove existing: %v", err))
		}
	}

	if err := os.MkdirAll(installDir, 0755); err != nil {
		r.Log(fmt.Sprintf("ERROR: %v", err))
		r.SetStatus(actionWord + " failed")
		r.FinishWithError()
		return
	}
	r.Log("Directory ready")

	r.SetStatus("Extracting files...")
	r.SetProgress(30)

	if err := zip.Extract(zipData, installDir); err != nil {
		r.Log(fmt.Sprintf("ERROR: %v", err))
		r.SetStatus(actionWord + " failed")
		r.FinishWithError()
		return
	}
	r.Log("Files extracted")

	if _, err := os.Stat(exePath); os.IsNotExist(err) {
		r.Log(fmt.Sprintf("ERROR: %s not found", platform.ExeName))
		r.SetStatus(actionWord + " failed")
		r.FinishWithError()
		return
	}

	if err := platform.PostExtract(exePath); err != nil {
		r.Log(fmt.Sprintf("ERROR: Could not set permissions: %v", err))
	}

	r.SetStatus("Creating shortcuts...")
	r.SetProgress(70)

	if err := platform.CreateEntry(installDir, exePath); err != nil {
		r.Log(fmt.Sprintf("ERROR: Entry creation failed: %v", err))
	} else {
		r.Log("Shortcut/entry created")
	}

	if err := platform.RegisterInstallPath(installDir); err != nil {
		r.Log(fmt.Sprintf("ERROR: Could not register path: %v", err))
	} else {
		r.Log("Registered application path")
	}

	r.SetStatus("Launching...")
	r.SetProgress(95)

	cmd := exec.Command(exePath)
	cmd.Dir = installDir
	if err := cmd.Start(); err != nil {
		r.Log(fmt.Sprintf("ERROR: Could not launch: %v", err))
	} else {
		r.Log("Application launched")
	}

	r.SetProgress(100)
	r.SetStatus(fmt.Sprintf("%s completed!", actionWord))
	r.Log(fmt.Sprintf("\n%s %s complete!", r.AppName(), actionLower))

	r.FinishSuccess()
}
