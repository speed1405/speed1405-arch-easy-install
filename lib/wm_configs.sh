#!/bin/bash
#
# Window Manager Configuration Manager
# Handles installation of WM configs for i3, OpenBox, Sway, etc.
#

# Configuration source directory
WM_CONFIG_SRC="$SCRIPT_DIR/config/wm"

# Install window manager configuration
install_wm_config() {
    local wm=$1
    
    log_info "Installing $wm configuration..."
    
    case $wm in
        "i3")
            install_i3_config
            ;;
        "openbox")
            install_openbox_config
            ;;
        "sway")
            install_sway_config
            ;;
        "awesome")
            install_awesome_config
            ;;
        "bspwm")
            install_bspwm_config
            ;;
        *)
            log_warn "No configuration available for $wm"
            return 1
            ;;
    esac
}

# Install i3 configuration
install_i3_config() {
    log_info "Setting up i3 configuration..."
    
    # Create config directories
    mkdir -p /mnt/home/$USERNAME/.config/i3
    mkdir -p /mnt/home/$USERNAME/.config/i3blocks
    mkdir -p /mnt/home/$USERNAME/.config/i3blocks/scripts
    mkdir -p /mnt/home/$USERNAME/.config/picom
    mkdir -p /mnt/home/$USERNAME/.config/dunst
    mkdir -p /mnt/home/$USERNAME/.config/rofi
    
    # Copy configuration files
    if [[ -d "$WM_CONFIG_SRC/i3" ]]; then
        cp "$WM_CONFIG_SRC/i3/config" /mnt/home/$USERNAME/.config/i3/config
        cp "$WM_CONFIG_SRC/i3/i3blocks.conf" /mnt/home/$USERNAME/.config/i3blocks/config
        cp "$WM_CONFIG_SRC/i3/picom.conf" /mnt/home/$USERNAME/.config/picom/picom.conf
        cp "$WM_CONFIG_SRC/i3/dunstrc" /mnt/home/$USERNAME/.config/dunst/dunstrc
        cp "$WM_CONFIG_SRC/i3/rofi-theme.rasi" /mnt/home/$USERNAME/.config/rofi/config.rasi
        cp "$WM_CONFIG_SRC/i3/autostart.sh" /mnt/home/$USERNAME/.config/i3/autostart.sh
        chmod +x /mnt/home/$USERNAME/.config/i3/autostart.sh
        
        # Copy i3blocks scripts
        if [[ -d "$WM_CONFIG_SRC/i3/scripts" ]]; then
            cp "$WM_CONFIG_SRC/i3/scripts/"* /mnt/home/$USERNAME/.config/i3blocks/scripts/
            chmod +x /mnt/home/$USERNAME/.config/i3blocks/scripts/*
        fi
        
        log_info "i3 configuration files copied"
    else
        log_warn "i3 config source not found"
    fi
    
    # Set ownership
    arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config"
    
    # Install additional i3 packages
    arch-chroot /mnt pacman -S --noconfirm --needed \
        i3-gaps \
        i3blocks \
        i3lock-fancy \
        dunst \
        rofi \
        picom \
        feh \
        maim \
        xclip \
        xdotool \
        xss-lock \
        dex \
        brightnessctl \
        playerctl \
        network-manager-applet \
        volumeicon \
        parcellite \
        polkit-gnome \
        unclutter \
        arc-gtk-theme \
        papirus-icon-theme \
        ttf-hack \
        ttf-jetbrains-mono
    
    # Download a nice wallpaper
    dialog_safe --infobox "Downloading wallpaper..." 3 40
    curl -L -o /mnt/home/$USERNAME/.config/wallpaper.jpg \
        "https://images.unsplash.com/photo-1550684848-fac1c5b4e853?w=1920&q=80" 2>/dev/null || \
        cp /mnt/usr/share/backgrounds/default.png /mnt/home/$USERNAME/.config/wallpaper.jpg 2>/dev/null || true
    
    arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/.config/wallpaper.jpg" 2>/dev/null || true
    
    log_info "i3 configuration complete"
}

# Install OpenBox configuration
install_openbox_config() {
    log_info "Setting up OpenBox configuration..."
    
    # Create config directories
    mkdir -p /mnt/home/$USERNAME/.config/openbox
    mkdir -p /mnt/home/$USERNAME/.config/tint2
    mkdir -p /mnt/home/$USERNAME/.config/picom
    mkdir -p /mnt/home/$USERNAME/.config/dunst
    mkdir -p /mnt/home/$USERNAME/.config/rofi
    
    # Copy configuration files
    if [[ -d "$WM_CONFIG_SRC/openbox" ]]; then
        cp "$WM_CONFIG_SRC/openbox/rc.xml" /mnt/home/$USERNAME/.config/openbox/rc.xml
        cp "$WM_CONFIG_SRC/openbox/menu.xml" /mnt/home/$USERNAME/.config/openbox/menu.xml
        cp "$WM_CONFIG_SRC/openbox/autostart" /mnt/home/$USERNAME/.config/openbox/autostart
        cp "$WM_CONFIG_SRC/openbox/environment" /mnt/home/$USERNAME/.config/openbox/environment
        cp "$WM_CONFIG_SRC/openbox/tint2rc" /mnt/home/$USERNAME/.config/tint2/tint2rc
        
        # Make autostart executable
        chmod +x /mnt/home/$USERNAME/.config/openbox/autostart
        
        log_info "OpenBox configuration files copied"
    else
        log_warn "OpenBox config source not found"
    fi
    
    # Copy shared config files
    if [[ -f "$WM_CONFIG_SRC/i3/picom.conf" ]]; then
        cp "$WM_CONFIG_SRC/i3/picom.conf" /mnt/home/$USERNAME/.config/picom/picom.conf
    fi
    
    if [[ -f "$WM_CONFIG_SRC/i3/dunstrc" ]]; then
        cp "$WM_CONFIG_SRC/i3/dunstrc" /mnt/home/$USERNAME/.config/dunst/dunstrc
    fi
    
    if [[ -f "$WM_CONFIG_SRC/i3/rofi-theme.rasi" ]]; then
        cp "$WM_CONFIG_SRC/i3/rofi-theme.rasi" /mnt/home/$USERNAME/.config/rofi/config.rasi
    fi
    
    # Set ownership
    arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config"
    
    # Install additional OpenBox packages
    arch-chroot /mnt pacman -S --noconfirm --needed \
        obconf \
        tint2 \
        dunst \
        rofi \
        picom \
        feh \
        maim \
        xclip \
        xautolock \
        i3lock-fancy \
        jgmenu \
        obmenu-generator \
        network-manager-applet \
        volumeicon \
        parcellite \
        polkit-gnome \
        unclutter \
        arc-gtk-theme \
        papirus-icon-theme \
        numlockx \
        galculator \
        gucharmap \
        viewnior
    
    # Generate OpenBox menu
    arch-chroot /mnt obmenu-generator -p -i 2>/dev/null || true
    
    # Download wallpaper
    dialog_safe --infobox "Downloading wallpaper..." 3 40
    curl -L -o /mnt/home/$USERNAME/.config/wallpaper.jpg \
        "https://images.unsplash.com/photo-1550684848-fac1c5b4e853?w=1920&q=80" 2>/dev/null || \
        cp /mnt/usr/share/backgrounds/default.png /mnt/home/$USERNAME/.config/wallpaper.jpg 2>/dev/null || true
    
    arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/.config/wallpaper.jpg" 2>/dev/null || true
    
    log_info "OpenBox configuration complete"
}

# Install Sway configuration
install_sway_config() {
    log_info "Setting up Sway configuration..."
    
    # Create config directories
    mkdir -p /mnt/home/$USERNAME/.config/sway
    mkdir -p /mnt/home/$USERNAME/.config/waybar
    mkdir -p /mnt/home/$USERNAME/.config/mako
    mkdir -p /mnt/home/$USERNAME/.config/rofi
    
    # Copy i3 config as base for Sway (they're mostly compatible)
    if [[ -f "$WM_CONFIG_SRC/i3/config" ]]; then
        cp "$WM_CONFIG_SRC/i3/config" /mnt/home/$USERNAME/.config/sway/config
        
        # Modify for Wayland/Sway
        # Replace X11-specific commands with Wayland equivalents
        sed -i 's/i3lock-fancy/swaylock-fancy/g' /mnt/home/$USERNAME/.config/sway/config
        sed -i 's/maim/grim/g' /mnt/home/$USERNAME/.config/sway/config
        sed -i 's/i3bar/waybar/g' /mnt/home/$USERNAME/.config/sway/config
        sed -i 's/i3blocks/waybar/g' /mnt/home/$USERNAME/.config/sway/config
        
        log_info "Sway configuration created from i3 template"
    fi
    
    # Set ownership
    arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config"
    
    # Install Sway-specific packages
    arch-chroot /mnt pacman -S --noconfirm --needed \
        swaylock-fancy \
        waybar \
        mako \
        wofi \
        wl-clipboard \
        grim \
        slurp \
        wf-recorder \
        brightnessctl \
        playerctl \
        polkit
    
    log_info "Sway configuration complete"
}

# Install AwesomeWM configuration
install_awesome_config() {
    log_info "Setting up AwesomeWM configuration..."
    
    # Create config directory
    mkdir -p /mnt/home/$USERNAME/.config/awesome
    
    # Awesome uses Lua for configuration, we'll create a basic one
    cat > /mnt/home/$USERNAME/.config/awesome/rc.lua <<'EOF'
-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")

-- Error handling
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Theme
beautiful.init(gears.filesystem.get_themes_dir() .. "default/theme.lua")

-- Terminal and editor
terminal = "alacritty"
editor = os.getenv("EDITOR") or "nano"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey
modkey = "Mod4"

-- Table of layouts
awful.layout.layouts = {
    awful.layout.suit.floating,
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,
    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    awful.layout.suit.spiral,
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    awful.layout.suit.max.fullscreen,
    awful.layout.suit.magnifier,
    awful.layout.suit.corner.nw,
}

-- Menu
myawesomemenu = {
   { "hotkeys", function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
   { "manual", terminal .. " -e man awesome" },
   { "edit config", editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "quit", function() awesome.quit() end },
}

mymainmenu = awful.menu({ items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
                                    { "open terminal", terminal }
                                  }
                        })

mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })

-- Menubar configuration
menubar.utils.terminal = terminal

-- Keyboard map indicator and switcher
mykeyboardlayout = awful.widget.keyboardlayout()

-- Create a textclock widget
mytextclock = wibox.widget.textclock()

-- Create a wibox for each screen
awful.screen.connect_for_each_screen(function(s)
    -- Wallpaper
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        if type(wallpaper) == "function" then
            wallpaper = wallpaper(s)
        end
        gears.wallpaper.maximized(wallpaper, s, true)
    end

    -- Tags
    awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }, s, awful.layout.layouts[1])

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()

    -- Create an imagebox widget which will contain an icon indicating which layout we're using
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
                           awful.button({ }, 1, function () awful.layout.inc( 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(-1) end),
                           awful.button({ }, 4, function () awful.layout.inc( 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(-1) end)))

    -- Create a taglist widget
    s.mytaglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.all,
        buttons = {
            awful.button({ }, 1, function(t) t:view_only() end),
            awful.button({ modkey }, 1, function(t)
                                            if client.focus then
                                                client.focus:move_to_tag(t)
                                            end
                                        end),
            awful.button({ }, 3, awful.tag.viewtoggle),
            awful.button({ modkey }, 3, function(t)
                                            if client.focus then
                                                client.focus:toggle_tag(t)
                                            end
                                        end),
            awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
            awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end),
        }
    }

    -- Create a tasklist widget
    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = {
            awful.button({ }, 1, function (c)
                c:activate { context = "tasklist", action = "toggle_minimization" }
            end),
            awful.button({ }, 3, function() awful.menu.client_list { theme = { width = 250 } } end),
            awful.button({ }, 4, function() awful.client.focus.byidx( 1) end),
            awful.button({ }, 5, function() awful.client.focus.byidx(-1) end),
        }
    }

    -- Create the wibox
    s.mywibox = awful.wibar({ position = "top", screen = s })

    -- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            mylauncher,
            s.mytaglist,
            s.mypromptbox,
        },
        s.mytasklist, -- Middle widget
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            mykeyboardlayout,
            wibox.widget.systray(),
            mytextclock,
            s.mylayoutbox,
        },
    }
end)

-- Mouse bindings
root.buttons(gears.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))

-- Key bindings
globalkeys = gears.table.join(
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore,
              {description = "go back", group = "tag"}),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
        end,
        {description = "focus next by index", group = "client"}
    ),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
        end,
        {description = "focus previous by index", group = "client"}
    ),
    awful.key({ modkey,           }, "w", function () mymainmenu:show() end,
              {description = "show main menu", group = "awesome"}),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end,
              {description = "focus the previous screen", group = "screen"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end,
        {description = "go back", group = "client"}),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)          end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)          end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "increase the number of master clients", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "decrease the number of master clients", group = "layout"}),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1, nil, true)    end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1, nil, true)    end,
              {description = "decrease the number of columns", group = "layout"}),
    awful.key({ modkey,           }, "space", function () awful.layout.inc( 1)                end,
              {description = "select next", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(-1)                end,
              {description = "select previous", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  if c then
                    c:activate { raise = true, context = "key.unminimize" }
                  end
              end,
              {description = "restore minimized", group = "client"}),

    -- Prompt
    awful.key({ modkey },            "r",     function () awful.screen.focused().mypromptbox:run() end,
              {description = "run prompt", group = "launcher"}),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run {
                    prompt       = "Run Lua code: ",
                    textbox      = awful.screen.focused().mypromptbox.widget,
                    exe_callback = awful.util.eval,
                    history_path = awful.util.get_cache_dir() .. "/history_eval"
                  }
              end,
              {description = "lua execute prompt", group = "awesome"}),
    -- Menubar
    awful.key({ modkey }, "p", function() menubar.show() end,
              {description = "show the menubar", group = "launcher"})
)

clientkeys = gears.table.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey,           }, "n",
        function (c)
            c.minimized = true
        end ,
        {description = "minimize", group = "client"}),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "(un)maximize", group = "client"}),
    awful.key({ modkey, "Control" }, "m",
        function (c)
            c.maximized_vertical = not c.maximized_vertical
            c:raise()
        end ,
        {description = "(un)maximize vertically", group = "client"}),
    awful.key({ modkey, "Shift"   }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c:raise()
        end ,
        {description = "(un)maximize horizontally", group = "client"})
)

-- Bind all key numbers to tags
for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end,
                  {description = "view tag #"..i, group = "tag"}),
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  {description = "move focused client to tag #"..i, group = "tag"}),
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end,
                  {description = "toggle focused client on tag #"..i, group = "tag"})
    )
end

clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c)
        c:activate { context = "mouse_click" }
    end),
    awful.button({ modkey }, 1, function (c)
        c:activate { context = "mouse_click", action = "mouse_move"  }
    end),
    awful.button({ modkey }, 3, function (c)
        c:activate { context = "mouse_click", action = "mouse_resize"}
    end)
)

-- Set keys
root.keys(globalkeys)

-- Rules
awful.rules.rules = {
    -- All clients will match this rule
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     screen = awful.screen.preferred,
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen
     }
    },

    -- Floating clients
    { rule_any = {
        instance = {
          "DTA",  -- Firefox addon DownThemAll
          "copyq",  -- Includes session name in class
          "pinentry",
        },
        class = {
          "Arandr",
          "Blueman-manager",
          "Gpick",
          "Kruler",
          "MessageWin",  -- kalarm
          "Sxiv",
          "Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size
          "Wpa_gui",
          "veromix",
          "xtightvncviewer"},

        -- Note that the name property shown in xprop might be set slightly after creation of the client
        -- and the name shown there might not match defined rules here
        name = {
          "Event Tester",  -- xev
        },
        role = {
          "AlarmWindow",  -- Thunderbird's calendar
          "ConfigManager",  -- Thunderbird's about:config
          "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools
        }
      }, properties = { floating = true }},

    -- Add titlebars to normal clients and dialogs
    { rule_any = {type = { "normal", "dialog" }
      }, properties = { titlebars_enabled = true }
    },

    -- Set Firefox to always map on the tag named "2" on screen 1
    -- { rule = { class = "Firefox" },
    --   properties = { screen = 1, tag = "2" } },
}

-- Signals
client.connect_signal("manage", function (c)
    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        awful.placement.no_offscreen(c)
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules
client.connect_signal("request::titlebars", function(c)
    -- buttons for the titlebar
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            c:activate { context = "titlebar", action = "mouse_move"  }
        end),
        awful.button({ }, 3, function()
            c:activate { context = "titlebar", action = "mouse_resize"}
        end)
    )

    awful.titlebar(c) : setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton   (c),
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)

-- Enable sloppy focus, so that focus follows mouse
client.connect_signal("mouse::enter", function(c)
    c:activate { context = "mouse_enter", raise = false }
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
EOF
    
    # Set ownership
    arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config"
    
    # Install Awesome packages
    arch-chroot /mnt pacman -S --noconfirm --needed \
        awesome \
        vicious \
        lua \
        lain
    
    log_info "AwesomeWM configuration complete"
}

# Install BSPWM configuration
install_bspwm_config() {
    log_info "Setting up BSPWM configuration..."
    
    # Create config directories
    mkdir -p /mnt/home/$USERNAME/.config/bspwm
    mkdir -p /mnt/home/$USERNAME/.config/sxhkd
    mkdir -p /mnt/home/$USERNAME/.config/polybar
    mkdir -p /mnt/home/$USERNAME/.config/picom
    
    # Create BSPWM config
    cat > /mnt/home/$USERNAME/.config/bspwm/bspwmrc <<'EOF'
#!/bin/sh

# Load config from Xresources
xrdb -merge ~/.Xresources

# Set keyboard repeat rate
xset r rate 300 50

# Start sxhkd
sxhkd &

# Set wallpaper
feh --bg-scale ~/.config/wallpaper.jpg &

# Start compositor
picom --config ~/.config/picom/picom.conf -b &

# Start notification daemon
dunst &

# Start polybar
~/.config/polybar/launch.sh &

# Start system tray apps
nm-applet &
volumeicon &
parcellite &

# Configure monitors
bspc monitor -d I II III IV V VI VII VIII IX X

# Window settings
bspc config border_width         2
bspc config window_gap          12
bspc config split_ratio          0.52
bspc config borderless_monocle   true
bspc config gapless_monocle      true
bspc config focus_follows_pointer true

# Colors (Gruvbox)
bspc config normal_border_color   "#3c3836"
bspc config active_border_color   "#458588"
bspc config focused_border_color  "#458588"
bspc config presel_feedback_color "#cc241d"

# Rules
bspc rule -a Gimp desktop='^8' state=floating follow=on
bspc rule -a Chromium desktop='^2'
bspc rule -a mplayer2 state=floating
bspc rule -a Kupfer.py focus=on
bspc rule -a Screenkey manage=off
bspc rule -a Pavucontrol state=floating
bspc rule -a Nm-connection-editor state=floating
EOF
    
    # Create sxhkd config
    cat > /mnt/home/$USERNAME/.config/sxhkd/sxhkdrc <<'EOF'
# Terminal
super + Return
    alacritty

# Program launcher
super + d
    rofi -show drun -config ~/.config/rofi/config.rasi

super + @space
    rofi -show run -config ~/.config/rofi/config.rasi

# Reload bspwm
super + shift + r
    bspc wm -r

# Restart sxhkd
super + Escape
    pkill -USR1 -x sxhkd

# Quit bspwm
super + shift + e
    bspc quit

# Close window
super + q
    bspc node -c

# Kill window
super + shift + q
    bspc node -k

# Set window state
super + t
    bspc node -t tiled

super + shift + t
    bspc node -t floating

super + f
    bspc node -t fullscreen

# Focus window
super + {h,j,k,l}
    bspc node -f {west,south,north,east}

# Move window
super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

# Resize window
super + alt + {h,j,k,l}
    bspc node -z {left -20 0,bottom 0 20,top 0 -20,right 20 0}

super + alt + shift + {h,j,k,l}
    bspc node -z {right -20 0,top 0 20,bottom 0 -20,left 20 0}

# Desktop navigation
super + {1-9,0}
    bspc desktop -f '^{1-9,10}'

# Move window to desktop
super + shift + {1-9,0}
    bspc node -d '^{1-9,10}'

# Preselect direction
super + ctrl + {h,j,k,l}
    bspc node -p {west,south,north,east}

# Cancel preselection
super + ctrl + space
    bspc node -p cancel

# Expand/contract window
super + ctrl + {1-9}
    bspc node -r 0.{1-9}

# Volume keys
XF86AudioRaiseVolume
    pactl set-sink-volume @DEFAULT_SINK@ +5%

XF86AudioLowerVolume
    pactl set-sink-volume @DEFAULT_SINK@ -5%

XF86AudioMute
    pactl set-sink-mute @DEFAULT_SINK@ toggle

# Brightness keys
XF86MonBrightnessUp
    brightnessctl set +5%

XF86MonBrightnessDown
    brightnessctl set 5%-

# Screenshot
Print
    maim "$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"

shift + Print
    maim --select "$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"

super + Print
    maim --window $(xdotool getactivewindow) "$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"

# Lock screen
super + l
    i3lock-fancy
EOF
    
    # Make scripts executable
    chmod +x /mnt/home/$USERNAME/.config/bspwm/bspwmrc
    chmod +x /mnt/home/$USERNAME/.config/sxhkd/sxhkdrc
    
    # Set ownership
    arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config"
    
    # Install BSPWM packages
    arch-chroot /mnt pacman -S --noconfirm --needed \
        bspwm \
        sxhkd \
        polybar \
        picom \
        feh \
        dunst \
        rofi \
        maim \
        xclip \
        xdotool \
        i3lock-fancy \
        brightnessctl \
        playerctl \
        network-manager-applet \
        volumeicon \
        parcellite
    
    log_info "BSPWM configuration complete"
}

# Display keybinding cheat sheet
show_keybinding_cheatsheet() {
    local wm=$1
    
    case $wm in
        "i3")
            dialog_safe --msgbox "i3 Keybindings Cheat Sheet:\n\nMod = Super/Windows key\n\nMod+Enter: Terminal\nMod+D: Application launcher\nMod+Shift+Q: Close window\nMod+Shift+E: Exit menu\nMod+Shift+R: Reload config\nMod+1-0: Switch workspace\nMod+Shift+1-0: Move to workspace\nMod+H/J/K/L: Navigate windows\nMod+Shift+H/J/K/L: Move windows\nMod+F: Fullscreen\nMod+V: Split vertical\nMod+Shift+V: Split horizontal\nMod+S: Stacking layout\nMod+W: Tabbed layout\nMod+E: Toggle split\nMod+R: Resize mode\nMod+Shift+X: Lock screen\n\nYour config is at: ~/.config/i3/config" 25 60
            ;;
        "openbox")
            dialog_safe --msgbox "OpenBox Keybindings Cheat Sheet:\n\nAlt+F1: Menu\nAlt+F2: Run dialog\nAlt+F3: Application search\nAlt+Tab: Switch windows\nAlt+F4: Close window\nAlt+F5: Minimize\nAlt+F6: Maximize\nAlt+F11: Fullscreen\nAlt+Escape: Exit menu\nCtrl+Alt+T: Terminal\nSuper+E: File manager\nSuper+L: Lock screen\nPrint: Screenshot\n\nRight-click desktop for menu\n\nYour config is at: ~/.config/openbox/rc.xml" 25 60
            ;;
        "awesome")
            dialog_safe --msgbox "AwesomeWM Keybindings Cheat Sheet:\n\nMod = Super/Windows key\n\nMod+Enter: Terminal\nMod+R: Run prompt\nMod+X: Lua prompt\nMod+P: Menubar\nMod+W: Main menu\nMod+J/K: Focus next/previous\nMod+Shift+J/K: Swap windows\nMod+H/L: Resize master\nMod+Space: Next layout\nMod+Shift+Space: Previous layout\nMod+Shift+Q: Close window\nMod+Ctrl+R: Restart Awesome\nMod+Shift+Q: Quit Awesome\nMod+1-9: Switch tag\nMod+Shift+1-9: Move to tag\n\nYour config is at: ~/.config/awesome/rc.lua" 25 60
            ;;
        "bspwm")
            dialog_safe --msgbox "BSPWM Keybindings Cheat Sheet:\n\nSuper = Mod key\n\nSuper+Enter: Terminal\nSuper+D: Application launcher\nSuper+Space: Run dialog\nSuper+Q: Close window\nSuper+Shift+Q: Kill window\nSuper+T: Tiled\nSuper+Shift+T: Floating\nSuper+F: Fullscreen\nSuper+H/J/K/L: Focus direction\nSuper+Shift+H/J/K/L: Move direction\nSuper+1-0: Desktop\nSuper+Shift+1-0: Move to desktop\nSuper+Shift+E: Quit BSPWM\nSuper+Shift+R: Reload BSPWM\nSuper+Escape: Reload sxhkd\nSuper+L: Lock screen\nPrint: Screenshot\n\nYour config is at: ~/.config/bspwm/bspwmrc" 25 60
            ;;
    esac
}
