package theme

import (
	"image/color"

	"fyne.io/fyne/v2"
	fyneTheme "fyne.io/fyne/v2/theme"
)

type cosmodromeTheme struct{}

func (t *cosmodromeTheme) Color(name fyne.ThemeColorName, variant fyne.ThemeVariant) color.Color {
	switch name {
	case fyneTheme.ColorNameBackground:
		return color.RGBA{R: 17, G: 17, B: 17, A: 255}
	case fyneTheme.ColorNameButton:
		return color.RGBA{R: 255, G: 133, B: 255, A: 255}
	case fyneTheme.ColorNameDisabledButton:
		return color.RGBA{R: 38, G: 38, B: 38, A: 255}
	case fyneTheme.ColorNameDisabled:
		return color.RGBA{R: 102, G: 102, B: 102, A: 255}
	case fyneTheme.ColorNameForeground:
		return color.RGBA{R: 250, G: 250, B: 250, A: 255}
	case fyneTheme.ColorNamePrimary:
		return color.RGBA{R: 255, G: 133, B: 255, A: 255}
	case fyneTheme.ColorNameFocus:
		return color.RGBA{R: 255, G: 133, B: 255, A: 255}
	case fyneTheme.ColorNameHover:
		return color.RGBA{R: 255, G: 95, B: 255, A: 30}
	case fyneTheme.ColorNameInputBackground:
		return color.RGBA{R: 31, G: 31, B: 31, A: 255}
	case fyneTheme.ColorNameInputBorder:
		return color.RGBA{R: 42, G: 42, B: 42, A: 255}
	case fyneTheme.ColorNamePlaceHolder:
		return color.RGBA{R: 102, G: 102, B: 102, A: 255}
	case fyneTheme.ColorNameScrollBar:
		return color.RGBA{R: 51, G: 51, B: 51, A: 255}
	case fyneTheme.ColorNameShadow:
		return color.RGBA{R: 0, G: 0, B: 0, A: 80}
	case fyneTheme.ColorNameSuccess:
		return color.RGBA{R: 34, G: 197, B: 94, A: 255}
	case fyneTheme.ColorNameWarning:
		return color.RGBA{R: 255, G: 133, B: 255, A: 255}
	case fyneTheme.ColorNameError:
		return color.RGBA{R: 255, G: 100, B: 103, A: 255}
	case fyneTheme.ColorNameHeaderBackground:
		return color.RGBA{R: 21, G: 21, B: 23, A: 255}
	case fyneTheme.ColorNameSeparator:
		return color.RGBA{R: 42, G: 42, B: 42, A: 255}
	default:
		return fyneTheme.DarkTheme().Color(name, variant)
	}
}

func (t *cosmodromeTheme) Font(style fyne.TextStyle) fyne.Resource {
	return fyneTheme.DefaultTheme().Font(style)
}

func (t *cosmodromeTheme) Icon(name fyne.ThemeIconName) fyne.Resource {
	return fyneTheme.DefaultTheme().Icon(name)
}

func (t *cosmodromeTheme) Size(name fyne.ThemeSizeName) float32 {
	switch name {
	case fyneTheme.SizeNamePadding:
		return 6
	case fyneTheme.SizeNameInnerPadding:
		return 8
	case fyneTheme.SizeNameText:
		return 13
	case fyneTheme.SizeNameHeadingText:
		return 20
	case fyneTheme.SizeNameSubHeadingText:
		return 14
	case fyneTheme.SizeNameScrollBar:
		return 8
	case fyneTheme.SizeNameScrollBarSmall:
		return 3
	default:
		return fyneTheme.DefaultTheme().Size(name)
	}
}

func New() fyne.Theme {
	return &cosmodromeTheme{}
}
