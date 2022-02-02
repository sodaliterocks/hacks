#!/usr/bin/env bash

function parse_plugin_option() {
    IFS=";" read -r -a option <<< "${@}"

    _PLUGIN_OPTION_PARAM="${option[0]}"
    _PLUGIN_OPTION_SHORT="${option[1]}"
    _PLUGIN_OPTION_HELP="${option[2]}"
}

function source_plugin() {
    plugin_file=$1
    
    export -f die
    export -f say
    
    . $plugin_file > /dev/null 2>&1
}
