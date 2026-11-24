// Copyright 2020 The Gitea Authors. All rights reserved.
// SPDX-License-Identifier: MIT

//go:build bindata

// Pack all files in the directory `src/static/options/` into a bindata file.
// We will use `assetfs.GenerateEmbedBindata` to embed the files, so the directory
// parameter must be relative to the `src/backend/modules/assetfs/embed.go` file.
// The generated bindata file `bindata.dat` will be placed in the current directory.

//go:generate go run ../../build/generate-bindata.go ../../../static/options bindata.dat

package options

import (
	"sync"

	"gitea.dev/modules/assetfs"

	_ "embed"
)

//go:embed bindata.dat
var bindata []byte

var BuiltinAssets = sync.OnceValue(func() *assetfs.Layer {
	return assetfs.Bindata("builtin(bindata)", assetfs.NewEmbeddedFS(bindata))
})
