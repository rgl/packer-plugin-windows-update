// +build ignore

package main

import (
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/shurcooL/httpfs/filter"
	"github.com/shurcooL/vfsgen"
)

func main() {
	fs := filter.Keep(http.Dir(""), func(path string, fi os.FileInfo) bool {
		return fi.IsDir() || strings.HasSuffix(path, ".ps1")
	})
	err := vfsgen.Generate(fs, vfsgen.Options{
		PackageName:  "update",
		VariableName: "assets",
		BuildTags:    "!dev",
	})
	if err != nil {
		log.Fatalln(err)
	}
}
