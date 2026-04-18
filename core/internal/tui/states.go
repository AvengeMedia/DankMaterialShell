package tui

type ApplicationState int

const (
	StateWelcome ApplicationState = iota
	StateSelectWindowManager
	StateSelectTerminal
	StateDetectingDeps
	StateDependencyReview
	StateGentooUseFlags
	StateGentooGCCCheck
	StateSelectPrivesc
	StateAuthMethodChoice
	StateFingerprintAuth
	StatePasswordPrompt
	StateInstallingPackages
	StateConfigConfirmation
	StateDeployingConfigs
	StateInstallComplete
	StateFinalComplete
	StateError
)
