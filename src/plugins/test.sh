#!/usr/bin/env bash

_PLUGIN_TITLE=""
_PLUGIN_DESCRIPTION=""
_PLUGIN_OPTIONS=(
    "test-get-property;;Invoke get_property()"
    "test-get-random-string;;Invoke get_random_string()"
    "no-header;n;Don't print header"
)
_PLUGIN_HIDDEN="true"

function print_header() {
    if [[ $no_header != "true" ]]; then
        title="$1"
        say "\033[1m$title\033[0m"
        say "\033[1;34m$(repeat "-" ${#title})\033[0m"
    fi
}

function main() {
    if [[ $options == "" ]]; then
        say "Hello, world!"
    fi

    if [[ -n "$test_get_property" ]]; then
        print_header "get_property()"
        [[ $test_get_property == "true" ]] && test_get_property=""
        eval "get_property $test_get_property"
    fi

    if [[ -n "$test_get_random_string" ]]; then
        print_header "get_random_string()"
        [[ $test_get_random_string == "true" ]] && test_get_random_string=""
        eval "get_random_string $test_get_random_string"
    fi
}
