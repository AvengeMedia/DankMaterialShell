#!/bin/bash

echo "Waiting for notification service to be ready..."

# Wait for the notification service to be available
max_attempts=20
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if notify-send -a "test" "Service Ready Test" "Testing..." 2>/dev/null; then
        echo "Notification service is ready!"
        break
    fi
    echo "Attempt $((attempt + 1))/$max_attempts - waiting..."
    sleep 2
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    echo "Timeout waiting for notification service"
    exit 1
fi

echo ""
echo "Running layout and functionality tests..."
echo ""

# Now run the actual tests
notify-send -a "firefox" "Test 1" "Firefox notification 1"
sleep 0.5
notify-send -a "firefox" "Test 2" "Firefox notification 2"
sleep 1

notify-send -a "MyCustomApp" "Custom 1" "Custom app notification 1"
sleep 0.5
notify-send -a "MyCustomApp" "Custom 2" "Custom app notification 2"
sleep 1

notify-send -a "code" "VS Code 1" "Code notification 1"
sleep 0.5
notify-send -a "code" "VS Code 2" "Code notification 2"

echo ""
echo "✅ All notifications sent successfully!"
echo ""
echo "🧪 Test Results Expected:"
echo "1. ✅ Button container stays within bounds on collapse"
echo "2. ✅ Count badges show as small circles (not parentheses)"
echo "3. ✅ App icons show with themed backgrounds (not black)"
echo "4. ✅ First letter fallbacks when icons don't load"
echo "5. ✅ Expand/collapse works in both popup and history"
echo ""
echo "Check your notification popup and history panel!"