# Performance Optimization for Low-Resource Environments

Analysis of DankMaterialShell performance characteristics and optimization opportunities for systems with limited RAM and weak CPU.

## Executive Summary

DankMaterialShell is a feature-rich Wayland desktop shell with significant GPU and CPU overhead from shader effects, high-frequency timers, and continuous background monitoring. This document identifies optimization opportunities to make the shell viable on low-resource hardware (2GB RAM, weak CPU).

## Current Performance Profile

### Resource Usage Categories

| Category | Impact | Primary Consumers |
|---|---|---|
| Shader/Blur Pipeline | GPU + VRAM | WallpaperBackground, BlurredWallpaperLive, BackdropBlur, DankAlbumArt |
| M3 Elevation Blur | GPU | All elevated surfaces via Theme.qml |
| High-Frequency Timers | CPU wake-ups | 10+ services with 16-100ms intervals |
| Shell Process Spawning | CPU + RAM | Weather, Dgop, compositor polling |
| Expressive Animations | CPU + GPU | Bezier curves, transition shaders |

---

## Detailed Findings

### 1. Shader Effects Pipeline

**Files:**
- `quickshell/Modules/WallpaperBackground.qml:794-853`
- `quickshell/Modules/BlurredWallpaperLive.qml:184-226`
- `quickshell/Widgets/BackdropBlur.qml:13-41`
- `quickshell/Widgets/DankAlbumArt.qml:185-224`

**Issues:**
- Multiple `ShaderEffectSource` instances with `live: true` continuously render even when source content hasn't changed
- `WallpaperBackground` uses 3+ ShaderEffectSource instances per monitor (srcCurrent, srcNext, srcParallax)
- `BackdropBlur` creates a live snapshot + MultiEffect blur for every blurred surface
- `DankAlbumArt` runs a 33ms timer driving a ShaderEffect for audio-reactive blob animation

**Current mitigations:**
- `ShaderEffectSource.live` is gated on `root.effectActive` (good)
- `DankAlbumArt` timer checks `blobEffect.visible && root.onScreen` (good)
- `BlurService.enabled` gates blur availability (good)

**Remaining opportunities:**
- `srcParallax` in WallpaperBackground has `live: true` unconditionally — should be gated on scroll activity
- `textureSize` for shader sources should be reduced in low-power mode
- `blurMax` (default 96) can be reduced in power-saving mode

### 2. M3 Elevation System

**Files:**
- `quickshell/Common/Theme.qml:761-792`
- `quickshell/Common/SettingsData.qml:234-245`

**Issues:**
- Every elevated surface generates a blur-based shadow
- `elevationBlurMax` ranges from 32-128 depending on intensity setting
- `m3ElevationEnabled` defaults to `true` — all surfaces get blur shadows

**Impact:** On weak GPUs, per-frame blur compositing for multiple surfaces is the single largest GPU cost.

### 3. Timer Overhead

Identified high-frequency timers across the codebase:

| Timer | Location | Interval | Purpose |
|---|---|---|---|
| `holdTimer` | PowerMenuModal.qml:136 | 16ms | Hold-to-confirm progress |
| `groupsDebounce` | NotificationService.qml:638 | 16ms | Notification grouping |
| `addGate` | NotificationService.qml:591 | 80ms | Notification queue gate |
| `dismissPump` | NotificationService.qml:613 | configurable | Batch dismiss |
| `timeUpdateTimer` | NotificationService.qml:602 | 30s | Time display update |
| `rebuildDebounce` | DesktopWidgetLayer.qml:92 | 150ms | Widget rebuild |
| `rebuildApply` | DesktopWidgetLayer.qml:101 | 32ms | Rebuild apply |
| `updateTimer` | DgopService.qml:632 | 3s/30s | Process monitoring |
| compositor timers | CompositorService.qml | 100ms | Compositor polling |
| search debounce | SettingsSearchService.qml:125 | 50ms | Search scheduling |
| gpu polling | GpuTemperature.qml:212 | 100ms | Hardware monitoring |
| media timer | Media.qml:380 | 150ms | Media state update |
| seekbar | DankSeekbar.qml:110 | 80ms | Playback position |
| blob animation | DankAlbumArt.qml:186 | 33ms | Audio visualization |
| audio viz | AudioVisualization.qml:37 | 500ms | Audio spectrum |

**Analysis:** The 16ms timers (PowerMenuModal, NotificationService) are effectively running at vsync rate and contribute to continuous CPU wake-ups. The 100ms timers for hardware polling are reasonable but could be relaxed.

### 4. Shell Process Spawning

**Files:**
- `quickshell/Services/WeatherService.qml:697-897` — multiple Process components for weather/network queries
- `quickshell/Common/settings/Processes.qml:28` — multiple system Process components
- `quickshell/Services/SessionService.qml:76-176` — shell/system checks
- `quickshell/Services/ShellVersionService.qml:19-42` — git/filesystem checks at startup
- `quickshell/Services/NotificationService.qml:53-54` — detached mkdir/rm commands

**Issues:** Each `Process` component spawns a new shell process. Frequent process creation/destruction is expensive on weak CPUs.

### 5. Animation System

**Files:**
- `quickshell/Common/Theme.qml:997-1057`
- `quickshell/Common/SettingsData.qml:31-47`

**Current state:** Already supports `AnimationSpeed.None`, `AnimationSpeed.Short`, `AnimationSpeed.Medium`, `AnimationSpeed.Long`, and `AnimationSpeed.Custom`. This is well-designed but there's no automatic "power saving" mode that forces minimal animations.

---

## Proposed Optimization Plan

### Phase 1: PowerMode Infrastructure (Prerequisite) ✅ DONE

Add a centralized power mode setting that controls all downstream optimizations.

**SettingsData.qml changes:**
```qml
enum PowerMode { Normal, Balanced, PowerSaving }
property int powerMode: PowerMode.Normal
```

**SettingsSpec.js defaults:**
- `powerMode: { def: 0 }` (Normal)
- `syncPowerModeWithSystem: { def: false }` (opt-in auto-switch from system power profile)

**Files modified:**
- `quickshell/Common/SettingsData.qml` — enum + property + syncPowerModeWithSystem + PowerProfileWatcher Connections
- `quickshell/Common/settings/SettingsSpec.js` — defaults
- `quickshell/Modules/Settings/TypographyMotionTab.qml` — Settings UI selector (Normal/Balanced/PowerSaving)

### Phase 2: Shader/Blur Optimizations ✅ DONE

| Change | File | Status |
|---|---|---|
| Gate `srcParallax.live` on PowerSaving | WallpaperBackground.qml | ✅ Done |
| Reduce `textureSize` in power saving | WallpaperBackground.qml:801,811,852 | ✅ Done (halved) |
| Reduce `blurMax` in power saving | BackdropBlur.qml:13 | ✅ Done (96→48) |
| Disable blob animation in power saving | DankAlbumArt.qml:187 | ✅ Done (running gated) |

### Phase 3: Timer Optimizations ✅ DONE

For each timer, add `PowerMode` awareness:

```qml
Timer {
    interval: SettingsData.powerMode === SettingsData.PowerMode.PowerSaving
              ? 200 : 100
    // ...
}
```

**Timers adjusted:**

| Timer | Current | PowerSaving | Status |
|---|---|---|---|
| `groupsDebounce` (NotificationService) | 16ms | 50ms | ✅ Done |
| `holdTimer` (PowerMenuModal) | 16ms | 32ms | ✅ Done |
| `scrollTimer` (SettingsSearchService) | 50ms | 150ms | ✅ Done |
| `previewSettleTimer` (DankSeekbar) | 80ms | 200ms | ✅ Done |
| `blobTimer` (DankAlbumArt) | 33ms | disabled | ✅ Done |
| `updateTimer` (DgopService) | 3000ms | 5000ms | ✅ Done |

**Not adjusted (intentionally):**

| Timer | Reason |
|---|---|
| CompositorService polling | Actually a debounce timer, not polling — no meaningful interval to relax |
| GpuTemperature autoSaveTimer | One-shot initialization timer (`running: false`), not continuous polling — interval irrelevant for performance |

### Phase 4: M3 Elevation in Power Saving ✅ DONE

```qml
// Theme.qml:761
readonly property bool elevationEnabled:
    typeof SettingsData !== "undefined"
    && SettingsData.powerMode !== SettingsData.PowerMode.PowerSaving
    && (SettingsData.m3ElevationEnabled ?? true)
```

### Phase 5: Animation Overrides ✅ DONE

In power saving mode:
- Force `AnimationSpeed.None` for all animation categories ✅
- Disable `enableRippleEffects` ✅
- ~~Use linear easing curves instead of expressive Bezier curves~~ — Not needed: AnimationSpeed.None sets all durations to 0, making easing curves irrelevant

```qml
// Theme.qml:1035
readonly property int currentAnimationSpeed:
    typeof SettingsData !== "undefined" && SettingsData.powerMode === SettingsData.PowerMode.PowerSaving
    ? SettingsData.AnimationSpeed.None
    : (typeof SettingsData !== "undefined" ? SettingsData.animationSpeed : SettingsData.AnimationSpeed.Short)

// Theme.qml:1036
readonly property bool rippleEffectsEnabled:
    typeof SettingsData !== "undefined" && SettingsData.powerMode === SettingsData.PowerMode.PowerSaving
    ? false
    : (typeof SettingsData !== "undefined" ? (SettingsData.enableRippleEffects ?? true) : true)
```

### Phase 6: Lazy Loading Verification ✅ DONE (audit + bonus fix)

Audit results — all non-essential modules already lazy:
- ProcessList modules — only when process viewer is open ✅
- Plugin components — only when plugins enabled ✅
- FileBrowser — on demand only ✅
- Fade-to-lock / fade-to-DPMS — per-screen Loader with active gate ✅
- All popouts/modals — LazyLoader active: false ✅

**Bonus fix:** DesktopWidgetLayer now filters disabled instances from Instantiator model instead of creating all and hiding disabled ones.

### Phase 7: Go Backend (Lower Priority) — NOT DONE

Lower priority per original assessment. Items remain as future work:
- Verify BoltDB compaction isn't running unnecessarily
- Check if shell process spawning can be batched or cached

---

## Implementation Order

1. **Phase 1** — PowerMode infrastructure (prerequisite for all others)
2. **Phase 2** — Shader/blur optimizations (highest GPU impact)
3. **Phase 3** — Timer optimizations (highest CPU impact)
4. **Phase 4** — Elevation toggle (low effort, good gain)
5. **Phase 5** — Animation overrides (already partially supported)
6. **Phase 6-7** — Lazy loading, Go backend (lower immediate impact)

---

## Testing Strategy

- Test on hardware with 2GB RAM + weak CPU (e.g., older ThinkPad, PineBook)
- Monitor CPU usage with `htop` during idle and active use
- Monitor GPU usage with `radeontop` or equivalent
- Measure RAM footprint at startup and after 30 minutes of use
- Verify all modes (Normal, Balanced, PowerSaving) render correctly
- Ensure no visual regressions in Normal mode

---

## Risk Assessment

| Change | Risk | Mitigation |
|---|---|---|
| PowerMode enum addition | Low | Additive, no existing behavior changes |
| Timer interval changes | Medium | May affect UX responsiveness — test each |
| Shader source gating | Medium | Could cause visual artifacts if gated incorrectly |
| Elevation disable | Low | Pure visual simplification |
| Animation speed override | Low | User can override per-category |

---

## Pull Request Best Practices

### PR Title and Description

**Title format:**
```
feat: add PowerMode for low-resource environments
perf: optimize shader/timer overhead for weak hardware
```

**Description must include:**
- Motivation (limited hardware, 2GB RAM, weak CPU)
- What changes (PowerMode enum, timer intervals, shader gating)
- Screenshots/video if visual changes (required by CONTRIBUTING.md)

### Commit Organization

One logical change per commit. Do not mix unrelated changes.

```
feat: add PowerMode enum to SettingsData
perf: gate shader live sources on activity
perf: increase timer intervals in PowerSaving mode
perf: disable M3 elevation in PowerSaving mode
perf: force AnimationSpeed.None in PowerSaving mode
```

### Pre-PR Checklist

```bash
# Format QML
cd quickshell && ./qmlformat-all.sh

# Lint QML (requires .qmlls.ini generated by qs -p .)
make lint-qml

# Go (only if core/ was changed)
cd core && make fmt && make test && go mod tidy

# Pre-commit hooks
prek install  # if not already installed
```

### PR Checklist

- [ ] Tested on at least one compositor (Niri, Hyprland, etc.)
- [ ] `AnimationSpeed.None` does not break existing animations
- [ ] Timers in PowerSaving mode do not cause perceptible UX delay
- [ ] Disabled shaders do not leave visual artifacts
- [ ] Settings UI allows switching between modes
- [ ] Default values preserve current behavior (`PowerMode.Normal`)
- [ ] Screenshots/video included if visual changes are present

### Documentation Requirements

Per CONTRIBUTING.md:172-174:

> Include screenshots/video if applicable in your pull request, to visualize what your change is affecting.

Include before/after screenshots of the shell running in each mode (Normal, Balanced, PowerSaving).

### Code Style

- 4-space indentation in QML
- No comments unless essential for complex logic (project convention)
- Use `DankIcon` for all icons, not manual Text components
- Bind directly to service properties, avoid wrapper functions
- Use `Theme.propertyName` for all styling values
- Wrap user-facing strings in `I18n.tr()` with context

---

## mise (Dev Tool Manager)

[mise](https://mise.jdx.dev/) manages language runtimes and dev tools per-project via `mise.toml`.

### Install mise

```bash
curl https://mise.run | sh

# Activate in shell (pick your shell)
echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc
# or
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
```

### Project Tool Versions

Defined in `mise.toml` at repo root:

| Tool | Version | Source | Notes |
|---|---|---|---|
| `go` | `1.26` | core | Matches `go.mod` (1.26.4) |
| `shellcheck` | `0.10` | pre-commit | Lints shell scripts |
| `golangci-lint` | `2.12` | Go linting | AGENTS.md |
| `uv` | `0.11` | Python pkg mgr | Used by prek, manages Python versions automatically |
| `prek` | `0.4` | pre-commit | Hook manager |

### Tools NOT in mise (require system/nix)

| Tool | Why | Alternative |
|---|---|---|
| `quickshell` | Wayland shell framework, not a mise backend | `nix develop` or system package |
| `qmllint` / `qmlfmt` | Qt6 QML tools | `nix develop` or system Qt6 |
| Qt6 libraries | System/display server dependent | `nix develop` or distro packages |
| `gopls`, `delve`, `go-tools` | Go dev tools | `go install` or nix |
| `go-mockery` | Mock generation | `go install` |
| `nixd`, `nil` | Nix LSPs | `nix develop` or system |

### Usage

```bash
# First time: install all tools from mise.toml
mise install

# Trust the config
mise trust

# Use tools directly
mise exec go -- go version
mise exec python -- python3 scripts/extract_translations.py

# Or with activate in shell, tools are on PATH automatically
```

### Recommended Workflow

For full development environment (including QML/Qt6 tools):

```bash
# Option A: nix develop (recommended — gets everything)
nix develop

# Option B: mise + system packages
mise install
# Install quickshell, Qt6, etc. from distro packages
```

For Go-only work (backend changes):

```bash
mise install
cd core && make test
```

### Adding New Tools

```bash
# Check if tool exists in mise registry
mise ls-remote <tool-name>

# Add to project
mise use <tool>@<version>

# Or edit mise.toml directly, then:
mise install
```

---

## Future Work

### PR Template ✅ DONE

Created `.github/PULL_REQUEST_TEMPLATE.md` with checklist, commit conventions, and code style reminders.

### Low-Power Mode UI ✅ DONE

PowerMode selector added to Settings → Typography & Motion → Performance Mode.

### CI Integration

Add a performance regression check to CI:
- Baseline memory footprint measurement
- Timer frequency audit (flag new timers under 50ms)
- Shader source count per surface
