#!/usr/bin/env bash

_PLUGIN_TITLE="GNOME Control Center shim"
_PLUGIN_DESCRIPTION="Shim to redirect requests for GNOME Control Center to Switchboard"
_PLUGIN_OPTIONS=(
    "setting;s;Panel for GNOME Control Center"
)
_PLUGIN_HIDDEN="true"

function launch_setting() {
    if [[ -z $1 ]]; then
        io.elementary.switchboard
    else
        xdg-open settings://$1
    fi
}

function main() {
    if { [[ $setting == "true" ]] || [[ $options == "" ]]; }; then
        die_message="No option specified for --setting, choose either:\n"
        die_message+=" - applications:     Switchboard ➔ Applications ➔ Permissions\n"
        die_message+=" - backgrounds:      Switchboard ➔ Desktop ➔ Wallpaper\n"
        die_message+=" - bluetooth         Switchboard ➔ Bluetooth\n"
        die_message+=" - color             Colour Profile Viewer\n"
        die_message+=" - datetime          Switchboard ➔ Date & Time\n"
        die_message+=" - display           Switchboard ➔ Displays\n"
        die_message+=" - info-overview     Switchboard ➔ System\n"
        die_message+=" - keyboard          Switchboard ➔ Keyboard\n"
        die_message+=" - mouse             Switchboard ➔ Mouse & Touchpad\n"
        die_message+=" - network           Switchboard ➔ Network\n"
        die_message+=" - notifications     Switchboard ➔ Notifications\n"
        die_message+=" - power             Switchboard ➔ Power\n"
        die_message+=" - printers          Switchboard ➔ Printers\n"
        die_message+=" - privacy           Switchboard ➔ Security & Privacy\n"
        die_message+=" - region            Switchboard ➔ Language & Region\n"
        die_message+=" - search            (No shim)\n"
        die_message+=" - sound             Switchboard ➔ Sound\n"
        die_message+=" - universal-access  Switchboard ➔ Universal Access\n"
        die_message+=" - user-accounts     Switchboard ➔ User Accounts\n"
        die_message+=" - wacom             Switchboard ➔ Wacom"

        die "$die_message"
    fi

    if [[ $setting == "" ]] && [[ $options != "" ]]; then
        setting="$options"
    fi

    case $setting in
        applications) launch_setting applications/permissions ;;
        backgrounds) launch_setting desktop/wallpaper ;;
        bluetooth) launch_setting network/bluetooth ;;
        color) gcm-viewer ;;
        datetime) launch_setting date ;;
        default) launch_setting ;;
        display) launch_setting display ;;
        info-overview) launch_setting about ;;
        keyboard) launch_setting input/keyboard ;;
        mouse) launch_setting input/pointer ;;
        network|wifi) launch_setting network ;;
        notifications) launch_setting notifications ;;
        power) launch_setting power ;;
        printers) launch_setting printer ;;
        privacy) launch_setting privacy ;;
        region) launch_setting language ;;
        sound) launch_setting sound ;;
        universal-access) launch_setting universal-access ;;
        user-accounts) launch_setting accounts ;;
        wacom) launch_setting input/pointing/stylus ;;
        *|search) die "No shim available for '$setting'" ;;
	esac
}

[[ $is_invoked != "true" ]] && rocks.sodalite.hacks $0 $@
