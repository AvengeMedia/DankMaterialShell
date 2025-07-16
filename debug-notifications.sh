#!/bin/bash

echo "Testing notification fixes..."
echo "This will test:"
echo "1. Icon visibility (should show round icons or emoji fallbacks)"
echo "2. Expand/collapse in popup (should work smoothly)"
echo "3. Expand/collapse in history (should work reliably)"
echo "4. Button alignment (should not be glitchy)"
echo ""

# Wait for shell to be ready
sleep 3

echo "Sending test notifications..."

# Test Discord grouping with multiple messages
notify-send -a "Discord" "User1" "First message in Discord"
sleep 0.5
notify-send -a "Discord" "User2" "Second message in Discord"
sleep 0.5
notify-send -a "Discord" "User3" "Third message in Discord"
sleep 1

# Test app with likely good icon
notify-send -a "firefox" "Download" "File downloaded successfully"
sleep 0.5
notify-send -a "firefox" "Update" "Browser updated"
sleep 1

# Test app that might not have icon (fallback test)
notify-send -a "TestApp" "Test 1" "This should show fallback icon"
sleep 0.5
notify-send -a "TestApp" "Test 2" "Another test notification"

echo ""
echo "Notifications sent! Please test:"
echo "1. Check notification popup - icons should be visible (round)"
echo "2. Try expand/collapse buttons in popup"
echo "3. Open notification history"
echo "4. Try expand/collapse buttons in history"
echo "5. Check that buttons stay aligned when collapsing"
echo ""
echo "Look for console logs in quickshell terminal for debugging info"