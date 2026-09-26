# FreeBSD support

DankMaterialShell contains native FreeBSD code paths and does not require
PulseAudio, PipeWire, systemd, NetworkManager, or Linux sysfs to provide its
core shell features.

## Native FreeBSD integrations

- **Audio:** `sound(4)` / `mixer(8)`. DMS enumerates all `pcmN` mixers, supports
  output/input volume and mute, and can change the default PCM device. PipeWire
  is dynamically loaded only on non-FreeBSD systems, so a FreeBSD session does
  not attempt to create a PipeWire context. Rapid volume changes are coalesced
  to keep the OSD responsive.
- **Wi-Fi:** the DMS daemon has a `wpa_supplicant` backend.
- **Brightness:** native FreeBSD backlight/devd support in the DMS daemon.
- **Battery:** UPower is used when useful; `acpiconf(8)` plus
  `hw.acpi.acline` is the native fallback.
- **Power:** `acpiconf(8)` for suspend and `shutdown(8)` for reboot/poweroff.
- **Users:** `pw(8)`.
- **Package updates:** `pkg(8)`.
- **Compositor/socket discovery:** `sockstat(1)` where Linux would use `/proc`.
- **Greeter state:** FreeBSD rc service detection for greetd.
- **Sessions:** elogind/loginctl is used when installed; otherwise DMS exposes
  the current session without repeatedly executing a missing Linux command.

## Recommended runtime tools

Install the Wayland/desktop tools used by the features you enable (for example
Quickshell, grim/slurp, wl-clipboard, and a notification/audio stack as desired)
from FreeBSD packages/ports. DMS's native audio path itself only needs the base
system `mixer` utility.

For session switching and login-manager integration, install/use elogind so
`loginctl` is available. Without elogind, locking and the current-session shell
remain usable, but switching between already-running graphical sessions is not
provided by the base system.

## FreeBSD limitations that DMS should not fake

- FreeBSD ACPI S4 hibernation is hardware/kernel dependent and is not presented
  as generally available by DMS.
- Charge thresholds are vendor-specific; the Linux `/sys/class/power_supply`
  controls are hidden on FreeBSD.
- Changing the default `pcmN` affects newly opened native audio streams. Moving
  an already-open stream between devices requires an audio routing layer such
  as `virtual_oss`.
- Power-profile-daemon and Linux rfkill semantics are not assumed. Features
  backed only by those Linux services are hidden/degraded rather than invoking
  Linux commands on FreeBSD.
