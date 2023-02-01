#!/usr/bin/env bash

_PLUGIN_TITLE="Web"
_PLUGIN_DESCRIPTION="Manage installation of Web (Epiphany)"
_PLUGIN_OPTIONS=(
    "install;i;Install Web"
    "uninstall;;Uninstall Web"
)
_PLUGIN_ROOT="true"

function is_flatpak_repo_installed() {
    if [[ $(flatpak remotes --columns=url --show-disabled --system | grep "$1") ]]; then
        echo "true"
    fi
}

function main() {
    has_run="false"

    if [[ $install == "true" ]]; then
        has_run="true"

        [[ $(is_flatpak_repo_installed "https://flatpak.elementary.io/repo/") != "true" ]] && die "Flatpak repo 'AppCenter' not available"
        [[ $(is_flatpak_repo_installed "https://dl.flathub.org/repo/") != "true" ]] && die "Flatpak repo 'Flathub' not available"

        flatpak install --assumeyes --noninteractive --or-update --system flathub org.freedesktop.Platform.GL.default 22.08
        flatpak install --assumeyes --noninteractive --or-update --system appcenter org.gnome.Epiphany stable
    fi

    if [[ $uninstall == "true" ]]; then
        has_run="true"

        flatpak uninstall --assumeyes --noninteractive --system org.gnome.Epiphany
    fi

    if [[ $has_run != "true" ]]; then
        die "No option specified (see --help)"
    fi
}
