#!/usr/bin/env bash

SODALITE_HACKS_INVOKED="true"
prog=$(basename "$(realpath -s "$0")")
cmd=$@
base_dir="$(dirname "$(realpath -s "$0")")"
plugins_dir=""

[[ ! -e "$base_dir/../.git" ]] && base_dir="/usr/libexec/rocks.sodalite.hacks"

plugins_dir="$base_dir/plugins"
. $base_dir/utils.sh

function print_help() {
    say "Sodalite Hacks"
    say "\nUsage:"
    say "  $prog [command] [options]"
    say "\nCommands:"

    for f in $plugins_dir/*.sh; do
        _PLUGIN_DESCRIPTION="(No description)"
        _PLUGIN_HIDDEN=""

        source_plugin "$f"

        if [[ $? -eq 0 ]]; then
            if [[ $_PLUGIN_HIDDEN != "true" ]]; then
                say "  $(basename "$f" | cut -d. -f1)\t$_PLUGIN_DESCRIPTION"
            fi
        fi
    done

    say "\nOptions:"
    say " -h, --help\tShow help (invoking with no [command] lists all available plugins)"
}

function invoke_plugin() {
    plugin=$1
    options=${@:2}
    plugin_file=""
    plugin_dir=""

    if [[ $plugin == "/"* ]] || [[ $plugin == "./"* ]]; then
        local_plugin_file="$plugin"

        if [[ -f "$local_plugin_file" ]]; then
            if [[ -f "$plugins_dir/$(basename "$local_plugin_file" | cut -d. -f1).sh" ]]; then
                plugin="$(basename "$local_plugin_file" | cut -d. -f1)"
                plugin_file="$plugins_dir/$plugin.sh"
            else
                plugin_file="$local_plugin_file"
            fi
        else
            die "'$local_plugin_file' does not exist"
        fi
    else
        plugin_file="$plugins_dir/$plugin.sh"
    fi

    debug "Invoking executable '$plugin_file'"

    if [[ -f $plugin_file ]]; then
        plugin_dir="$(dirname "$(realpath -s "$plugin_file")")"
        source_plugin $plugin_file

        if { [[ $options == "--help" ]] || [[ $options == "-h" ]]; }; then
            [[ -z $_PLUGIN_TITLE ]] && _PLUGIN_TITLE="$plugin"
            [[ -z $_PLUGIN_DESCRIPTION ]] && _PLUGIN_DESCRIPTION="(No description)"

            say "$_PLUGIN_TITLE"
            say "  $_PLUGIN_DESCRIPTION"
            say "\nUsage:"

            if [[ ! -z $_PLUGIN_OPTIONS ]]; then
                if [[ $SODALITE_HACKS_OVERRIDE_USAGE_PREFIX == "" ]]; then
                    say "  $prog $plugin [options]"
                else
                    say "  $SODALITE_HACKS_OVERRIDE_USAGE_PREFIX [options]"
                fi

                say "\nOptions:"

                for i in "${_PLUGIN_OPTIONS[@]}"; do
                    parse_plugin_option ${i}

                    param="--$_PLUGIN_OPTION_PARAM"

                    if [[ ! -z $_PLUGIN_OPTION_SHORT ]]; then
                        param="-$_PLUGIN_OPTION_SHORT, $param"
                    fi

                    say "  $param\t$_PLUGIN_OPTION_HELP"
                done
            else
                say "  $prog $plugin"
            fi

            exit 0
        fi

        if [[ $_PLUGIN_ROOT == "true" && ! $(id -u) = 0 ]]; then
            die "Unauthorized (are you root?)"
        fi

        if [[ ! -z $options ]]; then
            for i in "${_PLUGIN_OPTIONS[@]}"; do
                parse_plugin_option ${i}

                debug "Found option --$_PLUGIN_OPTION_PARAM (-$_PLUGIN_OPTION_SHORT)"

                if [[ $_PLUGIN_OPTION_PARAM == "" ]]; then
                    die "Plugin '$plugin' is malformed (bad \$$_PLUGIN_OPTION_PARAM: $_PLUGIN_OPTION_PARAM)"
                fi

                if [[ $(echo "$options " | grep -o -P "(--$_PLUGIN_OPTION_PARAM |-$_PLUGIN_OPTION_SHORT )") ]]; then
                    value=$(echo $options | grep -o -P "(?<=--$_PLUGIN_OPTION_PARAM |-$_PLUGIN_OPTION_SHORT ).*?(?:(?= -| --)|$)")
                    if { [[ -z $value ]] || [[ $value == -* ]]; }; then
                        value="true"
                    else
                        value=$(echo $value | xargs)
                    fi

                    debug "Value for option --$_PLUGIN_OPTION_PARAM (-$_PLUGIN_OPTION_SHORT) is '$value'"

                    variable=$(echo $_PLUGIN_OPTION_PARAM | sed s/-/_/g)
                    debug "Setting variable \$$variable to '$value'"
                    eval "${variable}"='${value}' # bite me
                fi
            done
        fi

        main
        if [[ ! $? -eq 0 ]]; then
            die "Plugin '$1' has no entrypoint (needs main())"
        fi
    else
        die "Plugin '$1' does not exist"
    fi
}

debug "Base directory is '$base_dir'"
debug "Plugins directory is '$plugins_dir'"
debug "Invoking command '$cmd'"

case $cmd in
    list|help|-h|--help|?|"")
        print_help
    ;;
    *)
        invoke_plugin $cmd
    ;;
esac
