#!/usr/bin/env bash

_PLUGIN_TITLE="Sodalite migration tools"
_PLUGIN_DESCRIPTION=""
_PLUGIN_OPTIONS=(
    "flatpak-apps;;"
    "hostname;;"
    "locale;;"
    "old-refs;;"
    "force;f;"
)
_PLUGIN_HIDDEN="true"
_PLUGIN_ROOT="true"

_installed_apps_file="$(get_vardir)/unattended-installed-apps"

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

function migrate_flatpak_apps() {
    run_flatpak_uninstall_unused="false"
    touch "$_installed_apps_file"

    if [[ $force == "true" ]]; then
        echo "" > "$_installed_apps_file"
    fi

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

    # TODO: Migrate GNOME apps to use Flathub?
    apps=(
        "gnome:fedora:org.gnome.baobab"
        "gnome:fedora:org.gnome.Calculator"
        "gnome:fedora:org.gnome.Calendar"
        "gnome:fedora:org.gnome.Characters"
        "gnome:fedora:org.gnome.clocks"
        "gnome:fedora:org.gnome.Connections"
        "gnome:fedora:org.gnome.Contacts"
        "gnome:fedora:org.gnome.eog"
        "gnome:fedora:org.gnome.Evince"
        "gnome:fedora:org.gnome.Extensions"
        "gnome:fedora:org.gnome.FileRoller"
        "gnome:fedora:org.gnome.font-viewer"
        "gnome:fedora:org.gnome.gedit"
        "gnome:fedora:org.gnome.Logs"
        "gnome:fedora:org.gnome.Maps"
        "gnome:fedora:org.gnome.NautilusPreviewer"
        "gnome:fedora:org.gnome.Screenshot"
        "gnome:fedora:org.gnome.TextEditor"
        "gnome:fedora:org.gnome.Weather"
        "pantheon:appcenter:io.elementary.Platform:7.1"
        "pantheon:appcenter:org.gnome.Evince:stable"
        "pantheon:appcenter:org.gnome.FileRoller:stable"
        "pantheon:appcenter:io.elementary.calculator:stable"
        "pantheon:appcenter:io.elementary.calendar:stable"
        "pantheon:appcenter:io.elementary.camera:stable"
        "pantheon:appcenter:io.elementary.capnet-assist:stable"
        #"pantheon:appcenter:io.elementary.mail:stable" # Not yet stable
        "pantheon:appcenter:io.elementary.screenshot:stable"
        #"pantheon:appcenter:io.elementary.tasks:stable" # Broken?
        "pantheon:appcenter:io.elementary.videos:stable"
    )

    apps_no_install=(
        "gnome:fedora:org.gnome.gedit"
    )

    for app in "${apps[@]}"; do
        app_core="$(echo "$app" | awk -F':' '{print $1}')"
        app_repo="$(echo "$app" | awk -F':' '{print $2}')"
        app_id="$(echo "$app" | awk -F':' '{print $3}')"
        app_branch="$(echo "$app" | awk -F':' '{print $4}')"
        app_string="$app_core:$app_repo:$app_id:$app_branch"

        if [[ "$app_core" == "$core" ]]; then
            install="false"
            skip_install="false"

            for app_no_install in "${apps_no_install[@]}"; do
                if [[ "$app" == "$app_no_install" ]]; then
                    skip_install="true"
                fi
            done

            if [[ $skip_install == "false" ]]; then
                if [[ $(grep -Fx "+:$app_string" "$_installed_apps_file") == "" ]]; then
                    debug "Is '$core'. Installing '$app_string'"
                    install="true"
                elif [[ $(grep -Fx -- "-:$app_string" "$_installed_apps_file") != "" ]]; then
                    debug "Is '$core'. Installing '$app_string'"
                    install="true"
                else
                    debug "Is '$core'. Already installed '$app_string'"
                fi

                if [[ $install == "true" ]]; then
                    update_status "Installing app '$app_id'..."
                    install_flatpak_app "$app_repo" "$app_id" "$app_branch"

                    if [[ $? == 0 ]]; then
                        sed -i /"-:$app_string"/d $_installed_apps_file
                        echo "+:$app_string" >> $_installed_apps_file
                    fi
                fi
            fi
        else
            uninstall="false"

            if [[ $(grep -Fx "+:$app_string" "$_installed_apps_file") != "" ]]; then
                debug "Not '$core'. Already installed '$app_string'"
                uninstall="true"
            elif [[ $(grep -Fx -- "-:$app_string" "$_installed_apps_file") != "" ]]; then
                debug "Not '$core'. Already uninstalled '$app_string'"
            else
                if [[ $(is_flatpak_app_installed "$app_id" "$app_repo") == "true" ]]; then
                    debug "Not '$core'. Uninstalling '$app_string'"
                    uninstall="true"
                fi
            fi

            if [[ $uninstall == "true" ]]; then
                update_status "Uninstalling app '$app_id'..."
                flatpak uninstall --assumeyes --force-remove --noninteractive $app_id

                if [[ $? == 0 ]] || [[ $? == 1 ]]; then
                    sed -i /"+:$app_string"/d $_installed_apps_file
                    echo "-:$app_string" >> $_installed_apps_file
                fi

                [[ $run_flatpak_uninstall_unused == "false" ]] && run_flatpak_uninstall_unused="true"
            fi
        fi
    done

    if [[ $run_flatpak_uninstall_unused == "true" ]]; then
        update_status "Uninstalling unused apps..."
        flatpak uninstall --assumeyes --noninteractive --unused
    fi
}

function migrate_hostname() {
    current_hostname=$(hostnamectl hostname)

    if [[ $force == "true" ]] || [[ $current_hostname == "fedora" ]]; then
        new_hostname="sodalite-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-6} | head -n 1)"
        update_status "Setting hostname to '$new_hostname'..."
        hostnamectl hostname "$new_hostname"
    fi
}

function migrate_locale() {
    [[ $force == "true" ]] && die "--force cannot be used with --locale"

    # Pantheon has no built-in way to set locales properly, so we'll rely on
    # what localectl is set to. Unfortunately, this will unintentionally clobber
    # settings manually set by the user.
    if [[ $(get_core) == "pantheon" ]]; then
        system_locale="$(localectl status | grep "System Locale:" | cut -d "=" -f2)"

        if [[ -d /var/lib/AccountsService/users ]]; then
            for user_file in /var/lib/AccountsService/users/*; do
                user="$(basename $user_file)"
                passwd_ent="$(getent passwd $user)"

                if [[ -n $passwd_ent ]]; then
                    update_status "Setting locale for '$user' to '$system_locale'..."

                    set_property "$user_file" Language "$system_locale"
                    su -c "gsettings set org.gnome.system.locale region '$system_locale'" $user
                fi
            done
        fi
    fi
}

function migrate_old_refs() {
    [[ $force == "true" ]] && die "--force cannot be used with --old-refs"

    current_boot=""
    current_boot_indicator=""
    rost_status="$(rpm-ostree status)"

    if [[ $(echo $rost_status | grep "● ") != "" ]]; then
        current_boot_indicator="●"
    elif [[ $(echo $rost_status | grep "* ") != "" ]]; then
        current_boot_indicator="*"
    fi

    current_boot="$(echo $rost_status | grep "$current_boot_indicator " | cut -d "$current_boot_indicator" -f2 | cut -d " " -f2)"

    if [[ -n $current_boot ]]; then
        current_ref="$(echo $current_boot | cut -d ":" -f2)"
        current_remote="$(echo $current_boot | cut -d ":" -f1 | cut -d " " -f2)"
        current_version="$(get_property /etc/os-release VERSION)"

        ref_to_migrate_to=""

        case "$current_ref:$(echo $current_version | cut -d "." -f1).$(echo $current_version | cut -d "." -f2 | cut -d "+" -f1)" in
            "sodalite/stable/x86_64/base:36-22.15")
                ref_to_migrate_to="sodalite/stable/x86_64/desktop"
                ;;
            "sodalite/f36/x86_64/base:36-22.15")
                ref_to_migrate_to="sodalite/f36/x86_64/desktop"
                ;;
            "sodalite/next/x86_64/base:38-22.15")
                ref_to_migrate_to="sodalite/next/x86_64/desktop"
                ;;
            "sodalite/devel/x86_64/base:36-22.14")
                ref_to_migrate_to="sodalite/devel/x86_64/desktop"
                ;;
        esac

        if [[ -n $ref_to_migrate_to ]]; then
            update_status "Rebasing to '$ref_to_migrate_to'..."
            rpm-ostree cancel
            rpm-ostree rebase "$current_remote:$ref_to_migrate_to"
        fi
    fi
}

function main() {
    [[ -n $(get_pidfile) ]] && die "Already running"

    pid="$(set_pidfile)"
    core="$(get_core)"
    has_run="false"

    if [[ ! -n $INVOCATION_ID ]]; then
        if [[ $(get_answer "Not running from systemd. Are you sure you want to run manually?") == "n" ]]; then
            exit
        fi
    fi

    if [[ $flatpak_apps == "true" ]]; then
        has_run="true"
        migrate_flatpak_apps
    fi

    if [[ $hostname == "true" ]]; then
        has_run="true"
        migrate_hostname
    fi

    if [[ $locale == "true" ]]; then
        has_run="true"
        migrate_locale
    fi

    if [[ $old_refs == "true" ]]; then
        has_run="true"
        migrate_old_refs
    fi

    if [[ $has_run == "false" ]]; then
        # NOTE: Order by intensive-ness (least intensive first)
        migrate_hostname
        migrate_locale
        migrate_old_refs
        migrate_flatpak_apps
    fi

    update_status
    pid="$(del_pidfile)"
}
