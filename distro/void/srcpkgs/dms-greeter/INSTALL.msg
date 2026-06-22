dms-greeter installed.

Configure and enable it with:

    dms greeter enable

This points greetd at the greeter and sets up everything Void needs that logind
would handle on systemd: enables seatd, adds the greeter user to the seat/video/
input groups, and adds pam_rundir to the greetd PAM stack. Optionally sync your
shell theme into the greeter with:

    dms greeter sync

Requirements not pulled in automatically: a Wayland compositor (niri, hyprland,
sway, …) and a working DRM device (/dev/dri/card*; in a VM, enable virtio-gpu).
