# Embedded Greetd module

TODO: remove when dank-greeter is available in the Arch extra repos.

The greeter moved to [dank-greeter](https://github.com/AvengeMedia/dank-greeter). This embedded copy exists only for archinstall compatibility: the `niri - DankMaterialShell` archinstall profile writes an `/etc/greetd/config.toml` that launches `Modules/Greetd/assets/dms-greeter` from the packaged DMS tree, and dank-greeter is not installable from the official Arch repos yet.

Do not extend this module. New greeter work goes to dank-greeter. Installing greetd-dms-greeter-bin from the AUR and running `dms-greeter sync` migrates a system off this embedded copy.
