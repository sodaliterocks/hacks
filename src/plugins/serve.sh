#!/usr/bin/env bash

_PLUGIN_TITLE="HTTP Server"
_PLUGIN_DESCRIPTION="..."
_PLUGIN_OPTIONS=(
    "directory;d;Directory to serve"
    "port;p;Port to listen to"
)
_PLUGIN_HIDDEN="true"

function main() {
    [[ $directory == "" ]] || [[ $directory == "true" ]] && directory="."
    [[ $port == "" ]] || [[ $port == "true" ]] && port="8080"

    python -m http.server --bind 0.0.0.0 --directory $directory $port
}
