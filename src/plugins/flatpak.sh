#!/usr/bin/env bash

_PLUGIN_TITLE="Flatpak helpers (Deprecated)"
_PLUGIN_DESCRIPTION="Various helpers for Flatpak"
_PLUGIN_OPTIONS=(
    "install-epiphany;;Install Epiphany from AppCenter"
)
_PLUGIN_ROOT="true"
_PLUGIN_HIDDEN="true"

function main() {
    if [[ $install_epiphany == "true" ]]; then
        has_run="true"
        invoke_install_epiphany
    fi

    if [[ $has_run != "true" ]]; then
        die "No option specified (see --help)"
    fi
}


function invoke_install_epiphany() {
    $(flatpak remotes --columns=url | grep "https://flatpak.elementary.io/repo/" > /dev/null 2>&1) || is_appcenter_installed="false"

    if [[ $(is_flatpak_repo_installed "https://flatpak.elementary.io/repo/") != "true" ]]; then
        say "Adding AppCenter Flatpak remote..."
        flatpak remote-add \
            --if-not-exists \
            --system \
            --comment="The open source, pay-what-you-want app store from elementary" \
            --description="Reviewed and curated by elementary to ensure a native, privacy-respecting, and secure experience" \
            --gpg-import=/usr/share/gnupg/appcenter.gpg \
            --homepage="https://appcenter.elementary.io/" \
            --icon="https://flatpak.elementary.io/icon.svg" \
            --if-not-exists \
            --title="AppCenter" \
            appcenter https://flatpak.elementary.io/repo/

        if [[ $(is_flatpak_repo_installed "https://flatpak.elementary.io/repo/") != "true" ]]; then
            say "Adding Flathub Flatpak remote..."
            flatpak remote-add \
                --if-not-exists \
                --system \
                flathub https://flathub.org/repo/flathub.flatpakrepo
        fi
    fi

    install_flatpak_app flathub org.freedesktop.Platform.GL.default 21.08
    install_flatpak_app appcenter org.gnome.Epiphany stable
}

function is_flatpak_repo_installed() {
    if [[ $(flatpak remotes --columns=url --system | grep "$1") ]]; then
        echo "true"
    fi
}

function install_flatpak_app() {
    repo=$1
    app=$2
    branch=$3

    [[ -z $branch ]] && branch="stable"

    say "Installing app '$app'..."
    flatpak install --assumeyes --noninteractive --or-update --system $repo $app $branch
}

[[ $is_invoked != "true" ]] && rocks.sodalite.hacks $0 $@
