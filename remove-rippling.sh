#!/bin/bash

# Rippling MDM Removal Script for macOS
# This script will uninstall the Rippling agent and all associated components.
# It unloads and removes Rippling LaunchDaemons/LaunchAgents, deletes Rippling files and directories,
# removes any Rippling configuration profiles, and resets custom settings (like login window text).
# Designed to run as root (e.g., via MDM) without any interactive prompts.

# Copied and modified from https://help.swif.ai/en/articles/11014985-clean-uninstallation-of-rippling-from-macos-devices-using-swif

# Exit if not run as root (UID 0)
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

# Unload and remove all Rippling LaunchDaemons (system-wide services)
if [ -d /Library/LaunchDaemons ]; then
    for plist in /Library/LaunchDaemons/com.rippling.*.plist; do
        [ -e "$plist" ] || continue   # skip if no Rippling LaunchDaemons exist
        # Use launchctl bootout to stop the LaunchDaemon in the system domain
        launchctl bootout system "$plist" 2>/dev/null || echo "NOTE: $(basename "$plist") not running or already unloaded"
        # Remove the LaunchDaemon plist file
        rm -f "$plist"
        echo "Removed LaunchDaemon: $(basename "$plist")"
    done
fi

# Unload and remove all Rippling LaunchAgents in /Library (these run in user login sessions)
if [ -d /Library/LaunchAgents ]; then
    for plist in /Library/LaunchAgents/com.rippling.*.plist; do
        [ -e "$plist" ] || continue   # skip if no Rippling LaunchAgents exist
        # Unload the LaunchAgent from each logged-in user session (GUI login)
        for user in $(who | awk '{print $1}' | sort -u); do
            # Skip system accounts or root
            if [[ "$user" == "root" || "$user" == "_mbsetupuser" ]]; then
                continue
            fi
            userID=$(id -u "$user" 2>/dev/null)
            if [ -n "$userID" ]; then
                launchctl bootout gui/"$userID" "$plist" 2>/dev/null
            fi
        done
        # Remove the LaunchAgent plist file
        rm -f "$plist"
        echo "Removed LaunchAgent: $(basename "$plist")"
    done
fi

# Unload and remove any Rippling LaunchAgents in users' home directories (if installed per-user)
for userHome in /Users/*; do
    if [ -d "$userHome/Library/LaunchAgents" ]; then
        for plist in "$userHome/Library/LaunchAgents"/com.rippling.*.plist; do
            [ -e "$plist" ] || continue
            # Determine the user and unload the agent if the user is currently logged in
            userName=$(basename "$userHome")
            userID=$(id -u "$userName" 2>/dev/null)
            if [ -n "$userID" ]; then
                launchctl bootout gui/"$userID" "$plist" 2>/dev/null
            fi
            # Remove the per-user LaunchAgent file
            rm -f "$plist"
            echo "Removed user LaunchAgent: $plist"
        done
    fi
done

# Remove the main Rippling application, if present
if [ -d "/Applications/Rippling.app" ]; then
    rm -rf "/Applications/Rippling.app"
    echo "Removed /Applications/Rippling.app"
fi

# Remove Rippling directories (if they exist)
if [ -d /opt/rippling ]; then
    rm -rf /opt/rippling
    echo "Removed /opt/rippling"
fi
if [ -d /usr/local/rippling ]; then
    rm -rf /usr/local/rippling
    echo "Removed /usr/local/rippling"
fi

# Remove any Chef provisioning data that Rippling might have used
# if [ -d /opt/chef ]; then
#     rm -rf /opt/chef
#     echo "Removed /opt/chef (Chef client)"
# fi
# if [ -d /private/var/chef ]; then
#     rm -rf /private/var/chef
#     echo "Removed /private/var/chef (Chef cookbooks)"
# fi

# Remove Rippling support files under /Library, if any
if [ -d "/Library/Application Support/Rippling" ]; then
    rm -rf "/Library/Application Support/Rippling"
    echo "Removed /Library/Application Support/Rippling"
fi
# Remove any Rippling-related preferences
if ls /Library/Preferences/com.rippling.* &>/dev/null; then
    rm -f /Library/Preferences/com.rippling.*
    echo "Removed /Library/Preferences/com.rippling.* files"
fi

# Remove any configuration profiles associated with Rippling (com.rippling.* profiles)
if profiles -P 2>&1 | grep -q "com.rippling"; then
    # List all profile identifiers containing "com.rippling"
    for profile_id in $(profiles -P | grep "com.rippling" | sed -E 's/.*Identifier: *([^\)]*com.rippling[^,]+).*/\1/'); do
        echo "Removing profile: $profile_id"
        profiles -R -p "$profile_id" 2>/dev/null || echo "NOTE: Failed to remove profile $profile_id (may require manual removal)"
    done
fi

# Reset login window text to blank (clears any message set by Rippling)
# defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "" 2>/dev/null

echo "Rippling removal complete. All Rippling components have been removed."
