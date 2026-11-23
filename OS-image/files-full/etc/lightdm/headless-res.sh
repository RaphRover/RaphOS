#!/bin/sh

# Headless only: with a monitor on HDMI, xorg.conf.d PreferredMode applies instead.
# Give HDMI-1 a real mode, not just a framebuffer size: OGRE (rviz2) segfaults
# when X reports no video modes.
if xrandr | grep -q '^HDMI-1 disconnected'; then
    xrandr --newmode 1280x800_60.00 83.50 1280 1352 1480 1680 800 803 809 831 -hsync +vsync
    xrandr --addmode HDMI-1 1280x800_60.00
    xrandr --output HDMI-1 --mode 1280x800_60.00
fi

# x0vncserver reads the screen size only at startup, so restart it after any resize.
# Only if the user hasn't disabled it: `restart` ignores enablement and would
# otherwise bring it back regardless.
if systemctl is-enabled --quiet x0vncserver.service; then
    systemctl --no-block restart x0vncserver.service
fi

exit 0
