#!/usr/bin/env bash

# Enhanced Notification System Test Script with Common Icons
# Uses icons that are more likely to be available on most systems

echo "🔔 Testing Enhanced Notification System Features"
echo "============================================================="

# Check what icons are available
echo "Checking available icons..."
if [ -d "~/.local/share/icons/Papirus" ]; then
    echo "✓ Icon theme found"
    ICON_BASE="~/.local/share/icons/Papirus"
else
    echo "! Using fallback icons"
    ICON_BASE=""
fi

# Test 1: Basic notifications with markdown
echo "📱 Test 1: Basic notifications with markdown"
notify-send -h string:desktop-entry:org.gnome.Settings -i preferences-desktop "Settings" "**Bold text** and *italic text* with [links](https://example.com) and \`code blocks\`"
sleep 2

# Test 2: Media notifications with rich formatting (grouping)
echo "🎵 Test 2: Media notifications with rich formatting (grouping)"
notify-send -h string:desktop-entry:spotify -i audio-x-generic "Spotify" "**Now Playing:** *Song 1* by **Artist A**\n\nAlbum: ~Greatest Hits~\nDuration: \`3:45\`"
sleep 1
notify-send -h string:desktop-entry:spotify -i audio-x-generic "Spotify" "**Now Playing:** *Song 2* by **Artist B**\n\n> From the album: \"New Releases\"\n- Track #4\n- \`4:12\`"
sleep 1
notify-send -h string:desktop-entry:spotify -i audio-x-generic "Spotify" "**Now Playing:** *Song 3* by **Artist C**\n\n### Recently Added\n- [View on Spotify](https://spotify.com)\n- Duration: \`2:58\`"
sleep 2

# Test 3: System notifications with markdown (separate groups)
echo "🔋 Test 3: System notifications with markdown (separate apps)"
notify-send -h string:desktop-entry:org.gnome.PowerStats -i battery "Power Manager" "⚠️ **Battery Low:** \`15%\` remaining\n\n### Power Saving Tips:\n- Reduce screen brightness\n- *Close unnecessary apps*\n- [Power settings](settings://power)"
sleep 1
notify-send -h string:desktop-entry:org.gnome.NetworkDisplays -i network-wired "Network Manager" "✅ **WiFi Connected:** *HomeNetwork*\n\n**Signal Strength:** Strong (85%)\n**IP Address:** \`192.168.1.100\`\n\n> Connection established successfully"
sleep 1
notify-send -h string:desktop-entry:org.gnome.Software -i system-software-update "Software" "📦 **Updates Available**\n\n### Pending Updates:\n- **Firefox** (v119.0)\n- *System libraries* (security)\n- \`python-requests\` (dependency)\n\n[Install All](software://updates) | [View Details](software://details)"
sleep 2

# Test 4: Chat notifications with complex markdown (grouping)
echo "💬 Test 4: Chat notifications with complex markdown (grouping)"
notify-send -h string:desktop-entry:discord -i internet-chat "Discord" "**#general** - User1\n\nHello everyone! 👋\n\n> Just wanted to share this cool project I'm working on:\n- Built with **React** and *TypeScript*\n- Using \`styled-components\` for styling\n- [Check it out](https://github.com/user1/project)"
sleep 1
notify-send -h string:desktop-entry:discord -i internet-chat "Discord" "**#general** - User2\n\nHey there! That looks awesome! 🚀\n\n### Quick question:\nDo you have any tips for:\n1. **State management** patterns?\n2. *Performance optimization*?\n3. Testing with \`jest\`?\n\n> I'm still learning React"
sleep 1
notify-send -h string:desktop-entry:discord -i internet-chat "Discord" "**Direct Message** - john_doe\n\n*Private message from John* 💬\n\n**Subject:** Weekend plans\n\nHey! Want to grab coffee this weekend?\n\n### Suggestions:\n- ☕ Local café on Main St\n- 🥐 That new bakery downtown\n- 🏠 My place (I got a new espresso machine!)\n\n[Reply](discord://dm/john_doe) | [Call](discord://call/john_doe)"
sleep 2

# Test 5: Urgent notifications with markdown
echo "🚨 Test 5: Urgent notifications with markdown"
notify-send -u critical -i dialog-warning "Critical Alert" "🔥 **SYSTEM OVERHEATING** 🔥\n\n### Current Status:\n- **Temperature:** \`85°C\` (Critical)\n- **CPU Usage:** \`95%\`\n- *Thermal throttling active*\n\n> **Immediate Actions Required:**\n1. Close resource-intensive applications\n2. Check cooling system\n3. Reduce workload\n\n[System Monitor](gnome-system-monitor) | [Power Options](gnome-power-statistics)"
sleep 2

# Test 6: Notifications with actions and markdown
echo "⚡ Test 6: Action buttons with markdown"
notify-send -h string:desktop-entry:org.gnome.Software -i system-upgrade "Software" "📦 **System Updates Available**\n\n### Ready to Install:\n- **Security patches** (High priority)\n- *Feature updates* for 3 applications\n- \`kernel\` update (5.15.0 → 5.16.2)\n\n> **Recommended:** Install now for optimal security\n\n**Estimated time:** ~15 minutes\n**Restart required:** Yes\n\n[Install Now](software://install) | [Schedule Later](software://schedule)"
sleep 2

# Test 7: Multiple different apps with rich markdown
echo "📊 Test 7: Multiple different apps with rich markdown"
notify-send -h string:desktop-entry:thunderbird -i mail-message-new "Thunderbird" "📧 **New Messages** (3)\n\n### Recent Emails:\n1. **Sarah Johnson** - *Project Update*\n   > \"The quarterly report is ready for review...\"\n   \n2. **GitHub** - \`[user/repo]\` *Pull Request*\n   > New PR: Fix memory leak in parser\n   \n3. **Newsletter** - *Weekly Tech Digest*\n   > This week: AI advancements, new frameworks...\n\n[Open Inbox](thunderbird://inbox) | [Mark All Read](thunderbird://markread)"
sleep 0.5
notify-send -h string:desktop-entry:org.gnome.Calendar -i office-calendar "Calendar" "📅 **Upcoming Meeting**\n\n### Daily Standup\n- **Time:** 5 minutes\n- **Location:** *Conference Room A*\n- **Attendees:** Team Alpha (8 people)\n\n#### Agenda:\n1. Yesterday's progress\n2. Today's goals  \n3. Blockers discussion\n\n> **Reminder:** Prepare your status update\n\n[Join Video Call](meet://standup) | [Reschedule](calendar://reschedule)"
sleep 0.5
notify-send -h string:desktop-entry:org.gnome.Nautilus -i folder-downloads "Files" "📁 **Download Complete**\n\n### File Details:\n- **Name:** \`document.pdf\`\n- **Size:** *2.4 MB*\n- **Location:** ~/Downloads/\n- **Type:** PDF Document\n\n> **Security:** Scanned ✅ (No threats detected)\n\n**Recent Downloads:**\n- presentation.pptx (1 hour ago)\n- backup.zip (yesterday)\n\n[Open File](file://document.pdf) | [Show in Folder](nautilus://downloads)"
sleep 2

# notify-send --hint=boolean:resident:true "Resident Test" "Click an action - I should stay visible!" --action="Test Action" --action="Close Me"

echo ""
echo "✅ Notification tests completed!"
echo ""
echo "📋 Enhanced Features Tested:"
echo "  • Media notification replacement"
echo "  • System notification grouping"
echo "  • Conversation grouping and auto-expansion"
echo "  • Urgency level handling"
echo "  • Action button support"
echo "  • Multi-app notification handling"
echo ""
echo "🎯 Check your notification popup and notification center to see the results!"
echo ""
echo "Note: Some icons may show as fallback (checkerboard) if icon themes aren't installed."
echo "To install more icons: sudo pacman -S papirus-icon-theme adwaita-icon-theme"
