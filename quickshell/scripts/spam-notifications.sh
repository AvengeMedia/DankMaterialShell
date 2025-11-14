#!/bin/bash

# Notification Spam Test Script - Sends 100 rapid notifications from fake apps

echo "NOTIFICATION SPAM TEST - 100 RAPID NOTIFICATIONS"
echo "============================================================="
echo "WARNING: This will send 100 notifications very quickly!"
echo "Press Ctrl+C to cancel, or wait 3 seconds to continue..."
sleep 3

# Arrays of fake app names and icons
APPS=(
    "slack:mail-message-new"
    "discord:internet-chat"
    "teams:call-start"
    "zoom:camera-video"
    "spotify:audio-x-generic"
    "chrome:web-browser"
    "firefox:web-browser"
    "vscode:text-editor"
    "terminal:utilities-terminal"
    "steam:applications-games"
    "telegram:internet-chat"
    "whatsapp:phone"
    "signal:security-high"
    "thunderbird:mail-client"
    "calendar:office-calendar"
    "notes:text-editor"
    "todo:emblem-default"
    "weather:weather-few-clouds"
    "news:rss"
    "reddit:web-browser"
    "twitter:internet-web-browser"
    "instagram:camera-photo"
    "youtube:video-x-generic"
    "netflix:media-playback-start"
    "github:folder-development"
    "gitlab:folder-development"
    "jira:applications-office"
    "notion:text-editor"
    "obsidian:accessories-text-editor"
    "dropbox:folder-remote"
    "gdrive:folder-google-drive"
    "onedrive:folder-cloud"
    "backup:drive-harddisk"
    "antivirus:security-high"
    "vpn:network-vpn"
    "torrent:network-server"
    "docker:application-x-executable"
    "kubernetes:applications-system"
    "postgres:database"
    "mongodb:database"
    "redis:database"
    "nginx:network-server"
    "apache:network-server"
    "jenkins:applications-development"
    "gradle:applications-development"
    "maven:applications-development"
    "npm:package-x-generic"
    "yarn:package-x-generic"
    "pip:package-x-generic"
    "apt:system-software-install"
)

# Arrays of message types
TITLES=(
    "New message"
    "Update available"
    "Download complete"
    "Task finished"
    "Build successful"
    "Deployment complete"
    "Sync complete"
    "Backup finished"
    "Security alert"
    "New notification"
    "Process complete"
    "Upload finished"
    "Connection established"
    "Meeting starting"
    "Reminder"
    "Warning"
    "Error occurred"
    "Success"
    "Failed"
    "Pending"
    "In progress"
    "Scheduled"
    "New activity"
    "Status update"
    "Alert"
    "Information"
    "Breaking news"
    "Hot update"
    "Trending"
    "New release"
)

MESSAGES=(
    "Your request has been processed successfully"
    "New content is available for download"
    "Operation completed without errors"
    "Check your inbox for updates"
    "3 new items require your attention"
    "Background task finished executing"
    "All systems operational"
    "Performance metrics updated"
    "Configuration saved successfully"
    "Database connection established"
    "Cache cleared and rebuilt"
    "Service restarted automatically"
    "Logs have been rotated"
    "Memory usage optimized"
    "Network latency improved"
    "Security scan completed - no threats"
    "Automatic backup created"
    "Files synchronized across devices"
    "Updates installed successfully"
    "New features are now available"
    "Your subscription has been renewed"
    "Report generated and ready"
    "Analysis complete - view results"
    "Queue processed: 42 items"
    "Rate limit will reset in 5 minutes"
    "API call successful (200 OK)"
    "Webhook delivered successfully"
    "Container started on port 8080"
    "Build artifact uploaded"
    "Test suite passed: 100/100"
    "Coverage report: 95%"
    "Dependencies updated to latest"
    "Migration completed successfully"
    "Index rebuilt for faster queries"
    "SSL certificate renewed"
    "Firewall rules updated"
    "DNS propagation complete"
    "CDN cache purged globally"
    "Load balancer health check: OK"
    "Cluster scaled to 5 nodes"
)

# Urgency levels
URGENCY=("low" "normal")

# Counter
COUNT=0
TOTAL=100

echo ""
echo "Starting notification spam..."
echo "------------------------------"

# Send notifications rapidly
for i in $(seq 1 $TOTAL); do
    # Pick random app, title, message, and urgency
    APP=${APPS[$RANDOM % ${#APPS[@]}]}
    APP_NAME=${APP%%:*}
    APP_ICON=${APP#*:}
    TITLE=${TITLES[$RANDOM % ${#TITLES[@]}]}
    MESSAGE=${MESSAGES[$RANDOM % ${#MESSAGES[@]}]}
    URG=${URGENCY[$RANDOM % ${#URGENCY[@]}]}
    
    # Add some variety with random numbers and timestamps
    RAND_NUM=$((RANDOM % 1000))
    TIMESTAMP=$(date +"%H:%M:%S")
    
    # Randomly add extra details to some messages
    if [ $((RANDOM % 3)) -eq 0 ]; then
        MESSAGE="[$TIMESTAMP] $MESSAGE (#$RAND_NUM)"
    fi
    
    # Send notification with very short delay
    notify-send \
        -h string:desktop-entry:$APP_NAME \
        -i $APP_ICON \
        -u $URG \
        "$APP_NAME: $TITLE" \
        "$MESSAGE" &
    
    # Increment counter
    COUNT=$((COUNT + 1))
    
    # Show progress every 10 notifications
    if [ $((COUNT % 10)) -eq 0 ]; then
        echo "  Sent $COUNT/$TOTAL notifications..."
    fi
    
    # Tiny delay to prevent complete system freeze
    # Adjust this value: smaller = faster spam, larger = slower spam
    sleep 0.01
done

# Wait for all background notifications to complete
wait

echo ""
echo "Spam test complete!"
echo "============================================================="
echo "Statistics:"
echo "  Total notifications sent: $TOTAL"
echo "  Apps simulated: ${#APPS[@]}"
echo "  Message variations: ${#MESSAGES[@]}"
echo "  Time taken: ~$(($TOTAL / 100)) seconds"
echo ""
echo "Check your notification center - it should be FULL!"
echo "Tip: You may want to clear all notifications after this test"
echo ""