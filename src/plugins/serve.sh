#!/usr/bin/env bash

_PLUGIN_TITLE="HTTP Server"
_PLUGIN_DESCRIPTION="Serve static files over HTTP"
_PLUGIN_OPTIONS=(
    "directory;d;Directory to serve"
    "port;p;Port to listen on"
)
_PLUGIN_HIDDEN="true"

function main() {
    if [[ $directory == "" ]] && \
        [[ $port == "" ]] && \
        [[ $options != "" ]]; then
        if [[ "$options" =~ ^([^ ]+)( ([0-9]+)){0,1}$ ]]; then
            directory="${BASH_REMATCH[1]}"
            port="${BASH_REMATCH[3]}"
        else
            die "Invalid positional paramenters"
        fi
    fi

    [[ $directory == "" ]] || [[ $directory == "true" ]] && directory="."
    [[ $port == "" ]] || [[ $port == "true" ]] && port="8080"

    ! [[ -d $directory ]] && die "Directory '$directory' does not exist"

    if { ! [[ $port =~ ^[0-9]+$ ]] || (( $port < 1 || $port > 65535 )); }; then
        die "Port '$port' is not a valid port"
    fi

    python -m http.server --bind 0.0.0.0 --directory $directory $port

    [[ $? != 0 ]] && die "Unable to start server"
}
