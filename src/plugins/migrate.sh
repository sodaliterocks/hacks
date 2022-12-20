#!/usr/bin/env bash

_PLUGIN_TITLE="Sodalite migration tools"
_PLUGIN_DESCRIPTION=""
_PLUGIN_OPTIONS=(
    "flatpak-apps;;"
    "old-refs;;"
)
_PLUGIN_HIDDEN="true"
_PLUGIN_ROOT="true"

_installed_apps_file="$(get_confdir)/unattanded-installed-apps"

function install_flatpak_app() {
    repo=$1
    app=$2
    branch=$3

    [[ -z $branch ]] && branch="stable"

    flatpak install --assumeyes --noninteractive --or-update --system $repo $app $branch
}

function is_flatpak_app_installed() {
    app=$1
    repo=$2

    installed="true"

    if [[ -z $repo ]]; then
        flatpak info --system $1 > /dev/null 2>&1 || installed="false"
    else
        flatpak info --system $1 | grep "Origin: $2" > /dev/null 2>&1 || installed="false"
    fi

    echo $installed
}

function is_flatpak_repo_installed() {
    if [[ $(flatpak remotes --columns=url --system | grep "$1") ]]; then
        echo "true"
    fi
}

function update_status() {
    migrate_status_file="$_pidfile_dir/migrate-status"
    status="$@"

    if [[ ! -f "$migrate_status_file" ]]; then
        mkdir -p "$_pidfile_dir"
        touch "$migrate_status_file"
    fi

    if [[ "$status" == "" ]]; then
        rm -f $migrate_status_file
    else
        echo "$status"
        echo "$status" > $migrate_status_file
    fi
}

function migrate_old_refs() {
    current_boot="$(rpm-ostree status | grep "*" | cut -d "*" -f2)"
    current_ref="$(echo $current_boot | cut -d ":" -f2)"
    current_remote="$(echo $current_boot | cut -d ":" -f1 | cut -d " " -f2)"
    current_version="$(get_property /etc/os-release VERSION)"

    ref_to_migrate_to=""

    case "$current_ref:$(echo $current_version | cut -d "." -f1).$(echo $current_version | cut -d "." -f2)" in
        "sodalite/f36/x86_64/base:36-22.15")
            ref_to_migrate_to="sodalite/stable/x86_64/desktop"
            ;;
        "sodalite/f36/x86_64/base:36-22.15")
            ref_to_migrate_to="sodalite/f36/x86_64/desktop"
            ;;
    esac

    if [[ -n $ref_to_migrate_to ]]; then
        update_status "Rebasing to '$ref_to_migrate_to'..."
        #rpm-ostree cancel
        #rpm-ostree rebase $ref_to_migrate_to
    fi
}

function migrate_flatpak_apps() {
    run_flatpak_uninstall_unused="false"

    touch "$_installed_apps_file"

    if [[ $core == "pantheon" ]]; then
        if [[ $(is_flatpak_repo_installed "https://flatpak.elementary.io/repo/") != "true" ]]; then
            update_status "Adding AppCenter remote..."
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
        fi
    fi

    apps=(
        "gnome:fedora:org.gnome.Calculator"
        "gnome:fedora:org.gnome.Calendar"
        "gnome:fedora:org.gnome.Characters"
        "gnome:fedora:org.gnome.Connections"
        "gnome:fedora:org.gnome.Contacts"
        "gnome:fedora:org.gnome.Evince"
        "gnome:fedora:org.gnome.Extensions"
        "gnome:fedora:org.gnome.FileRoller"
        "gnome:fedora:org.gnome.Logs"
        "gnome:fedora:org.gnome.Maps"
        "gnome:fedora:org.gnome.NatutilusPreviewer"
        "gnome:fedora:org.gnome.Screenshot"
        "gnome:fedora:org.gnome.TextEditor"
        "gnome:fedora:org.gnome.Weather"
        "gnome:fedora:org.gnome.baobab"
        "gnome:fedora:org.gnome.clocks"
        "gnome:fedora:org.gnome.eog"
        "gnome:fedora:org.gnome.font-viewer"
        "gnome:fedora:org.gnome.gedit"
        "pantheon:appcenter:org.gnome.Evince:stable"
        "pantheon:appcenter:org.gnome.FileRoller:stable"
        "pantheon:appcenter:io.elementary.calculator:stable"
        "pantheon:appcenter:io.elementary.camera:stable"
        "pantheon:appcenter:io.elementary.capnet-assist:stable"
        "pantheon:appcenter:io.elementary.screenshot:stable"
        #"pantheon:appcenter:io.elementary.tasks:stable"
        "pantheon:appcenter:io.elementary.videos:stable"
    )

    for app in "${apps[@]}"
    do
        app_core="$(echo "$app" | awk -F':' '{print $1}')"
        app_repo="$(echo "$app" | awk -F':' '{print $2}')"
        app_id="$(echo "$app" | awk -F':' '{print $3}')"
        app_branch="$(echo "$app" | awk -F':' '{print $4}')"

        if [[ "$app_core" == "$core" ]]; then
            if [[ ! $(grep -Fxq "$app" "$_installed_apps_file") ]]; then
                update_status "Installing app '$app_id'..."

                install_success="true"
                if [[ $(is_flatpak_app_installed "$app_id" "$app_repo") == "false" ]]; then
                    install_flatpak_app "$app_repo" "$app_id" "$app_branch"
                    [[ $? != 0 ]] && install_success="false"
                fi

                [[ $install_success == "true" ]] && echo "$app_core:$app_repo:$app_id:$app_branch" >> $_installed_apps_file
            fi
        else
            if [[ $(is_flatpak_app_installed "$app_id" "$app_repo") == "true" ]]; then
                update_status "Uninstalling app '$app_id'..."
                flatpak uninstall --assumeyes --force-remove --noninteractive $app_id
                [[ $? == 0 ]] && sed -i /$app/d  $_installed_apps_file
                [[ $run_flatpak_uninstall_unused == "false" ]] && run_flatpak_uninstall_unused="true"
            fi
        fi
    done

    if [[ $run_flatpak_uninstall_unused == "true" ]]; then
        update_status "Uninstalling unused apps..."
        flatpak uninstall --assumeyes --noninteractive --unused
    fi
}

function main() {
    pid="$(set_pidfile)"
    core="$(get_core)"
    has_run="false"

    if [[ $flatpak_apps == "true" ]]; then
        has_run="true"
        migrate_flatpak_apps
    fi

    if [[ $old_refs == "true" ]]; then
        has_run="true"
        migrate_old_refs
    fi

    if [[ $has_run == "false" ]]; then
        migrate_flatpak_apps
        migrate_old_refs
    fi

    update_status
    pid="$(del_pidfile)"
}
