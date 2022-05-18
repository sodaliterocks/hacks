#!/usr/bin/env bash

prog=$(basename "$(realpath -s "$0")" | cut -d. -f1)
cmd=$@
base_dir="$(dirname "$(realpath -s "$0")")"
plugins_dir=""

function die() {
    message=$@
    say "\033[1;31mError: $message\033[0m"
    exit 255
}

function debug() {
    if [[ $SODALITE_HACKS_DEBUG == "true" ]]; then
        message=$@
        say "\033[1;33mDebug:\033[0m $message"
    fi
}

function say() {
    message=$@
    echo -e "$@"
}

if [[ -d "$base_dir/../.git" ]]; then
    plugins_dir="$base_dir/plugins"
    . $base_dir/utils.sh
elif [[ $base_dir == "/usr/bin" ]]; then
    plugins_dir="/usr/libexec/sodalite-hacks/plugins"
    . /usr/libexec/sodalite-hacks/utils.sh
else
    die "Unable to initialize"
fi

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
    plugin_file="$plugins_dir/$plugin.sh"
    
    debug "Invoking executable '$plugin_file'"

    if [[ -f $plugin_file ]]; then
        source_plugin $plugin_file

        if { [[ $options == "--help" ]] || [[ $options == "-h" ]]; }; then
            [[ -z $_PLUGIN_TITLE ]] && _PLUGIN_TITLE="$plugin"
            [[ -z $_PLUGIN_DESCRIPTION ]] && _PLUGIN_DESCRIPTION="(No description)"
        
            say "Sodalite Hacks: $_PLUGIN_TITLE"
            say "  $_PLUGIN_DESCRIPTION"
            say "\nUsage:"
            
            if [[ ! -z $_PLUGIN_OPTIONS ]]; then
                say "  $prog $plugin [options]"
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
