#!/bin/bash

# Test script to run the Android 16 notification system demo

echo "Starting Android 16 Notification System Demo..."
echo "This demo showcases the enhanced notification grouping and stacking features."
echo ""

# Check if quickshell is available
if ! command -v quickshell &> /dev/null; then
    echo "Error: quickshell is not installed or not in PATH"
    echo "Please install quickshell to run this demo"
    exit 1
fi

# Navigate to the quickshell config directory
cd "$(dirname "$0")/.." || exit 1

# Run the demo in the background
echo "Running demo with quickshell in the background..."
quickshell -p Tests/NotificationSystemDemo.qml &
QUICKSHELL_PID=$!

# Wait for a few seconds to see if it crashes
sleep 5

# Check if the process is still running
if ps -p $QUICKSHELL_PID > /dev/null; then
    echo "Demo is running successfully in the background (PID: $QUICKSHELL_PID)."
    echo "Please close the demo window manually to stop the process."
    # Kill the process for the purpose of this test
    kill $QUICKSHELL_PID
else
    echo "Error: The demo crashed or failed to start."
    exit 1
fi

echo "Demo test completed."