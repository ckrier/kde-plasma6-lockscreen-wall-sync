# KDE Plasma6 Lockscreen Wall Sync

## Description

The wallpaper experience on KDE Plasma6 is highly disjointed. There are 3 different places wallpapers are managed and they are disparate systems that do not share a common configuration:

- Plasma Desktop Wallpaper
- Screen Locker Wallpaper (Lock Screen)
- SDDM Wallpaper (Login Screen)

This script attempts to handle synchronizing the desktop and lockscreen wallpapers to gain a more cohesive wallpaper experience. SDDM provides additional challenges that are not handled as a part of this project. Particularly, it requires root privileges to access and change wallpapers without a reliable/secure way to make updates.

## Behavior

This script runs in the background managed by a `systemd` service. It listens for “screen unlocked” `dbus` events and performs the following steps when the computer is unlocked:

1. Change desktop wallpaper to current lockscreen wallpaper (based on the state file)
2. Pick the next lockscreen wallpaper
3. Store the new wallpaper in the state file for later use
4. Set the lockscreen wallpaper to the new wallpaper (activated the next time the screen is locked).

This process creates the illusion the wallpaper is updated every time the screen is locked and maintains the synchronization between the desktop and the lock screen.

## How to use

To use this script, the following steps are required.

1. Clone this repository.
2. Setup/change the variables in the script
    1. `WALLPAPER_DIR` to the directory you store your wallpapers
    2. `LOCKER_CFG` to the location of the `kscreenlockerrc` file. Usually located at `$HOME/.config/kscreenlockerrc`
    3. `STATE_FILE` to the location you want to store your state file. Can be anywhere your user has write access. Even in this repo. 
    4. `DEBOUNCE_SECONDS` to the number seconds you want the script to ignore updates. Likely unnecessary to change this for most people. However it can be useful to tweak if you are running on a slower system that needs more time to process.
3. Setup up the `systemd` `ExecStart` location.
4. Configure the `systemd` to run your `service` file.
    
    ```bash
    systemctl --user daemon-reload
    systemctl --user enable --now wallpaper-sync.service
    ```
    

## Known Issues

- On rapid unlock/re-lock attempts can prevent the system from locking. This seems to be a race condition with the Wayland compositor that results in cancellation of the lock. It is not a problem during normal use of the computer, but can be triggered by spamming lockscreen after unlocking.
- The application of the desktop wallpaper after unlocking is not immediate. There is a brief “fade” transition that occurs as Plasma applies the new wallpaper.
- Has very rarely stalled my computer indefinitely on a black screen when under development. Unclear why, but it is fixed by a reboot. Hasn’t happened in awhile, but a warning worth pointing out.