package window

import (
	"fmt"
	"image/color"
	"os"
	"path/filepath"
	"time"

	"rmfosho/cosmodrome_installer/src/install"
	"rmfosho/cosmodrome_installer/src/platform"
	"rmfosho/cosmodrome_installer/src/theme"

	"fyne.io/fyne/v2"
	fyneapp "fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/widget"
)

type Config struct {
	AppName    string
	LogoPng    []byte
	AppZipData []byte
	InstallDir string
	IsUpdate   bool
}

type Installer struct {
	fyneApp       fyne.App
	fyneWindow    fyne.Window
	logBox        *widget.Entry
	progress      *widget.ProgressBar
	status        *widget.Label
	contentHolder *fyne.Container
	pathEntry     *widget.Entry
	appName       string
	logoPng       []byte
	appZipData    []byte
	installDir    string
	isUpdate      bool
	currentStep   int
}

// fixedWidthLayout forces all children to an exact width regardless of container size.
type fixedWidthLayout struct{ width float32 }

func (f *fixedWidthLayout) MinSize(_ []fyne.CanvasObject) fyne.Size {
	return fyne.NewSize(f.width, 0)
}

func (f *fixedWidthLayout) Layout(objects []fyne.CanvasObject, size fyne.Size) {
	for _, o := range objects {
		o.Resize(fyne.NewSize(f.width, size.Height))
		o.Move(fyne.NewPos(0, 0))
	}
}

var stepNames = []string{"Welcome", "Installation", "Installing", "Finish"}

func (i *Installer) buildStepRow(name string, idx, current int) fyne.CanvasObject {
	isActive := idx == current
	isDone := idx < current

	var barColor color.Color = color.RGBA{0, 0, 0, 0}
	if isActive {
		barColor = colAura
	}
	bar := canvas.NewRectangle(barColor)
	bar.SetMinSize(fyne.NewSize(3, 36))

	label := fmt.Sprintf("%d. %s", idx+1, name)
	if isDone {
		// unicode check mark
		label = "✓ " + name
	}

	var textColor color.Color
	switch {
	case isActive:
		textColor = colForeground
	case isDone:
		textColor = colMuted
	default:
		textColor = color.RGBA{R: 70, G: 70, B: 70, A: 255}
	}

	text := canvas.NewText(label, textColor)
	text.TextSize = 13
	if isActive {
		text.TextStyle = fyne.TextStyle{Bold: true}
	}

	return container.NewBorder(nil, nil, bar, nil, container.NewPadded(text))
}

func (i *Installer) buildSidebar(current int) fyne.CanvasObject {
	dot := canvas.NewRectangle(colAura)
	dot.SetMinSize(fyne.NewSize(8, 8))
	dot.CornerRadius = 4

	brandName := canvas.NewText("COSMODROME", colForeground)
	brandName.TextSize = 13
	brandName.TextStyle = fyne.TextStyle{Bold: true}

	appIcon := canvas.NewImageFromResource(fyne.NewStaticResource("logo.png", i.logoPng))
	appIcon.SetMinSize(fyne.NewSize(32, 32))

	brandRow := container.NewPadded(container.NewBorder(nil, nil, appIcon, nil, brandName))

	gap := canvas.NewRectangle(color.RGBA{0, 0, 0, 0})
	gap.SetMinSize(fyne.NewSize(0, 16))

	stepsList := container.NewVBox()
	for idx, name := range stepNames {
		stepsList.Add(i.buildStepRow(name, idx, current))
	}

	top := container.NewVBox(brandRow, gap, stepsList)
	return container.NewBorder(top, nil, nil, layout.NewSpacer())
}

func (i *Installer) setPage(step int, content fyne.CanvasObject) {
	i.currentStep = step

	sidebarBg := canvas.NewRectangle(colSidebar)
	sidebarFixed := container.New(&fixedWidthLayout{220},
		container.NewStack(sidebarBg, i.buildSidebar(step)))

	sep := canvas.NewRectangle(colSeparator)
	sep.SetMinSize(fyne.NewSize(1, 0))
	leftPanel := container.NewBorder(nil, nil, nil, sep, sidebarFixed)

	contentBg := canvas.NewRectangle(colBackground)
	full := container.NewBorder(nil, nil, leftPanel, nil,
		container.NewStack(contentBg, content))

	i.contentHolder.Objects = []fyne.CanvasObject{full}
	i.contentHolder.Refresh()
}

func New(cfg Config) *Installer {
	return &Installer{
		appName:    cfg.AppName,
		logoPng:    cfg.LogoPng,
		appZipData: cfg.AppZipData,
		installDir: cfg.InstallDir,
		isUpdate:   cfg.IsUpdate,
	}
}

func (i *Installer) AppName() string         { return i.appName }
func (i *Installer) InstallDir() string      { return i.installDir }
func (i *Installer) ActionWord() string      { return i.getActionWord() }
func (i *Installer) SetStatus(msg string)    { i.status.SetText(msg) }
func (i *Installer) SetProgress(val float64) { i.progress.SetValue(val) }

func (i *Installer) Log(msg string) {
	timestamp := time.Now().Format("15:04:05")
	line := fmt.Sprintf("[%s] %s\n", timestamp, msg)
	i.logBox.SetText(i.logBox.Text + line)
	i.logBox.CursorRow = len(i.logBox.Text)
}

func (i *Installer) FinishWithError() {
	i.showFinishedPage(false)
}

func (i *Installer) FinishSuccess() {
	i.showFinishedPage(true)
}

func (i *Installer) Run() {
	i.fyneApp = fyneapp.New()
	i.fyneApp.Settings().SetTheme(theme.New())

	title := i.appName + " Installer"
	if i.isUpdate {
		title = i.appName + " Updater"
	}

	i.fyneWindow = i.fyneApp.NewWindow(title)
	i.fyneWindow.Resize(fyne.NewSize(760, 500))
	i.fyneWindow.SetFixedSize(true)
	i.fyneWindow.CenterOnScreen()

	i.contentHolder = container.NewStack()
	i.showWelcomePage()

	i.fyneWindow.SetContent(i.contentHolder)
	i.fyneWindow.ShowAndRun()
}

func (i *Installer) runInstall() {
	install.Run(i, i.appZipData)
}

func (i *Installer) checkIsUpdate() bool {
	_, err := os.Stat(filepath.Join(i.installDir, platform.ExeName))
	return err == nil
}

func (i *Installer) getActionWord() string {
	if i.isUpdate {
		return "Update"
	}
	return "Install"
}
