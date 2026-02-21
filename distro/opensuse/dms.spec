# Spec for DMS for OpenSUSE/OBS

%global debug_package %{nil}

Name:           dms
Version:        1.2.3
Release:        1%{?dist}
Summary:        DankMaterialShell - Material 3 inspired shell for Wayland compositors

License:        MIT
URL:            https://github.com/AvengeMedia/DankMaterialShell
Source0:        dms-source.tar.gz
Source1:        dms-distropkg-amd64.gz
Source2:        dms-distropkg-arm64.gz

BuildRequires:  gzip
BuildRequires:  systemd-rpm-macros

# Core requirements
Requires:       (quickshell or quickshell-git)
Requires:       accountsservice
Requires:       dgop

# Core utilities (Highly recommended for DMS functionality)
Recommends:     cava
Recommends:     danksearch
Recommends:     matugen
Recommends:     NetworkManager
Recommends:     qt6-qtmultimedia
Suggests:       cups-pk-helper
Suggests:       qt6ct

%description
DankMaterialShell (DMS) is a modern Wayland desktop shell built with Quickshell
and optimized for niri, Hyprland, Sway, and other wlroots compositors. Features
notifications, app launcher, wallpaper customization, and plugin system.

Includes auto-theming for GTK/Qt apps with matugen, 20+ customizable widgets,
process monitoring, notification center, clipboard history, dock, control center,
lock screen, and comprehensive plugin system.

%prep
%setup -q -n DankMaterialShell-%{version}

%ifarch x86_64
gunzip -c %{SOURCE1} > dms
%endif
%ifarch aarch64
gunzip -c %{SOURCE2} > dms
%endif
chmod +x dms

%build

%install
install -Dm755 dms %{buildroot}%{_bindir}/dms

install -d %{buildroot}%{_datadir}/bash-completion/completions
install -d %{buildroot}%{_datadir}/zsh/site-functions
install -d %{buildroot}%{_datadir}/fish/vendor_completions.d
./dms completion bash > %{buildroot}%{_datadir}/bash-completion/completions/dms || :
./dms completion zsh > %{buildroot}%{_datadir}/zsh/site-functions/_dms || :
./dms completion fish > %{buildroot}%{_datadir}/fish/vendor_completions.d/dms.fish || :

install -Dm644 assets/systemd/dms.service %{buildroot}%{_userunitdir}/dms.service

install -Dm644 assets/dms-open.desktop %{buildroot}%{_datadir}/applications/dms-open.desktop
install -Dm644 assets/danklogo.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/danklogo.svg

install -dm755 %{buildroot}%{_datadir}/quickshell/dms
cp -r quickshell/* %{buildroot}%{_datadir}/quickshell/dms/

rm -rf %{buildroot}%{_datadir}/quickshell/dms/.git*
rm -f %{buildroot}%{_datadir}/quickshell/dms/.gitignore
rm -rf %{buildroot}%{_datadir}/quickshell/dms/.github
rm -rf %{buildroot}%{_datadir}/quickshell/dms/distro
rm -rf %{buildroot}%{_datadir}/quickshell/dms/core

echo "%{version}" > %{buildroot}%{_datadir}/quickshell/dms/VERSION

%posttrans
# Signal running DMS instances to reload
pkill -USR1 -x dms >/dev/null 2>&1 || :

%files
%license LICENSE
%doc CONTRIBUTING.md
%doc quickshell/README.md
%{_bindir}/dms
%dir %{_datadir}/fish
%dir %{_datadir}/fish/vendor_completions.d
%{_datadir}/fish/vendor_completions.d/dms.fish
%dir %{_datadir}/zsh
%dir %{_datadir}/zsh/site-functions
%{_datadir}/zsh/site-functions/_dms
%{_datadir}/bash-completion/completions/dms
%dir %{_datadir}/quickshell
%{_datadir}/quickshell/dms/
%{_userunitdir}/dms.service
%{_datadir}/applications/dms-open.desktop
%dir %{_datadir}/icons/hicolor
%dir %{_datadir}/icons/hicolor/scalable
%dir %{_datadir}/icons/hicolor/scalable/apps
%{_datadir}/icons/hicolor/scalable/apps/danklogo.svg

%changelog
* Mon Dec 16 2025 AvengeMedia <maintainer@avengemedia.com> - 1.0.3-1
- Update to stable v1.0.3 release

* Fri Dec 12 2025 AvengeMedia <maintainer@avengemedia.com> - 1.0.2-1
- Update to stable v1.0.2 release
- Bug fixes and improvements

* Fri Nov 22 2025 AvengeMedia <maintainer@avengemedia.com> - 0.6.2-1
- Stable release build with pre-built binaries
- Multi-arch support (x86_64, aarch64)
