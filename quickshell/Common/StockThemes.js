// Stock theme definitions for DankMaterialShell
// Separated from Theme.qml to keep that file clean

const CatppuccinMocha = {
    surface: "#181825",
    surfaceText: "#cdd6f4",
    surfaceVariant: "#1e1e2e",
    surfaceVariantText: "#a6adc8",
    background: "#181825",
    backgroundText: "#cdd6f4",
    outline: "#6c7086",
    surfaceContainer: "#1e1e2e",
    surfaceContainerHigh: "#313244",
    surfaceContainerHighest: "#45475a"
}

const CatppuccinLatte = {
    surface: "#e6e9ef",
    surfaceText: "#4c4f69",
    surfaceVariant: "#e6e9ef",
    surfaceVariantText: "#6c6f85",
    background: "#eff1f5",
    backgroundText: "#4c4f69",
    outline: "#9ca0b0",
    surfaceContainer: "#dce0e8",
    surfaceContainerHigh: "#ccd0da",
    surfaceContainerHighest: "#bcc0cc"
}

const CatppuccinVariants = {
    "cat-rosewater": {
        name: "Rosewater",
        dark: { primary: "#f5e0dc", secondary: "#f2cdcd", primaryText: "#1e1e2e", primaryContainer: "#7d5d56", surfaceTint: "#f5e0dc" },
        light: { primary: "#dc8a78", secondary: "#dd7878", primaryText: "#ffffff", primaryContainer: "#f6e7e3", surfaceTint: "#dc8a78" }
    },
    "cat-flamingo": {
        name: "Flamingo",
        dark: { primary: "#f2cdcd", secondary: "#f5e0dc", primaryText: "#1e1e2e", primaryContainer: "#7a555a", surfaceTint: "#f2cdcd" },
        light: { primary: "#dd7878", secondary: "#dc8a78", primaryText: "#ffffff", primaryContainer: "#f6e5e5", surfaceTint: "#dd7878" }
    },
    "cat-pink": {
        name: "Pink",
        dark: { primary: "#f5c2e7", secondary: "#cba6f7", primaryText: "#1e1e2e", primaryContainer: "#7a3f69", surfaceTint: "#f5c2e7" },
        light: { primary: "#ea76cb", secondary: "#8839ef", primaryText: "#ffffff", primaryContainer: "#f7d7ee", surfaceTint: "#ea76cb" }
    },
    "cat-mauve": {
        name: "Mauve",
        dark: { primary: "#cba6f7", secondary: "#b4befe", primaryText: "#1e1e2e", primaryContainer: "#55307f", surfaceTint: "#cba6f7" },
        light: { primary: "#8839ef", secondary: "#7287fd", primaryText: "#ffffff", primaryContainer: "#eadcff", surfaceTint: "#8839ef" }
    },
    "cat-red": {
        name: "Red",
        dark: { primary: "#f38ba8", secondary: "#eba0ac", primaryText: "#1e1e2e", primaryContainer: "#6f2438", surfaceTint: "#f38ba8" },
        light: { primary: "#d20f39", secondary: "#e64553", primaryText: "#ffffff", primaryContainer: "#f6d0d6", surfaceTint: "#d20f39" }
    },
    "cat-maroon": {
        name: "Maroon",
        dark: { primary: "#eba0ac", secondary: "#f38ba8", primaryText: "#1e1e2e", primaryContainer: "#6d3641", surfaceTint: "#eba0ac" },
        light: { primary: "#e64553", secondary: "#d20f39", primaryText: "#ffffff", primaryContainer: "#f7d8dc", surfaceTint: "#e64553" }
    },
    "cat-peach": {
        name: "Peach",
        dark: { primary: "#fab387", secondary: "#f9e2af", primaryText: "#1e1e2e", primaryContainer: "#734226", surfaceTint: "#fab387" },
        light: { primary: "#fe640b", secondary: "#df8e1d", primaryText: "#ffffff", primaryContainer: "#ffe4d5", surfaceTint: "#fe640b" }
    },
    "cat-yellow": {
        name: "Yellow",
        dark: { primary: "#f9e2af", secondary: "#a6e3a1", primaryText: "#1e1e2e", primaryContainer: "#6e5a2f", surfaceTint: "#f9e2af" },
        light: { primary: "#df8e1d", secondary: "#40a02b", primaryText: "#ffffff", primaryContainer: "#fff6d6", surfaceTint: "#df8e1d" }
    },
    "cat-green": {
        name: "Green",
        dark: { primary: "#a6e3a1", secondary: "#94e2d5", primaryText: "#1e1e2e", primaryContainer: "#2f5f36", surfaceTint: "#a6e3a1" },
        light: { primary: "#40a02b", secondary: "#179299", primaryText: "#ffffff", primaryContainer: "#dff4e0", surfaceTint: "#40a02b" }
    },
    "cat-teal": {
        name: "Teal",
        dark: { primary: "#94e2d5", secondary: "#89dceb", primaryText: "#1e1e2e", primaryContainer: "#2e5e59", surfaceTint: "#94e2d5" },
        light: { primary: "#179299", secondary: "#04a5e5", primaryText: "#ffffff", primaryContainer: "#daf3f1", surfaceTint: "#179299" }
    },
    "cat-sky": {
        name: "Sky",
        dark: { primary: "#89dceb", secondary: "#74c7ec", primaryText: "#1e1e2e", primaryContainer: "#24586a", surfaceTint: "#89dceb" },
        light: { primary: "#04a5e5", secondary: "#209fb5", primaryText: "#ffffff", primaryContainer: "#dbf1fb", surfaceTint: "#04a5e5" }
    },
    "cat-sapphire": {
        name: "Sapphire",
        dark: { primary: "#74c7ec", secondary: "#89b4fa", primaryText: "#1e1e2e", primaryContainer: "#1f4d6f", surfaceTint: "#74c7ec" },
        light: { primary: "#209fb5", secondary: "#1e66f5", primaryText: "#ffffff", primaryContainer: "#def3f8", surfaceTint: "#209fb5" }
    },
    "cat-blue": {
        name: "Blue",
        dark: { primary: "#89b4fa", secondary: "#b4befe", primaryText: "#1e1e2e", primaryContainer: "#243f75", surfaceTint: "#89b4fa" },
        light: { primary: "#1e66f5", secondary: "#7287fd", primaryText: "#ffffff", primaryContainer: "#e0e9ff", surfaceTint: "#1e66f5" }
    },
    "cat-lavender": {
        name: "Lavender",
        dark: { primary: "#b4befe", secondary: "#cba6f7", primaryText: "#1e1e2e", primaryContainer: "#3f4481", surfaceTint: "#b4befe" },
        light: { primary: "#7287fd", secondary: "#8839ef", primaryText: "#ffffff", primaryContainer: "#e5e8ff", surfaceTint: "#7287fd" }
    }
}

function getCatppuccinTheme(variant, isLight = false) {
    const variantData = CatppuccinVariants[variant]
    if (!variantData) return null

    const baseColors = isLight ? CatppuccinLatte : CatppuccinMocha
    const accentColors = isLight ? variantData.light : variantData.dark

    return Object.assign({
        name: `${variantData.name}${isLight ? ' Light' : ''}`
    }, baseColors, accentColors)
}

const StockThemes = {
    DARK: {
        blue: {
            name: "Blue",
            primary: "#42a5f5",
            primaryText: "#000000",
            primaryContainer: "#0d47a1",
            secondary: "#8ab4f8",
            surface: "#101418",
            surfaceText: "#e0e2e8",
            surfaceVariant: "#42474e",
            surfaceVariantText: "#c2c7cf",
            surfaceTint: "#8ab4f8",
            background: "#101418",
            backgroundText: "#e0e2e8",
            outline: "#8c9199",
            surfaceContainer: "#1d2024",
            surfaceContainerHigh: "#272a2f",
            surfaceContainerHighest: "#32353a"
        },
        purple: {
            name: "Purple",
            primary: "#D0BCFF",
            primaryText: "#381E72",
            primaryContainer: "#4F378B",
            secondary: "#CCC2DC",
            surface: "#141218",
            surfaceText: "#e6e0e9",
            surfaceVariant: "#49454e",
            surfaceVariantText: "#cac4cf",
            surfaceTint: "#D0BCFF",
            background: "#141218",
            backgroundText: "#e6e0e9",
            outline: "#948f99",
            surfaceContainer: "#211f24",
            surfaceContainerHigh: "#2b292f",
            surfaceContainerHighest: "#36343a"
        },
        green: {
            name: "Green",
            primary: "#4caf50",
            primaryText: "#000000",
            primaryContainer: "#1b5e20",
            secondary: "#81c995",
            surface: "#10140f",
            surfaceText: "#e0e4db",
            surfaceVariant: "#424940",
            surfaceVariantText: "#c2c9bd",
            surfaceTint: "#81c995",
            background: "#10140f",
            backgroundText: "#e0e4db",
            outline: "#8c9388",
            surfaceContainer: "#1d211b",
            surfaceContainerHigh: "#272b25",
            surfaceContainerHighest: "#323630"
        },
        orange: {
            name: "Orange",
            primary: "#ff6d00",
            primaryText: "#000000",
            primaryContainer: "#3e2723",
            secondary: "#ffb74d",
            surface: "#1a120e",
            surfaceText: "#f0dfd8",
            surfaceVariant: "#52443d",
            surfaceVariantText: "#d7c2b9",
            surfaceTint: "#ffb74d",
            background: "#1a120e",
            backgroundText: "#f0dfd8",
            outline: "#a08d85",
            surfaceContainer: "#271e1a",
            surfaceContainerHigh: "#322824",
            surfaceContainerHighest: "#3d332e"
        },
        red: {
            name: "Red",
            primary: "#f44336",
            primaryText: "#000000",
            primaryContainer: "#4a0e0e",
            secondary: "#f28b82",
            surface: "#1a1110",
            surfaceText: "#f1dedc",
            surfaceVariant: "#534341",
            surfaceVariantText: "#d8c2be",
            surfaceTint: "#f28b82",
            background: "#1a1110",
            backgroundText: "#f1dedc",
            outline: "#a08c89",
            surfaceContainer: "#271d1c",
            surfaceContainerHigh: "#322826",
            surfaceContainerHighest: "#3d3231"
        },
        cyan: {
            name: "Cyan",
            primary: "#00bcd4",
            primaryText: "#000000",
            primaryContainer: "#004d5c",
            secondary: "#4dd0e1",
            surface: "#0e1416",
            surfaceText: "#dee3e5",
            surfaceVariant: "#3f484a",
            surfaceVariantText: "#bfc8ca",
            surfaceTint: "#4dd0e1",
            background: "#0e1416",
            backgroundText: "#dee3e5",
            outline: "#899295",
            surfaceContainer: "#1b2122",
            surfaceContainerHigh: "#252b2c",
            surfaceContainerHighest: "#303637"
        },
        pink: {
            name: "Pink",
            primary: "#e91e63",
            primaryText: "#000000",
            primaryContainer: "#4a0e2f",
            secondary: "#f8bbd9",
            surface: "#191112",
            surfaceText: "#f0dee0",
            surfaceVariant: "#524345",
            surfaceVariantText: "#d6c2c3",
            surfaceTint: "#f8bbd9",
            background: "#191112",
            backgroundText: "#f0dee0",
            outline: "#9f8c8e",
            surfaceContainer: "#261d1e",
            surfaceContainerHigh: "#312829",
            surfaceContainerHighest: "#3c3233"
        },
        amber: {
            name: "Amber",
            primary: "#ffc107",
            primaryText: "#000000",
            primaryContainer: "#4a3c00",
            secondary: "#ffd54f",
            surface: "#17130b",
            surfaceText: "#ebe1d4",
            surfaceVariant: "#4d4639",
            surfaceVariantText: "#d0c5b4",
            surfaceTint: "#ffd54f",
            background: "#17130b",
            backgroundText: "#ebe1d4",
            outline: "#998f80",
            surfaceContainer: "#231f17",
            surfaceContainerHigh: "#2e2921",
            surfaceContainerHighest: "#39342b"
        },
        coral: {
            name: "Coral",
            primary: "#ffb4ab",
            primaryText: "#000000",
            primaryContainer: "#8c1d18",
            secondary: "#f9dedc",
            surface: "#1a1110",
            surfaceText: "#f1dedc",
            surfaceVariant: "#534341",
            surfaceVariantText: "#d8c2bf",
            surfaceTint: "#ffb4ab",
            background: "#1a1110",
            backgroundText: "#f1dedc",
            outline: "#a08c8a",
            surfaceContainer: "#271d1c",
            surfaceContainerHigh: "#322826",
            surfaceContainerHighest: "#3d3231"
        },
        monochrome: {
            name: "Monochrome",
            primary: "#ffffff",
            primaryText: "#2b303c",
            primaryContainer: "#424753",
            secondary: "#c4c6d0",
            surface: "#2a2a2a",
            surfaceText: "#e4e2e3",
            surfaceVariant: "#474648",
            surfaceVariantText: "#c8c6c7",
            surfaceTint: "#c2c6d6",
            background: "#131315",
            backgroundText: "#e4e2e3",
            outline: "#929092",
            surfaceContainer: "#353535",
            surfaceContainerHigh: "#424242",
            surfaceContainerHighest: "#505050",
            error: "#ffb4ab",
            warning: "#3f4759",
            info: "#595e6c",
            matugen_type: "scheme-monochrome"
        }
    },
    LIGHT: {
        blue: {
            name: "Blue Light",
            primary: "#1976d2",
            primaryText: "#ffffff",
            primaryContainer: "#e3f2fd",
            secondary: "#42a5f5",
            surface: "#f7f9ff",
            surfaceText: "#181c20",
            surfaceVariant: "#dee3eb",
            surfaceVariantText: "#42474e",
            surfaceTint: "#1976d2",
            background: "#f7f9ff",
            backgroundText: "#181c20",
            outline: "#72777f",
            surfaceContainer: "#eceef4",
            surfaceContainerHigh: "#e6e8ee",
            surfaceContainerHighest: "#e0e2e8"
        },
        purple: {
            name: "Purple Light",
            primary: "#6750A4",
            primaryText: "#ffffff",
            primaryContainer: "#EADDFF",
            secondary: "#625B71",
            surface: "#fef7ff",
            surfaceText: "#1d1b20",
            surfaceVariant: "#e7e0eb",
            surfaceVariantText: "#49454e",
            surfaceTint: "#6750A4",
            background: "#fef7ff",
            backgroundText: "#1d1b20",
            outline: "#7a757f",
            surfaceContainer: "#f2ecf4",
            surfaceContainerHigh: "#ece6ee",
            surfaceContainerHighest: "#e6e0e9"
        },
        green: {
            name: "Green Light",
            primary: "#2e7d32",
            primaryText: "#ffffff",
            primaryContainer: "#e8f5e8",
            secondary: "#4caf50",
            surface: "#f7fbf1",
            surfaceText: "#191d17",
            surfaceVariant: "#dee5d8",
            surfaceVariantText: "#424940",
            surfaceTint: "#2e7d32",
            background: "#f7fbf1",
            backgroundText: "#191d17",
            outline: "#72796f",
            surfaceContainer: "#ecefe6",
            surfaceContainerHigh: "#e6e9e0",
            surfaceContainerHighest: "#e0e4db"
        },
        orange: {
            name: "Orange Light",
            primary: "#e65100",
            primaryText: "#ffffff",
            primaryContainer: "#ffecb3",
            secondary: "#ff9800",
            surface: "#fff8f6",
            surfaceText: "#221a16",
            surfaceVariant: "#f4ded5",
            surfaceVariantText: "#52443d",
            surfaceTint: "#e65100",
            background: "#fff8f6",
            backgroundText: "#221a16",
            outline: "#85736c",
            surfaceContainer: "#fceae3",
            surfaceContainerHigh: "#f6e5de",
            surfaceContainerHighest: "#f0dfd8"
        },
        red: {
            name: "Red Light",
            primary: "#d32f2f",
            primaryText: "#ffffff",
            primaryContainer: "#ffebee",
            secondary: "#f44336",
            surface: "#fff8f7",
            surfaceText: "#231918",
            surfaceVariant: "#f5ddda",
            surfaceVariantText: "#534341",
            surfaceTint: "#d32f2f",
            background: "#fff8f7",
            backgroundText: "#231918",
            outline: "#857370",
            surfaceContainer: "#fceae7",
            surfaceContainerHigh: "#f7e4e1",
            surfaceContainerHighest: "#f1dedc"
        },
        cyan: {
            name: "Cyan Light",
            primary: "#0097a7",
            primaryText: "#ffffff",
            primaryContainer: "#e0f2f1",
            secondary: "#00bcd4",
            surface: "#f5fafc",
            surfaceText: "#171d1e",
            surfaceVariant: "#dbe4e6",
            surfaceVariantText: "#3f484a",
            surfaceTint: "#0097a7",
            background: "#f5fafc",
            backgroundText: "#171d1e",
            outline: "#6f797b",
            surfaceContainer: "#e9eff0",
            surfaceContainerHigh: "#e3e9eb",
            surfaceContainerHighest: "#dee3e5"
        },
        pink: {
            name: "Pink Light",
            primary: "#c2185b",
            primaryText: "#ffffff",
            primaryContainer: "#fce4ec",
            secondary: "#e91e63",
            surface: "#fff8f7",
            surfaceText: "#22191a",
            surfaceVariant: "#f3dddf",
            surfaceVariantText: "#524345",
            surfaceTint: "#c2185b",
            background: "#fff8f7",
            backgroundText: "#22191a",
            outline: "#847375",
            surfaceContainer: "#fbeaeb",
            surfaceContainerHigh: "#f5e4e5",
            surfaceContainerHighest: "#f0dee0"
        },
        amber: {
            name: "Amber Light",
            primary: "#ff8f00",
            primaryText: "#000000",
            primaryContainer: "#fff8e1",
            secondary: "#ffc107",
            surface: "#fff8f2",
            surfaceText: "#1f1b13",
            surfaceVariant: "#ede1cf",
            surfaceVariantText: "#4d4639",
            surfaceTint: "#ff8f00",
            background: "#fff8f2",
            backgroundText: "#1f1b13",
            outline: "#7f7667",
            surfaceContainer: "#f6ecdf",
            surfaceContainerHigh: "#f1e7d9",
            surfaceContainerHighest: "#ebe1d4"
        },
        coral: {
            name: "Coral Light",
            primary: "#8c1d18",
            primaryText: "#ffffff",
            primaryContainer: "#ffdad6",
            secondary: "#ff5449",
            surface: "#fff8f7",
            surfaceText: "#231918",
            surfaceVariant: "#f5ddda",
            surfaceVariantText: "#534341",
            surfaceTint: "#8c1d18",
            background: "#fff8f7",
            backgroundText: "#231918",
            outline: "#857371",
            surfaceContainer: "#fceae7",
            surfaceContainerHigh: "#f6e4e2",
            surfaceContainerHighest: "#f1dedc"
        },
        monochrome: {
            name: "Monochrome Light",
            primary: "#2b303c",
            primaryText: "#ffffff",
            primaryContainer: "#d6d7dc",
            secondary: "#4a4d56",
            surface: "#f5f5f6",
            surfaceText: "#2a2a2a",
            surfaceVariant: "#e0e0e2",
            surfaceVariantText: "#424242",
            surfaceTint: "#5a5f6e",
            background: "#ffffff",
            backgroundText: "#1a1a1a",
            outline: "#757577",
            surfaceContainer: "#e8e8ea",
            surfaceContainerHigh: "#dcdcde",
            surfaceContainerHighest: "#d0d0d2",
            error: "#ba1a1a",
            warning: "#f9e79f",
            info: "#5d6475",
            matugen_type: "scheme-monochrome"
        }
    }
}

const ThemeCategories = {
    GENERIC: {
        name: "Generic",
        variants: ["blue", "purple", "green", "orange", "red", "cyan", "pink", "amber", "coral", "monochrome"]
    },
    CATPPUCCIN: {
        name: "Catppuccin",
        variants: Object.keys(CatppuccinVariants)
    }
}

const ThemeNames = {
    BLUE: "blue",
    PURPLE: "purple",
    GREEN: "green",
    ORANGE: "orange",
    RED: "red",
    CYAN: "cyan",
    PINK: "pink",
    AMBER: "amber",
    CORAL: "coral",
    MONOCHROME: "monochrome",
    DYNAMIC: "dynamic"
}

function isStockTheme(themeName) {
    return Object.keys(StockThemes.DARK).includes(themeName)
}

function isCatppuccinVariant(themeName) {
    return Object.keys(CatppuccinVariants).includes(themeName)
}

function getAvailableThemes(isLight = false) {
    return isLight ? StockThemes.LIGHT : StockThemes.DARK
}

function getThemeByName(themeName, isLight = false) {
    if (isCatppuccinVariant(themeName)) {
        return getCatppuccinTheme(themeName, isLight)
    }
    const themes = getAvailableThemes(isLight)
    return themes[themeName] || themes.blue
}

function getAllThemeNames() {
    return Object.keys(StockThemes.DARK)
}

function getCatppuccinVariantNames() {
    return Object.keys(CatppuccinVariants)
}

function getThemeCategories() {
    return ThemeCategories
}