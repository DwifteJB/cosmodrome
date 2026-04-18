package window

import (
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/widget"
)

func (i *Installer) showFinishedPage(success bool) {
	var titleText, subtitleText string

	if success {
		titleText = i.getActionWord() + " Complete!"
		subtitleText = "Cosmodrome was installed to: " + i.installDir
	} else {
		titleText = i.getActionWord() + " Failed"
		subtitleText = "An error occurred. See log below for details."
	}

	title := canvas.NewText(titleText, colForeground)
	title.TextSize = 22
	title.TextStyle = fyne.TextStyle{Bold: true}
	title.Alignment = fyne.TextAlignCenter

	subtitle := canvas.NewText(subtitleText, colMuted)
	subtitle.TextSize = 12
	subtitle.Alignment = fyne.TextAlignCenter

	closeBtn := widget.NewButton("Close Installer", func() { i.fyneWindow.Close() })
	closeBtn.Importance = widget.HighImportance

	var content fyne.CanvasObject
	if !success && i.logBox != nil {
		logLabel := canvas.NewText("LOG", colMuted)
		logLabel.TextSize = 11

		logCopy := widget.NewMultiLineEntry()
		logCopy.SetText(i.logBox.Text)
		logCopy.Disable()
		logCopy.Wrapping = fyne.TextWrapWord

		logScroll := container.NewScroll(logCopy)
		logScroll.SetMinSize(fyne.NewSize(0, 140))

		logSection := container.NewBorder(logLabel, nil, nil, nil, logScroll)

		content = container.NewPadded(
			container.NewBorder(
				container.NewVBox(container.NewCenter(title), container.NewCenter(subtitle)),
				container.NewCenter(closeBtn),
				nil, nil,
				logSection,
			),
		)
	} else {
		content = container.NewPadded(
			container.NewCenter(
				container.NewVBox(
					container.NewCenter(title),
					container.NewCenter(subtitle),
					container.NewCenter(closeBtn),
				),
			),
		)
	}


	i.setPage(3, content)

	go func () {
		// close after 10 seconds if it was successful, otherwise leave it open for user to read log
		if success {
			fyne.CurrentApp().SendNotification(&fyne.Notification{
				Title:   "Installation Complete",
				Content: "Cosmodrome was successfully installed!",
			})
			select {
	
			case <-time.After(10 * time.Second):
				i.fyneWindow.Close()
			}
		}
	}()
}
