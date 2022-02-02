#!/usr/bin/env bash

_PLUGIN_TITLE="Flatpak helpers"
_PLUGIN_DESCRIPTION="Various helpers for Flatpak"
_PLUGIN_OPTIONS=(
    "setup-appcenter;;Add AppCenter repository and install extra apps"
    "install-epiphany;;Install Epiphany from AppCenter"
    "remove-gnome-apps;;Uninstall default GNOME apps"
)
_PLUGIN_ROOT="true"

function main() {
    if [[ -x "$(command -v flatpak)" ]]; then
        has_run="false"
        
        if [[ $install_epiphany == "true" ]]; then
            has_run="true"
            invoke_install_epiphany
        fi

        if [[ $remove_gnome_apps == "true" ]]; then
            has_run="true"
            invoke_remove_gnome_apps
        fi
        
        if [[ $setup_appcenter == "true" ]]; then
            has_run="true"
            invoke_setup_appcenter
        fi
        
        if [[ $has_run == "false" ]]; then
            die "No option specified (see --help)"
        fi
    else
        die "Flatpak not installed"
    fi
}


function invoke_install_epiphany() {
    say "Installing Epiphany from AppCenter..."
    flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo
    install_app org.freedesktop.Platform.GL.default flathub 21.08
    install_app org.gnome.Epiphany appcenter stable
}

function invoke_remove_gnome_apps() {
    say "Removing default GNOME apps (if installed)..."
    flatpak uninstall --assumeyes --force-remove --unused \
        org.gnome.Calculator \
        org.gnome.Calendar \
        org.gnome.Characters \
        org.gnome.Connections \
        org.gnome.Contacts \
        org.gnome.Evince \
        org.gnome.FileRoller \
        org.gnome.Logs \
        org.gnome.Maps \
        org.gnome.NautilusPreviewer \
        org.gnome.Screenshot \
        org.gnome.Weather \
        org.gnome.baobab \
        org.gnome.clocks \
        org.gnome.eog \
        org.gnome.font-viewer \
        org.gnome.gedit
        
    install_pantheon_apps
}

function invoke_setup_appcenter() {
    # TODO: Get GPG key from remote location?
    # TODO: Check we can reach the remote, otherwise abandon this attempt

    if [[ ! -f /usr/share/gnupg/appcenter.gpg ]]; then
        die "AppCenter GPG not found"
    fi

    echo "Adding AppCenter repository (if not exists)..."
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

    install_pantheon_apps
}


function is_app_installed() {
    app=$1
    origin=$2

    installed=true
    
    if [[ -z $origin ]]; then
        $(flatpak info --system $1 > /dev/null 2>&1) || installed=false
    else
        $(flatpak info --system $1 | grep "Origin: $2" > /dev/null 2>&1) || installed=false
    fi
    
    echo $installed
}

function install_app() {
    app=$1
    branch=$3
    origin=$2

    [[ -z $branch ]] && branch="stable"
    [[ -z $origin ]] && origin="appcenter"

    echo "Installing (or updating) $app/$branch from $origin..."
    flatpak install --assumeyes --noninteractive --or-update --system $origin $app $branch
}

function install_pantheon_apps() {
    is_appcenter_installed="true"
    $(flatpak remotes --columns=url | grep "https://flatpak.elementary.io/repo/" > /dev/null 2>&1) || is_appcenter_installed="false"

    if [[ $is_appcenter_installed == "true" ]]; then
        install_app org.gnome.Evince appcenter
        install_app org.gnome.FileRoller appcenter
    fi
}
