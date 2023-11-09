#!/usr/bin/env bash

_PLUGIN_TITLE="Sodalite migration tools"
_PLUGIN_DESCRIPTION=""
_PLUGIN_OPTIONS=(
    "all;a;"
    "cleanup-tool;;"
    "flatpak-apps;;"
    "hostname;;"
    "old-refs;;"
    "user-data;;"
    "force;f;"
    "no-internet;;"
)
_PLUGIN_HIDDEN="true"
_PLUGIN_ROOT="true"

_installed_apps_file="$(get_vardir)/unattended-installed-apps"

function get_flatpak_repo_name() {
    remote_name="$(dbus-launch flatpak remotes --columns=name,url --show-disabled --system | grep "$1"  | sed "s/\thttps:.*//")"
    [[ $remote_name != "" ]] && echo $remote_name
}

function install_flatpak_app() {
    repo=$1
    app=$2
    branch=$3

    [[ -z $branch ]] && branch="stable"

    dbus-launch flatpak install --assumeyes --noninteractive --or-update --system $repo $app $branch
}

function is_flatpak_app_installed() {
    app=$1
    repo=$2

    installed="true"

    if [[ -z $repo ]]; then
        dbus-launch flatpak info --system $1 > /dev/null 2>&1 || installed="false"
    else
        dbus-launch flatpak info --system $1 | grep "Origin: $2" > /dev/null 2>&1 || installed="false"
    fi

    echo $installed
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

function migrate_cleanup_tool() {
	[[ $force == "true" ]] && die "--force cannot be used with --cleanup-tool"
	cleanup_tool_bin="rocks.sodalite.cleanup"
	cleanup_tool_alias="sodalite-cleanup"

	if [[ -f "/usr/libexec/$cleanup_tool_bin" ]]; then
		rm -f "/usr/local/bin/$cleanup_tool_bin"
		rm -f "/usr/local/bin/$cleanup_tool_alias"

		cp "/usr/libexec/$cleanup_tool_bin" "/usr/local/bin/$cleanup_tool_bin"

		chmod +x "/usr/local/bin/$cleanup_tool_bin"
		ln -s "/usr/local/bin/$cleanup_tool_bin" "/usr/local/bin/$cleanup_tool_alias"
	fi
}

function migrate_flatpak_apps() {
    run_flatpak_uninstall_unused="false"
    touch "$_installed_apps_file"

    flatpak_repo_flathub_name="flathub"
    flatpak_repo_flathub_url="https://dl.flathub.org/repo/"
    flatpak_repo_appcenter_name="appcenter"
    flatpak_repo_appcenter_url="https://flatpak.elementary.io/repo/"

    if [[ $force == "true" ]]; then
        echo "" > "$_installed_apps_file"
    fi

    if [[ $(get_flatpak_repo_name "$flatpak_repo_flathub_url") == "" ]]; then
        update_status "Adding Flathub Flatpak remote..."
        dbus-launch flatpak remote-add \
            --if-not-exists \
            --system \
            $flatpak_repo_flathub_name https://flathub.org/repo/flathub.flatpakrepo
    else
        flatpak_repo_flathub_name="$(get_flatpak_repo_name "$flatpak_repo_flathub_url")"
    fi

    if [[ $core == "pantheon" ]]; then
        if [[ $(get_flatpak_repo_name "$flatpak_repo_appcenter_url") == "" ]]; then
            update_status "Adding AppCenter Flatpak remote..."
            dbus-launch flatpak remote-add \
                --if-not-exists \
                --system \
                --comment="The open source, pay-what-you-want app store from elementary" \
                --description="Reviewed and curated by elementary to ensure a native, privacy-respecting, and secure experience" \
                --gpg-import=/usr/share/gnupg/appcenter.gpg \
                --homepage="https://appcenter.elementary.io/" \
                --icon="https://flatpak.elementary.io/icon.svg" \
                --title="AppCenter" \
                appcenter https://flatpak.elementary.io/repo/
        else
            flatpak_repo_appcenter_name="$(get_flatpak_repo_name "$flatpak_repo_appcenter_url")"
        fi
    fi

    update_status "Enabling various Flatpak remotes..."
    [[ $core == "pantheon" ]] && dbus-launch flatpak remote-modify $flatpak_repo_appcenter_name --enable
    dbus-launch flatpak remote-modify $flatpak_repo_flathub_name --enable

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
        "pantheon:$flatpak_repo_appcenter_name:io.elementary.Platform:7.1"
        "pantheon:$flatpak_repo_appcenter_name:org.gnome.Evince:stable"
        "pantheon:$flatpak_repo_appcenter_name:org.gnome.FileRoller:stable"
        "pantheon:$flatpak_repo_appcenter_name:io.elementary.calculator:stable"
        "pantheon:$flatpak_repo_appcenter_name:io.elementary.calendar:stable"
        "pantheon:$flatpak_repo_appcenter_name:io.elementary.camera:stable"
        "pantheon:$flatpak_repo_appcenter_name:io.elementary.capnet-assist:stable"
        #"pantheon:$flatpak_repo_appcenter_name:io.elementary.mail:stable" # Not yet stable
        "pantheon:$flatpak_repo_appcenter_name:io.elementary.screenshot:stable"
        "pantheon:$flatpak_repo_appcenter_name:io.elementary.tasks:stable"
        "pantheon:$flatpak_repo_appcenter_name:io.elementary.videos:stable"
        "pantheon:$flatpak_repo_flathub_name:org.freedesktop.Platform:22.08"
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
                dbus-launch flatpak uninstall --assumeyes --force-remove --noninteractive $app_id

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
        dbus-launch flatpak uninstall --assumeyes --noninteractive --unused
    fi
}

function migrate_hostname() {
    current_hostname=$(hostnamectl hostname)

    if [[ $force == "true" ]] || [[ $current_hostname == "fedora" ]] || [[ $current_hostname == "localhost" ]] || [[ $current_hostname == "" ]]; then
        hostname_array=()

        for i in {a..z} {A..Z} {0..9}; 
           do
           hostname_array[$RANDOM]=$i
        done

        new_hostname="sodalite-$(printf %s ${array[@]::6} $'\n')"

        update_status "Setting hostname to '$new_hostname'..."
        hostnamectl hostname "$new_hostname"
    fi
}

function migrate_old_refs() {
    [[ $force == "true" ]] && die "--force cannot be used with --old-refs"

    set -f

    current_boot=""

    if [[ $(rpm-ostree status | grep "● ") != "" ]]; then
        current_boot="$(rpm-ostree status | grep "● " | cut -d "●" -f2)"
    elif [[ $(rpm-ostree status | grep "* ") != "" ]]; then
        current_boot="$(rpm-ostree status | grep "* " | cut -d "*" -f2)"
    fi

    echo $current_boot

    if [[ -n $current_boot ]]; then
        current_ref="$(echo $current_boot | cut -d ":" -f2)"
        current_remote="$(echo $current_boot | cut -d ":" -f1 | cut -d " " -f2)"
        current_version="$(get_property /etc/os-release VERSION)"

        ref_to_migrate_to=""

        case "$current_ref:$(echo $current_version | cut -d "." -f1).$(echo $current_version | cut -d "." -f2 | cut -d "+" -f1 | cut -d " " -f1)" in
            "sodalite/stable/x86_64/desktop:"*)
                ref_to_migrate_to="sodalite/current/x86_64/desktop"
                ;;
            "sodalite/f37/x86_64/desktop:"*)
                ref_to_migrate_to="sodalite/long-4/x86_64/desktop"
                ;;
        esac

        if [[ -n $ref_to_migrate_to ]]; then
            update_status "Rebasing to '$ref_to_migrate_to'..."
            rpm-ostree cancel
            rpm-ostree rebase "$current_remote:$ref_to_migrate_to"
        fi
    fi

    set +f
}

function migrate_user_data() {
    [[ $force == "true" ]] && die "--force cannot be used with --user-data"

    skel_files=(
        ".bashrc"
        ".config/touchegg/touchegg.conf"
    )
    system_locale="$(localectl status | grep "System Locale:" | cut -d "=" -f2)"

    if [[ -d /var/lib/AccountsService/users ]]; then
        for user_file in /var/lib/AccountsService/users/*; do
            user="$(basename $user_file)"
            passwd_ent="$(getent passwd $user)"

            if [[ -n $passwd_ent ]]; then
                user_home="$(echo $passwd_ent | cut -d ":" -f6)"

                if [[ $(get_core) == "pantheon" ]]; then
                    if [[ "$(get_property "$user_file" Language)" == "" ]]; then
                        update_status "Setting locale for '$user' to '$system_locale'..."
                        set_property "$user_file" Language "$system_locale"
                    fi
                fi

                if [[ -d "$user_home/Desktop" ]]; then
                    if [[ $(get_core) == "pantheon" ]]; then
                        if [ -z "$(ls -A "$user_home/Desktop")" ]; then
                            update_status "Removing Desktop directory for '$user'..."
                            rm -rf "$user_home/Desktop"
                        fi
                    fi
                else
                    if [[ $(get_core) != "pantheon" ]]; then
                        update_status "Creating Desktop directory for '$user'..."
                        mkdir -p "$user_home/Desktop"
                        chmod -r "$user":"$user" "$user_home/Desktop"
                    fi
                fi

                update_status "Installing skel for '$user'..."
                for skel_file in "${skel_files[@]}"; do
                    if [[ ! -f "$user_home/$skel_file" ]]; then
                        touchp "$user_home/$skel_file"
                        cp -f "/etc/skel/$skel_file" "$user_home/$skel_file"
                    fi
                done
            fi
        done
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

    [[ $all != "true" && $no_internet == "true" ]] && die "--no-internet cannot be used with --all"

	if [[ $cleanup_tool == "true" ]]; then
        has_run="true"
        migrate_cleanup_tool
    fi

    if [[ $flatpak_apps == "true" ]]; then
        has_run="true"
        migrate_flatpak_apps
    fi

    if [[ $hostname == "true" ]]; then
        has_run="true"
        migrate_hostname
    fi

    if [[ $old_refs == "true" ]]; then
        has_run="true"
        migrate_old_refs
    fi

    if [[ $user_data == "true" ]]; then
        has_run="true"
        migrate_user_data
    fi

    if [[ $all == "true" ]]; then
        [[ $force == "true" ]] && die "--force cannot be used with --all"

        has_run="true"

		migrate_cleanup_tool
        migrate_hostname
        migrate_user_data

        if [[ $no_internet != "true" ]]; then
            migrate_old_refs
            migrate_flatpak_apps
        fi
    fi

    if [[ $has_run == "false" ]]; then
        die "No option specified (see --help)"
    fi

    update_status
    pid="$(del_pidfile)"
    exit 0
}
