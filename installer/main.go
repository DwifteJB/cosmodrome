package main

import (
	_ "embed"

	"rmfosho/cosmodrome_installer/src/platform"
	"rmfosho/cosmodrome_installer/src/window"
)

//go:embed app.zip
var AppZipData []byte

//go:embed assets/logo.png
var logoPng []byte

const appName = "Cosmodrome"

func main() {
	if !platform.IsAdmin() {
		platform.RunAsAdmin()
		return
	}

	installDir, isUpdate := platform.DetectExistingInstall()

	window.New(window.Config{
		AppName:    appName,
		LogoPng:    logoPng,
		AppZipData: AppZipData,
		InstallDir: installDir,
		IsUpdate:   isUpdate,
	}).Run()
}
