import qs.DankCommon.Widgets as DankCommon
import qs.Services

DankCommon.DankDropdown {
    // Hyprland drops a focus grab when a whitelisted popup takes its own xdg grab
    popupGrabsFocus: !(CompositorService.useHyprlandFocusGrab && transientSurfaceTracker)
}
