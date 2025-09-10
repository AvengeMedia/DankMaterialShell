{
    lib,
    config,
    pkgs,
}:
with lib.types; let
    inherit
        (lib.types)
        nullOr
        oneOf
        either
        submodule
        listOf
        ;

    noDefault = option: builtins.removeAttrs option ["default"];
    allowNull = option: option // {type = nullOr option.type;};
    mkOption = default: types:
        lib.mkOption {
            type = oneOf (lib.toList types);
            inherit default;
        };

    simpleOption = type: default: mkOption default type;
    simpleOptionWithParameter = type: elemType: default:
        simpleOption (type elemType) default;

    listOfOption = simpleOptionWithParameter listOf;
    strOption = simpleOption str;
    boolOption = simpleOption bool;
    floatOption = simpleOption float;
    intOption = simpleOption int;
    enumOption = simpleOptionWithParameter enum;

    theme = lib.mkOption {
        default = null;
        type = nullOr (
            either
            (enum [
                "blue"
                "deepBlue"
                "purple"
                "green"
                "orange"
                "red"
                "cyan"
                "pink"
                "amber"
                "coral"
                "dynamic"
            ])
            (submodule {
                # TODO: support dark and light variants
                options = {
                    primary = noDefault (strOption null);
                    primaryText = noDefault (strOption null);
                    primaryContainer = noDefault (strOption null);
                    secondary = noDefault (strOption null);
                    surface = noDefault (strOption null);
                    surfaceText = noDefault (strOption null);
                    surfaceVariant = noDefault (strOption null);
                    surfaceVariantText = noDefault (strOption null);
                    surfaceTint = noDefault (strOption null);
                    background = noDefault (strOption null);
                    backgroundText = noDefault (strOption null);
                    outline = noDefault (strOption null);
                    surfaceContainer = noDefault (strOption null);
                    surfaceContainerHigh = noDefault (strOption null);
                    error = allowNull (strOption null);
                    warning = allowNull (strOption null);
                    info = allowNull (strOption null);
                };
            })
        );
    };

    widgetsOption = allowNull (
        listOfOption (submodule {
            options = {
                enabled = noDefault (boolOption null);
                id = noDefault (
                    enumOption [
                        "launcherButton"
                        "workspaceSwitcher"
                        "focusedWindow"
                        "runningApps"
                        "clock"
                        "weather"
                        "music"
                        "clipboard"
                        "cpuUsage"
                        "memUsage"
                        "cpuTemp"
                        "gpuTemp"
                        "systemTray"
                        "privacyIndicator"
                        "controlCenterButton"
                        "notificationButton"
                        "battery"
                        "vpn"
                        "idleInhibitor"
                        "spacer"
                        "separator"
                        "network_speed_monitor"
                        "keyboard_layout_name"
                        "notepadButton"
                    ]
                    null
                );
            };
        })
        null
    );

    topBarLeftWidgets = widgetsOption;
    topBarCenterWidgets = widgetsOption;
    topBarRightWidgets = widgetsOption;

    workspaceNameIcons = allowNull (
        listOfOption (submodule {
            options = {
                type = noDefault (enumOption ["icon" "text"] null);
                value = noDefault (strOption null);
            };
        })
        null
    );

    screenPreferences = allowNull (
        lib.mkOption {
            default = null;
            type = submodule {
                options = lib.genAttrs [
                    "topBar"
                    "dock"
                    "notifications"
                    "wallpaper"
                    "osd"
                    "toast"
                    "notepad"
                    "systemTray"
                ] (_: allowNull (listOfOption str null));
            };
        }
    );

    cfg = config.programs.dankMaterialShell;

    removeNulls = v:
        if lib.isAttrs v
        then lib.filterAttrs (_: v: v != null) (lib.mapAttrs (_: removeNulls) v)
        else v;

    defaultSettings = removeNulls (lib.removeAttrs cfg.defaultSettings ["theme"]);
in {
    options.programs.dankMaterialShell.defaultSettings = lib.mkOption {
        default = null;
        type = nullOr (submodule {
            options = {
                inherit
                    theme
                    workspaceNameIcons
                    screenPreferences
                    topBarLeftWidgets
                    topBarCenterWidgets
                    topBarRightWidgets
                    ;

                topBarTransparency = allowNull (floatOption null);
                topBarWidgetTransparency = allowNull (floatOption null);
                popupTransparency = allowNull (floatOption null);
                dockTransparency = allowNull (floatOption null);
                use24HourClock = allowNull (boolOption null);
                useFahrenheit = allowNull (boolOption null);
                nightModeEnabled = allowNull (boolOption null);
                weatherLocation = allowNull (strOption null);
                weatherCoordinates = allowNull (strOption null);
                useAutoLocation = allowNull (boolOption null);
                weatherEnabled = allowNull (boolOption null);
                showLauncherButton = allowNull (boolOption null);
                showWorkspaceSwitcher = allowNull (boolOption null);
                showFocusedWindow = allowNull (boolOption null);
                showWeather = allowNull (boolOption null);
                showMusic = allowNull (boolOption null);
                showClipboard = allowNull (boolOption null);
                showCpuUsage = allowNull (boolOption null);
                showMemUsage = allowNull (boolOption null);
                showCpuTemp = allowNull (boolOption null);
                showGpuTemp = allowNull (boolOption null);
                selectedGpuIndex = allowNull (intOption null);
                enabledGpuPciIds = allowNull (listOfOption int null);
                showSystemTray = allowNull (boolOption null);
                showClock = allowNull (boolOption null);
                showNotificationButton = allowNull (boolOption null);
                showBattery = allowNull (boolOption null);
                showControlCenterButton = allowNull (boolOption null);
                controlCenterShowNetworkIcon = allowNull (boolOption null);
                controlCenterShowBluetoothIcon = allowNull (boolOption null);
                controlCenterShowAudioIcon = allowNull (boolOption null);
                showWorkspaceIndex = allowNull (boolOption null);
                showWorkspacePadding = allowNull (boolOption null);
                showWorkspaceApps = allowNull (boolOption null);
                maxWorkspaceIcons = allowNull (intOption null);
                workspacesPerMonitor = allowNull (boolOption null);
                clockCompactMode = allowNull (boolOption null);
                focusedWindowCompactMode = allowNull (boolOption null);
                runningAppsCompactMode = allowNull (boolOption null);
                runningAppsCurrentWorkspace = allowNull (boolOption null);
                clockDateFormat = allowNull (strOption null);
                lockDateFormat = allowNull (strOption null);
                mediaSize = allowNull (intOption null);
                topBarWidgetOrder = allowNull (boolOption null);
                appLauncherViewMode = allowNull (enumOption ["grid" "list"] null);
                spotlightModalViewMode = allowNull (enumOption ["grid" "list"] null);
                networkPreference = allowNull (enumOption ["auto" "wifi" "ethernet"] null);
                iconTheme = allowNull (strOption null);
                useOSLogo = allowNull (boolOption null);
                osLogoColorOverride = allowNull (strOption null);
                osLogoBrightness = allowNull (floatOption null);
                osLogoContrast = allowNull (floatOption null);
                wallpaperDynamicTheming = allowNull (boolOption null);
                fontFamily = allowNull (strOption null);
                monoFontFamily = allowNull (strOption null);
                fontWeight = allowNull (intOption null);
                fontScale = allowNull (floatOption null);
                gtkThemingEnabled = allowNull (boolOption null);
                qtThemingEnabled = allowNull (boolOption null);
                showDock = allowNull (boolOption null);
                dockAutoHide = allowNull (boolOption null);
                cornerRadius = allowNull (intOption null);
                notificationOverlayEnabled = allowNull (boolOption null);
                topBarAutoHide = allowNull (boolOption null);
                topBarVisible = allowNull (boolOption null);
                notificationTimeoutLow = allowNull (intOption null);
                notificationTimeoutNormal = allowNull (intOption null);
                notificationTimeoutCritical = allowNull (intOption null);
                topBarSpacing = allowNull (intOption null);
                topBarBottomGap = allowNull (intOption null);
                topBarInnerPadding = allowNull (intOption null);
                topBarSquareCorners = allowNull (boolOption null);
                topBarNoBackground = allowNull (boolOption null);
                lockScreenShowPowerActions = allowNull (boolOption null);
                hideBrightnessSlider = allowNull (boolOption null);
            };
        });
    };

    config.xdg.configFile."DankMaterialShell/custom-theme.json" = lib.mkIf (lib.isAttrs cfg.defaultSettings.theme)
    {
        source = pkgs.writers.writeJSON "custom-theme.json" (cfg.defaultSettings.theme);
    };

    config.xdg.configFile."DankMaterialShell/default-settings.json" = lib.mkIf (cfg.defaultSettings != null)
    {
        source = pkgs.writers.writeJSON "default-settings.json" (
            defaultSettings
            // (lib.optionalAttrs (lib.isString cfg.defaultSettings.theme) {
                currentThemeName = cfg.defaultSettings.theme;
            })
            // (lib.optionalAttrs (lib.isAttrs cfg.defaultSettings.theme) {
                currentThemeName = "custom";
                customThemeFile = config.xdg.configFile."DankMaterialShell/custom-theme.json".source;
            })
        );
    };
}
