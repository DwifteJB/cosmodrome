package window

import (
	"fmt"
	"path/filepath"

	"rmfosho/cosmodrome_installer/src/platform"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/widget"
)

func (i *Installer) showSetupPage([]byte) {
	title := canvas.NewText("Installation Path", colForeground)
	title.TextSize = 22
	title.TextStyle = fyne.TextStyle{Bold: true}

	desc := canvas.NewText("Choose where Cosmodrome will be installed.", colMuted)
	desc.TextSize = 13

	dirLabel := canvas.NewText("INSTALL DIRECTORY", colMuted)
	dirLabel.TextSize = 11

	i.pathEntry = widget.NewEntry()
	i.pathEntry.SetText(i.installDir)
	i.pathEntry.OnChanged = func(s string) {
		i.installDir = s
		i.isUpdate = i.checkIsUpdate()
	}

	browseBtn := widget.NewButton("Browse", func() {
		platform.BrowseForDirectory(i.fyneWindow, func(selected string) {
			if selected == "" {
				return
			}
			i.installDir = filepath.Join(selected, i.appName)
			i.pathEntry.SetText(i.installDir)
			i.isUpdate = i.checkIsUpdate()
		})
	})

	pathRow := container.NewBorder(nil, nil, nil, browseBtn, i.pathEntry)

	appByteLen := len(i.appZipData)
	// convert to MB from bytes, round up
	appSizeMB := (appByteLen + 1024*1024 - 1) / (1024 * 1024)

	note := canvas.NewText(fmt.Sprintf("Approximately %d MB of disk space required.", appSizeMB), colMuted)
	note.TextSize = 11

	backBtn := widget.NewButton("Back", func() { i.showWelcomePage() })
	installBtn := widget.NewButton(i.getActionWord(), func() { i.showInstallPage() })
	installBtn.Importance = widget.HighImportance

	buttonRow := container.NewHBox(backBtn, layout.NewSpacer(), installBtn)

	inner := container.NewVBox(title, desc, dirLabel, pathRow, note, layout.NewSpacer())
	content := container.NewBorder(nil, container.NewPadded(buttonRow), nil, nil,
		container.NewPadded(inner))

	i.setPage(1, content)
}
