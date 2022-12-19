#!/usr/bin/env bash

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

function get_property() {
    file=$1
    property=$2

    if [[ -f $file ]]; then
        echo $(grep -oP '(?<=^'"$property"'=).+' $file | tr -d '"')
    fi
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
