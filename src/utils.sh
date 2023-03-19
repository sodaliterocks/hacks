#!/usr/bin/env bash

_pidfile_dir="/var/run/rocks.sodalite.hacks"

function check_prog() {
    [[ ! $(command -v "$1") ]] && die "'$1' not installed"
}

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

function debug() {
    if [[ $SODALITE_HACKS_DEBUG == "true" ]]; then
        say debug "$@"
    fi
}

function die() {
    say error "$@"
    exit 255
}

function emj() {
    emoji="$1"
    emoji_length=${#emoji}
    echo "$emoji$(eval "for i in {1..$emoji_length}; do echo -n " "; done")"
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
    file="$1"
    property="$2"

    if [[ -f $file ]]; then
        echo $(grep -oP '(?<=^'"$property"'=).+' $file | tr -d '"')
    fi
}

function get_random_string() {
    amount=$1

    if ! [[ -n $amount ]]; then
        amount=6
    fi

    eval "echo $RANDOM | md5sum | head -c ${amount}; echo;"
}

function get_vardir() {
    vardir="/var/lib/sodalite"
    [[ ! -d $vardir ]] && mkdir -p $vardir
    echo $vardir
}

function parse_file_uri() {
    file="$1"
    uri="$(echo "$1" | sed "s/file:\/\///g" | sed "s/'//g")"
    echo "$(parse_uri "$uri")"
}

function parse_uri() {
    : "${*//+/ }"; echo -e "${_//%/\\x}";
}

function repeat() {
    string="$1"
    amount=$2

    if ! [[ -n $amount ]]; then
        amount=20
    fi

    eval "for i in {1..$amount}; do echo -n "$1"; done"
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

function say() {
	color=""
	emoji=""
    message="${@:2}"
    output=""
    prefix=""
    style="0"

    if [[ "$2" != "" ]]; then
    	message="$2"
    	type="$1"
    else
    	message="$1"
    fi

    case $1 in
        debug)
            color="35"
            prefix="Debug"
            ;;
        error)
            color="31"
            prefix="Error"
            style="1"
            ;;
        info)
            color="34"
            style="1"
            ;;
        primary)
            color="37"
            style="1"
            ;;
        warning)
            color="33"
            style="1"
            ;;
        *|default)
            color="0"
            message="$@"
            ;;
    esac

    if [[ $prefix == "" ]]; then
        output="\033[${style};${color}m${message}\033[0m"
    else
        output="\033[1;${color}m${prefix}"

        if [[ $message == "" ]]; then
            output+="!"
        else
            output+=": \033[${style};${color}m${message}\033[0m"
        fi

        output+="\033[0m"
    fi

    if [[ $emoji != "" ]]; then
        output="$(emj "$emoji")$output"
    fi

    echo -e "$output"
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
    . $plugin_file > /dev/null 2>&1
}

function toggle_service() {
    service="$1"

    if [ $(systemctl list-unit-files "$service" | wc -l) -gt 3 ]; then
        service_status="$(systemctl is-enabled "$service")"

        if [[ $service_status == "enabled" ]]; then
            systemctl disable --now "$service"
        else
            systemctl enable --now "$service"
        fi
    else
        die "Service '$service' does not exist"
    fi
}

function touchp() {
    mkdir -p "$(dirname "$1")/" && touch "$1"
}
