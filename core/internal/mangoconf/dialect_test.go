package mangoconf

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestTranslateRespellsKeysBothWays(t *testing.T) {
	legacy := "exec-once=dms run\nsource=./dms/colors.conf\ngappih = 5\nbordercolor = 0x595959ff\nwindowrule=appid:foo,isfloating:1,isnoanimation:1\nlayerrule=noanim:1,noshadow:1,layer_name:rofi\n# exec-once=kept\n"
	snake := "exec_once=dms run\nsource=./dms/colors.conf\ngap_inner_horizontal = 5\nborder_color = 0x595959ff\nwindow_rule=app_id:foo,is_floating:1,no_animation:1\nlayer_rule=no_animation:1,no_shadow:1,layer_name:rofi\n# exec-once=kept\n"
	assert.Equal(t, snake, Snake.Translate(legacy))
	assert.Equal(t, legacy, Legacy.Translate(snake))
	assert.Equal(t, legacy, Legacy.Translate(legacy))
	assert.Equal(t, "tag_rule=id:1,master_factor:0.6,master_count:2\n", Snake.Translate("tagrule=id:1,mfact:0.6,nmaster:2\n"))
}

func TestDetectBinary(t *testing.T) {
	dir := t.TempDir()
	old := filepath.Join(dir, "old")
	cur := filepath.Join(dir, "new")
	require.NoError(t, os.WriteFile(old, []byte("\x00run_exec_once\x00gappih\x00"), 0o755))
	require.NoError(t, os.WriteFile(cur, []byte("\x00exec_once\x00gap_inner_horizontal\x00"), 0o755))
	assert.Equal(t, Legacy, DetectBinary(old))
	assert.Equal(t, Snake, DetectBinary(cur))
	assert.Equal(t, Legacy, DetectBinary(filepath.Join(dir, "missing")))
}

func TestMigrateLeavesUserConfigUnlessAsked(t *testing.T) {
	dir := t.TempDir()
	require.NoError(t, os.MkdirAll(filepath.Join(dir, "dms"), 0o755))
	main := filepath.Join(dir, "config.conf")
	layout := filepath.Join(dir, "dms", "layout.conf")
	input := filepath.Join(dir, "dms", "input.conf")
	require.NoError(t, os.WriteFile(main, []byte("exec-once=dms run\n"), 0o644))
	require.NoError(t, os.WriteFile(layout, []byte("borderpx=2\n"), 0o644))
	require.NoError(t, os.WriteFile(input, []byte("numlockon=1\n"), 0o644))

	changed, err := Snake.Migrate(dir, false)
	require.NoError(t, err)
	assert.Equal(t, []string{layout, input}, changed)
	data, _ := os.ReadFile(main)
	assert.Equal(t, "exec-once=dms run\n", string(data))
	data, _ = os.ReadFile(input)
	assert.Equal(t, "numlock_on=1\n", string(data))

	changed, err = Snake.Migrate(dir, true)
	require.NoError(t, err)
	assert.Equal(t, []string{main}, changed)
	backups, _ := filepath.Glob(main + ".backup.*")
	assert.Len(t, backups, 1)
}

func TestMigrateReportsUnwritableFragmentAndContinues(t *testing.T) {
	dir := t.TempDir()
	require.NoError(t, os.MkdirAll(filepath.Join(dir, "dms"), 0o755))
	binds := filepath.Join(dir, "dms", "binds.conf")
	layout := filepath.Join(dir, "dms", "layout.conf")
	require.NoError(t, os.WriteFile(binds, []byte("exec-once=foo\n"), 0o444))
	require.NoError(t, os.WriteFile(layout, []byte("borderpx=2\n"), 0o644))

	changed, err := Snake.Migrate(dir, false)
	assert.ErrorContains(t, err, "binds.conf")
	assert.Equal(t, []string{layout}, changed)
}
