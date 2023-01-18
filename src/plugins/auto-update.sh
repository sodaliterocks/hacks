#!/usr/bin/env bash

delay_init=600
delay_check_logged_in=60
delay_check_updates=10800
delay_update_retry=60
service_file=""

_PLUGIN_TITLE="Auto Updater"
_PLUGIN_DESCRIPTION=""
_PLUGIN_OPTIONS=(
    "ignore-logged-in;;Run even if users are logged in"
    "toggle-service;;Toggle systemd service"
)
_PLUGIN_HIDDEN="true"
_PLUGIN_ROOT="true"

function main() {
    if [[ $toggle_service == "true" ]]; then
        toggle_service "sodalite-auto-update.service"
        exit 0
    fi

    [[ -n $(get_pidfile) ]] && die "Already running"
    pid="$(set_pidfile)"

    check_prog "rpm-ostree"

    while true; do
        uptime="$(cat /proc/uptime)"
        uptime="${uptime%%.*}"

        if (( $delay_init > $uptime )); then
            delay_init=$(( $delay_init - $uptime ))
            say info "System recently booted. Waiting $delay_init seconds..."
            sleep $delay_init
        fi

        say primary "Checking for updates..."
        rpm-ostree upgrade --check --unchanged-exit-77

        if [[ $? -ne 77 ]]; then
            while true; do
                logged_in_users="$(users | sed -s 's/root//g')"
                update="false"

                if [[ $ignore_logged_in == "true" ]]; then
                    update="true"
                else
                    if [[ "$logged_in_users" == "" ]]; then
                        update="true"
                    fi
                fi

                if [[ $update == "true" ]]; then
                    say info "Updating..."
                    rpm-ostree upgrade --unchanged-exit-77

                    if [[ $? -ne 77 ]]; then
                        say info "Restarting OS..."
                        shutdown -r now
                    else
                        say warning "Update pending but nothing deployed. Retrying in $delay_update_retry seconds..."
                        sleep $delay_update_retry
                    fi
                else
                    say info "Users logged in ($logged_in_users). Waiting $delay_check_logged_in seconds..."
                    sleep $delay_check_logged_in
                fi
            done
        else
            say info "No updates available. Retrying in $delay_check_updates seconds..."
            sleep $delay_check_updates
        fi
    done

    pid="$(del_pidfile)"
}
