package update

import (
	"io/ioutil"
)

func MustAsset(name string) []byte {
	f, err := assets.Open(name)
	if err != nil {
		panic("asset: Asset(" + name + "): " + err.Error())
	}
	defer func() {
		err := f.Close()
		if err != nil {
			panic("asset: Asset(" + name + "): " + err.Error())
		}
	}()
	b, err := ioutil.ReadAll(f)
	if err != nil {
		panic("asset: Asset(" + name + "): " + err.Error())
	}
	return b
}
