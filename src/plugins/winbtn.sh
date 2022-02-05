#!/usr/bin/env bash

_PLUGIN_TITLE="Window Buttons"
_PLUGIN_DESCRIPTION="Modify window button layout\nUse with caution: modifications are generally unsupported in Pantheon, and some apps may choose not to listen to this option."
_PLUGIN_OPTIONS=(
    "layout;l;Set which layout to use (default: default). Passing nothing or an incorrect value will list possible values"
    "reset;;Resets to default layout (same as '--layout default')"
)

layout=""

function main() {
    [[ $reset == "true" ]] && layout="default"

    case ${layout,,} in
        "default"|"elementary"|"pantheon"|"sodalite")
            reset_layout
            ;;
        "classic"|"cinnamon"|"kde"|"windows"|"xfce")
            set_layout ":minimize,maximize,close" "menu:minimize,maximize,close"
            ;;
        "fruity"|"macos"|"unity")
            set_layout "close,minimize,maximize:" "close,minimize,maximize:menu"
            ;;
        "minimal"|"gnome")
            set_layout ":close" ":menu,close"
            ;;
        "ninja"|"none")
            set_layout ":" ":menu"
            ;;
        *)
            die_message="Invalid (or missing) --layout option, choose either:\n"
            die_message+=" - default: default layout for Pantheon\n"
            die_message+=" - classic: layout used on Windows, KDE, Cinnamon, Xfce...\n"
            die_message+=" - fruity: layout used on macOS and Unity\n"
            die_message+=" - minimal: layout used on GNOME\n"
            die_message+=" - ninja: buttons be gone!"

            die $die_message
            ;;
    esac
}

function set_layout() {
    wm_layout="$1"
    gnome_layout="$2"
    say "Setting button layout to '$gnome_layout'..."

    gsettings set org.gnome.desktop.wm.preferences button-layout $wm_layout
    gsettings set org.pantheon.desktop.gala.appearance button-layout $wm_layout

    # TODO: Don't clobber any user changes to this value
    gsettings set org.gnome.settings-daemon.plugins.xsettings overrides "{'Gtk/DialogsUseHeader': <0>, 'Gtk/EnablePrimaryPaste': <0>, 'Gtk/ShellShowsAppMenu': <0>, 'Gtk/DecorationLayout': <'$gnome_layout'>,'Gtk/ShowUnicodeMenu': <0>}"
}

function reset_layout() {
    say "Resetting button layout..."

    gsettings reset org.gnome.desktop.wm.preferences button-layout
    gsettings reset org.pantheon.desktop.gala.appearance button-layout
    gsettings reset org.gnome.settings-daemon.plugins.xsettings overrides
}
