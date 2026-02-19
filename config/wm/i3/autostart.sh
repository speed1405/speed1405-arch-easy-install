#!/bin/bash
# i3 autostart script
# Arch Linux Easy Installer

# Function to check if process is running
is_running() {
    pgrep -x "$1" > /dev/null
}

# Start notification daemon
is_running dunst || dunst &

# Start compositor for transparency and effects
is_running picom || picom --config ~/.config/picom/picom.conf -b &

# Set wallpaper
if [ -f ~/.config/wallpaper.jpg ]; then
    feh --bg-scale ~/.config/wallpaper.jpg &
else
    # Use a solid color if no wallpaper
    xsetroot -solid "#282828" &
fi

# Start network manager applet
is_running nm-applet || nm-applet &

# Start volume icon in system tray
is_running volumeicon || volumeicon &

# Start clipboard manager
is_running parcellite || parcellite &

# Start policy kit authentication agent
is_running polkit-gnome-authentication-agent-1 || /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &

# Start screen locker
xss-lock --transfer-sleep-lock -- i3lock-fancy --nofork &

# Start unclutter to hide mouse cursor after timeout
is_running unclutter || unclutter --timeout 3 &

# Set keyboard repeat rate
xset r rate 300 50

# Start redshift for eye comfort (optional)
# is_running redshift || redshift-gtk &

# Set GTK theme
export GTK_THEME=Arc-Dark

# Set icon theme
export GTK_ICON_THEME=Papirus-Dark

# Set cursor theme
export XCURSOR_THEME=Adwaita
export XCURSOR_SIZE=24

# Update MIME associations
xdg-mime default thunar.desktop inode/directory

# Start flameshot for screenshots (optional alternative to maim)
# is_running flameshot || flameshot &

# Start blueman applet for bluetooth
is_running blueman-applet || blueman-applet &

echo "i3 autostart complete"
