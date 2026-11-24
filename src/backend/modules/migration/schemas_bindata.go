// Copyright 2022 The Gitea Authors. All rights reserved.
// SPDX-License-Identifier: MIT

//go:build bindata

// Pack all files in the directory `src/backend/modules/migration/schemas/` into a bindata file.
// We will use `assetfs.GenerateEmbedBindata` to embed the files, so the directory
// parameter must be relative to the `src/backend/modules/assetfs/embed.go` file.
// The generated bindata file `bindata.dat` will be placed in the current directory.

//go:generate go run ../../build/generate-bindata.go ../migration/schemas bindata.dat

package migration

import (
	"io/fs"
	"path"
	"sync"

	"gitea.dev/modules/assetfs"

	_ "embed"

	"github.com/santhosh-tekuri/jsonschema/v6"
)

//go:embed bindata.dat
var bindata []byte

var BuiltinAssets = sync.OnceValue(func() fs.FS {
	return assetfs.NewEmbeddedFS(bindata)
})

func openSchema(filename string) (any, error) {
	f, err := BuiltinAssets().Open(path.Base(filename))
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return jsonschema.UnmarshalJSON(f)
}
