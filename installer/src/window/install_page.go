package window

import (
	"fmt"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/widget"
)

func (i *Installer) showInstallPage() {
	i.isUpdate = i.checkIsUpdate()
	actionWord := i.getActionWord()

	title := canvas.NewText(fmt.Sprintf("%sing %s", actionWord, i.appName), colForeground)
	title.TextSize = 22
	title.TextStyle = fyne.TextStyle{Bold: true}

	i.status = widget.NewLabel(fmt.Sprintf("Preparing to %s...", strings.ToLower(actionWord)))
	i.status.TextStyle = fyne.TextStyle{Bold: true}

	i.progress = widget.NewProgressBar()
	i.progress.Min = 0
	i.progress.Max = 100
	i.progress.SetValue(0)

	logLabel := canvas.NewText("LOG", colMuted)
	logLabel.TextSize = 11

	i.logBox = widget.NewMultiLineEntry()
	i.logBox.Disable()
	i.logBox.SetMinRowsVisible(8)
	i.logBox.Wrapping = fyne.TextWrapWord

	logScroll := container.NewScroll(i.logBox)
	logScroll.SetMinSize(fyne.NewSize(0, 150))
	logSection := container.NewBorder(logLabel, nil, nil, nil, logScroll)

	inner := container.NewVBox(title, i.status, i.progress, logSection)
	content := container.NewPadded(inner)

	i.setPage(2, content)
	go i.runInstall()
}
