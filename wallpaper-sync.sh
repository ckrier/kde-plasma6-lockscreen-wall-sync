#!/usr/bin/env bash

# Script to synchronize desktop wallpaper with the lockscreen wallpaper on KDE Plasma 6. 
# This script tries to take advantage of common user lifecycle behaviors when using a computer and follows
# this set of steps:
#
# When the computer is unlocked:
# 1. Change desktop wallpaper to current lockscreen wallpaper (based on the state file)
# 2. Pick the next lockscreen wallpaper
# 3. Store the new wallpaper in the state file for later use
# 4. Set the lockscreen wallpaper to new wallpaper. Activated the next time the screen is locked.
#
# This gives the illusion that the wallpaper is changing every time the screen is locked. It also keeps
# both desktop. This script is managed by a systemd service and monitors dbus locking events to trigger
# the above steps.

set -euo pipefail

# Debounce time to prevent processing duplicate unlock events
DEBOUNCE_SECONDS=2

# Location of the pool of wallpapers the user wants to shuffle through
WALLPAPER_DIR="/path/to/your/wallpapers"

# Location of the screen locker configuration
LOCKER_CFG="$HOME/path/to/your/kscreenlockerrc"

# Location to store the state file used to synchronize wallpapers
STATE_FILE="$HOME/path/to/your/statefile"

# Protect against rapid mutation of the wallaper by dedouncing. Sometimes multiple events can be processed
# by the event bus that trigger mulitple wallpaper changes. Multiple changes cause the state file to become
# desynchronized so the lock screen and desktop wallpaper do not show the same image.
should_update_wallpaper() {
    [[ ! -f "$STATE_FILE" ]] && return 0

    local now last
    now=$(date +%s)
    last=$(stat -c %Y "$STATE_FILE")

    (( now - last >= DEBOUNCE_SECONDS ))
}

# Randomly select the next wallpaper to use from the configured directory
pick_next_wallpaper() {
  find "$WALLPAPER_DIR" -type f \( \
    -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \
  \) | shuf -n 1
}

# Write the wallpaper to the lockscreen configuration
set_lock_wallpaper() {
  kwriteconfig6 \
    --file "$LOCKER_CFG" \
    --group Greeter \
    --group Wallpaper \
    --group org.kde.image \
    --group General \
    --key Image "$1"
}

# Write the wallpaper to the desktop configuration. Applies to all monitors.
set_desktop_wallpaper() {
  local img="$1"

  qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
var all = desktops();
for (var i = 0; i < all.length; i++) {
  var d = all[i];
  d.wallpaperPlugin = 'org.kde.image';
  d.currentConfigGroup = ['Wallpaper','org.kde.image','General'];
  d.writeConfig('Image', '$img');
}
"
}

# Monitor for dbus lockscreen events and perform the following:
# 1. Change desktop wallpaper to current lockscreen wallpaper (based on state file)
# 2. Pick the next lockscreen wallpaper
# 3. Store the new wallpaper in a state file for later use
# 4. Set the lockscreen wallpaper to new wallpaper.
dbus-monitor --session "interface='org.freedesktop.ScreenSaver'" |
while read -r line; do
  # When unlocked run
  if [[ "$line" == *"boolean false"* ]]; then
    if ! should_update_wallpaper; then
        continue
    fi

    # Update desktop wallpaper after unlock
    CURRENT_URI="$(cat "$STATE_FILE")"
    set_desktop_wallpaper "$CURRENT_URI"

    # Prepare lock screen for next time
    NEXT_IMG="$(pick_next_wallpaper)" || continue
    NEXT_URI="file://$NEXT_IMG"

    echo "$NEXT_URI" > "$STATE_FILE"
    set_lock_wallpaper "$NEXT_URI"
  fi

done
