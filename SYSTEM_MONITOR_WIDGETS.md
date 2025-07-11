# System Monitor Widgets Usage Example

## Installation Complete

The CPU and RAM monitor widgets have been successfully created and integrated into your quickshell project:

### Files Created:
- `/Widgets/CpuMonitorWidget.qml` - CPU usage monitor with progress bar and percentage
- `/Widgets/RamMonitorWidget.qml` - RAM usage monitor with progress bar and percentage  
- `/Services/SystemMonitorService.qml` - Backend service for system monitoring

### Files Updated:
- `/Widgets/qmldir` - Added widget exports
- `/Services/qmldir` - Added service export

## Usage in TopBar

To add the system monitor widgets to your TopBar, add them to the right section alongside the BatteryWidget:

```qml
// In TopBar.qml, around line 716 after BatteryWidget
BatteryWidget {
    anchors.verticalCenter: parent.verticalCenter
}

// Add these new widgets:
CpuMonitorWidget {
    anchors.verticalCenter: parent.verticalCenter
    showPercentage: true
    showIcon: true
}

RamMonitorWidget {
    anchors.verticalCenter: parent.verticalCenter
    showPercentage: true
    showIcon: true
}
```

## Widget Features

### CpuMonitorWidget:
- **Real-time CPU usage monitoring** (updates every 2 seconds)
- **Visual progress bar** with color coding:
  - Green: < 60% usage
  - Orange: 60-80% usage  
  - Red: > 80% usage
- **Tooltip** showing CPU usage, core count, and frequency
- **Material Design CPU icon** (󰘚)
- **Configurable properties:**
  - `showPercentage: bool` - Show/hide percentage text
  - `showIcon: bool` - Show/hide CPU icon

### RamMonitorWidget:
- **Real-time RAM usage monitoring** (updates every 3 seconds)
- **Visual progress bar** with color coding:
  - Blue: < 75% usage
  - Orange: 75-90% usage
  - Red: > 90% usage
- **Tooltip** showing memory usage, used/total memory in GB/MB
- **Material Design memory icon** (󰍛)
- **Configurable properties:**
  - `showPercentage: bool` - Show/hide percentage text  
  - `showIcon: bool` - Show/hide RAM icon

### SystemMonitorService:
- **Centralized system monitoring** backend service
- **CPU monitoring:** usage, core count, frequency, temperature
- **Memory monitoring:** usage percentage, total/used/free memory
- **Automatic updates** with configurable intervals
- **Helper functions** for formatting and color coding

## Widget Customization

Both widgets inherit your theme colors and styling:
- Uses `Theme.cornerRadius` for rounded corners
- Uses `Theme.primary/secondary` colors for progress bars
- Uses `Theme.error/warning` for alert states
- Uses `Theme.surfaceText` for text color
- Consistent hover effects matching other widgets

## System Requirements

The widgets use standard Linux system commands:
- `/proc/stat` for CPU usage
- `/proc/meminfo` via `free` command for memory info
- `/proc/cpuinfo` for CPU details
- Works on most Linux distributions

The widgets are designed to integrate seamlessly with your existing quickshell material design theme and provide essential system monitoring information at a glance.
