#!/usr/bin/env bash

_pidfile_dir="/var/run/sodalite-hacks"

function del_pidfile() {
    pidfile=""

    if [[ -n "$plugin" ]]; then
        pidfile="$plugin"
    else
        pidfile="$1"
    fi

    pidfile="$pidfile.pid"

    [[ "$(cat $_pidfile_dir/$pidfile)" == $pid ]] && rm -f "$_pidfile_dir/$pidfile"
    [[ -z "$(ls -A $_pidfile_dir)" ]] && rm -fr "$_pidfile_dir"
}

function del_property() {
    file=$1
    property=$2

    if [[ -f $file ]]; then
        if [[ ! -z $(get_property $file $property) ]]; then
            sed -i "s/^\($property=.*\)$//g" $file
        fi
    fi
}


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

function get_core() {
    if [[ -f "/usr/lib/sodalite-core" ]]; then
        echo "$(cat /usr/lib/sodalite-core)"
    else
        echo "pantheon"
    fi
}

function get_pidfile() {
    pidfile=""

    if [[ -n "$plugin" ]]; then
        pidfile="$plugin"
    else
        pidfile="$1"
    fi

    pidfile="$pidfile.pid"

    if [[ -f "$_pidfile_dir/$pidfile" ]]; then
        pid="$(cat $_pidfile_dir/$pidfile)"
        if ps -p $pid > /dev/null; then
            echo "$pid"
        else
            del_pidfile
        fi
    fi
}

function get_property() {
    file=$1
    property=$2

    if [[ -f $file ]]; then
        echo $(grep -oP '(?<=^'"$property"'=).+' $file | tr -d '"')
    fi
}

function get_vardir() {
    vardir="/var/lib/sodalite"
    [[ ! -d $vardir ]] && mkdir -p $vardir
    echo $vardir
}

function parse_file_uri() {
    file="$1"
    echo "$1" | sed "s/file:\/\///g" | sed "s/'//g"
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

function set_pidfile() {
    pid="$$"
    pidfile=""

    if [[ -n "$plugin" ]]; then
        pidfile="$plugin"
    else
        pidfile="$1"
    fi

    pidfile="$pidfile.pid"

    [[ ! -d "$_pidfile_dir" ]] && mkdir -p "$_pidfile_dir"
    touch "$_pidfile_dir/$pidfile"
    echo "$$" > "$_pidfile_dir/$pidfile"

    echo "$(cat "$_pidfile_dir/$pidfile")"
}

function set_property() {
    file=$1
    property=$2
    value=$3

    if [[ -f $file ]]; then
        if [[ -z $(get_property $file $property) ]]; then
            echo "$property=\"$value\"" >> $file
        else
            if [[ $value =~ [[:space:]]+ ]]; then
                value="\"$value\""
            fi

            sed -i "s/^\($property=\)\(.*\)$/\1$value/g" $file
        fi
    fi
}

function source_plugin() {
    plugin_file=$1
    
    export -f die
    export -f say
    
    . $plugin_file > /dev/null 2>&1
}
