package matugen

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestBuildImportDataInjections(t *testing.T) {
	const dank16 = `{"color0":"#000000"}`
	const pal = `{"color0":"#111111"}`
	const pal2 = `{"color0":"#222222"}`

	assert.Equal(t,
		`{"dank16": {"color0":"#000000"}, "wallust": {"color0":"#111111"}}`,
		buildImportData(dank16, "", "", []paletteInjection{{Namespace: "wallust", JSON: pal}}),
		"palette lands under its namespace")

	assert.Equal(t,
		`{"dank16": {"color0":"#000000"}, "image": "/w.png", "mypalette": {"color0":"#111111"}}`,
		buildImportData(dank16, "/w.png", "", []paletteInjection{{Namespace: "mypalette", JSON: pal}}),
		"custom namespace coexists with image")

	assert.Equal(t,
		`{"dank16": {"color0":"#000000"}, "wallust": {"color0":"#111111"}, "mytool": {"color0":"#222222"}}`,
		buildImportData(dank16, "", "", []paletteInjection{{Namespace: "wallust", JSON: pal}, {Namespace: "mytool", JSON: pal2}}),
		"each palette lands under its own namespace, in order")

	dup := []paletteInjection{{Namespace: "wallust", JSON: pal}, {Namespace: "wallust", JSON: pal2}, {Namespace: "dank16", JSON: pal2}}
	assert.Equal(t,
		`{"dank16": {"color0":"#000000"}, "wallust": {"color0":"#111111"}}`,
		buildImportData(dank16, "", "", dup),
		"duplicate and reserved namespaces are dropped")

	empty := []paletteInjection{{Namespace: "wallust", JSON: ""}, {Namespace: "", JSON: pal}}
	assert.Equal(t,
		`{"dank16": {"color0":"#000000"}}`,
		buildImportData(dank16, "", "", empty),
		"injections missing a namespace or JSON are skipped")
}

func TestLoadPaletteInjectConfig(t *testing.T) {
	write := func(t *testing.T, body string) string {
		t.Helper()
		dir := t.TempDir()
		mdir := filepath.Join(dir, "matugen")
		require.NoError(t, os.MkdirAll(mdir, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(mdir, "palette-inject.json"), []byte(body), 0o644))
		return dir
	}

	got, err := loadPaletteInjectConfig(t.TempDir())
	require.NoError(t, err)
	assert.Nil(t, got, "absent config yields no entries")

	got, err = loadPaletteInjectConfig(write(t, `{"enabled":true,"command":"mytool","args":["{image}"]}`))
	require.NoError(t, err)
	require.Len(t, got, 1, "bare single-object config is normalized to one entry")
	assert.Equal(t, "mytool", got[0].Command)
	assert.Equal(t, "palette1", got[0].Namespace, "missing namespace defaults to a positional name")

	got, err = loadPaletteInjectConfig(write(t, `{"palettes":[
		{"enabled":true,"command":"a","namespace":"one"},
		{"enabled":false,"command":"b","namespace":"two"},
		{"enabled":true,"command":"","namespace":"three"},
		{"enabled":true,"command":"c"}
	]}`))
	require.NoError(t, err)
	require.Len(t, got, 2, "disabled entries and empty commands are filtered out")
	assert.Equal(t, "one", got[0].Namespace)
	assert.Equal(t, "c", got[1].Command)
	assert.Equal(t, "palette4", got[1].Namespace, "positional default uses the original config index")
}

func TestRunPaletteEntry(t *testing.T) {
	sh := func(script string) paletteEntry {
		return paletteEntry{Enabled: true, Command: "sh", Args: []string{"-c", script}, Namespace: "p"}
	}

	// Nested JSON (pywal/wallust shape) is accepted and forwarded verbatim.
	nested := `{"colors":{"color0":"#111111"},"special":{"background":"#000000"}}`
	got := runPaletteEntry(sh("printf '%s' '"+nested+"'"), "/img.png", ColorModeDark)
	assert.JSONEq(t, nested, got, "nested palette objects are accepted")

	// A JSON array or scalar is not an object and is rejected.
	assert.Empty(t, runPaletteEntry(sh(`printf '%s' '["#111"]'`), "/img.png", ColorModeDark),
		"a non-object payload is rejected")
	assert.Empty(t, runPaletteEntry(sh(`printf '%s' '{}'`), "/img.png", ColorModeDark),
		"an empty object is rejected")

	// A failing command yields no palette rather than breaking the build.
	assert.Empty(t, runPaletteEntry(sh("exit 1"), "/img.png", ColorModeDark),
		"a failing command is skipped")

	// {image}/{mode} tokens reach the command.
	echoed := runPaletteEntry(
		paletteEntry{Enabled: true, Command: "sh", Args: []string{"-c", `printf '{"m":"%s","i":"%s"}' "$1" "$2"`, "sh", "{mode}", "{image}"}, Namespace: "p"},
		"/wall.png", ColorModeLight)
	assert.JSONEq(t, `{"m":"light","i":"/wall.png"}`, echoed, "tokens are substituted in args")

	// output_file is read back instead of stdout when set.
	out := filepath.Join(t.TempDir(), "pal.json")
	fileEntry := paletteEntry{Enabled: true, Command: "sh", Args: []string{"-c", `printf '%s' '{"color0":"#abcabc"}' > "$DMS_PALETTE_OUT"`}, OutputFile: out, Namespace: "p"}
	assert.JSONEq(t, `{"color0":"#abcabc"}`, runPaletteEntry(fileEntry, "/img.png", ColorModeDark),
		"palette is read from output_file")
}
