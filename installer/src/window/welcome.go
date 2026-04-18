package window

import (
	"image/color"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/widget"
)

var (
	colBackground = color.RGBA{R: 17, G: 17, B: 17, A: 255}
	colSidebar    = color.RGBA{R: 21, G: 21, B: 23, A: 255}
	colAura       = color.RGBA{R: 255, G: 133, B: 255, A: 255}
	colForeground = color.RGBA{R: 250, G: 250, B: 250, A: 255}
	colMuted      = color.RGBA{R: 161, G: 161, B: 161, A: 255}
	colSeparator  = color.RGBA{R: 42, G: 42, B: 42, A: 255}
)

func (i *Installer) showWelcomePage() {
	title := canvas.NewText("Welcome to Cosmodrome", colForeground)
	title.TextSize = 32
	title.TextStyle = fyne.TextStyle{Bold: true}

	desc := canvas.NewText("A Subsonic/navidrome music client :)", colMuted)
	desc.TextSize = 20

	cancelBtn := widget.NewButton("Cancel", func() { i.fyneWindow.Close() })
	nextBtn := widget.NewButton("Next", func() { i.showSetupPage(i.appZipData) })
	nextBtn.Importance = widget.HighImportance

	buttonRow := container.NewHBox(layout.NewSpacer(), cancelBtn, nextBtn)

	inner := container.NewVBox(title, desc, layout.NewSpacer())
	content := container.NewBorder(nil, container.NewPadded(buttonRow), nil, nil,
		container.NewPadded(inner))

	i.setPage(0, content)
}
