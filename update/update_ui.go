package update

import (
	"io"
	"strings"

	"github.com/hashicorp/packer-plugin-sdk/packer"
)

type UpdateUi struct {
	ui       packer.Ui
	finished bool
}

func NewUpdateUi(ui packer.Ui) *UpdateUi {
	return &UpdateUi{
		ui:       ui,
		finished: false,
	}
}

func (u *UpdateUi) Askf(s string, args ...any) (string, error) {
	return u.ui.Askf(s, args...)
}

func (u *UpdateUi) Ask(s string) (string, error) {
	return u.ui.Ask(s)
}

func (u *UpdateUi) Sayf(s string, args ...any) {
	u.ui.Sayf(s, args...)
}

func (u *UpdateUi) Say(s string) {
	if strings.HasPrefix(s, "Exiting with code ") {
		u.finished = true
		return
	}
	u.ui.Say(s)
}

func (u *UpdateUi) Message(s string) {
	u.Say(s)
}

func (u *UpdateUi) Errorf(s string, args ...any) {
	u.ui.Errorf(s, args...)
}

func (u *UpdateUi) Error(s string) {
	u.ui.Error(s)
}

func (u *UpdateUi) Machine(t string, args ...string) {
	u.ui.Machine(t, args...)
}

func (u *UpdateUi) TrackProgress(src string, currentSize, totalSize int64, stream io.ReadCloser) (body io.ReadCloser) {
	return u.ui.TrackProgress(src, currentSize, totalSize, stream)
}
