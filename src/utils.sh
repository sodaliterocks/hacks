#!/usr/bin/env bash

function get_answer() {
    question=$@

    if [[ ! -n $question ]]; then
        question="Continue?"
    fi

    while true; do
        read -p "$question [Y/n]: " answer
        if [[ $answer = "" ]]; then
            answer="Y"
        fi
        case $answer in
            [Yy]* ) echo "y"; return ;;
            [Nn]* ) echo "n"; return ;;
            * ) ;;
        esac
    done
}

function parse_plugin_option() {
    IFS=";" read -r -a option <<< "${@}"

    _PLUGIN_OPTION_PARAM="${option[0]}"
    _PLUGIN_OPTION_SHORT="${option[1]}"
    _PLUGIN_OPTION_HELP="${option[2]}"
}

function rost_apply_live() {
    message=$1
    [[ -z $message ]] && message="Unable to apply changes live. Reboot required to process changes."
    
    rpm-ostree ex apply-live --allow-replacement

    if [[ ! $? -eq 0 ]]; then
        say "\n$message"
        if [[ $(get_answer "Reboot now?") == "y" ]]; then
            say "Rebooting..."
            shutdown -r now
        else
            exit
        fi
    fi
}

function source_plugin() {
    plugin_file=$1
    
    export -f die
    export -f say
    
    . $plugin_file > /dev/null 2>&1
}
