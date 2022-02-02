#!/usr/bin/env bash

_PLUGIN_TITLE="Cleanup"
_PLUGIN_DESCRIPTION="Remove various system junk files"
_PLUGIN_OPTIONS=(
    "all;a;Cleanup everything (runs all options)"
    "flatpak;;Remove Flatpak unused packages"
    "rost-cache;;Remove rpm-ostree cache and temporary data"
    "rost-deployments;;Remove rpm-ostree pending and rollback deployments"
)
_PLUGIN_ROOT="true"

function main() {
    has_run="false"

    if [[ $all == "true" ]]; then
        has_run="true"
        
        flatpak="true"
        rost_cache="true"
        rost_deployments="true"
    fi
    
    if [[ $flatpak == "true" ]]; then
        has_run="true"
        say "Removing Flatpak unused packages..."
        flatpak uninstall --noninteractive --unused
    fi
    
    if [[ $rost_cache == "true" ]]; then
        has_run="true"
        say "Removing rpm-ostree cache and temporary data..."
        rpm-ostree cleanup --base --repomd
    fi
    
    if [[ $rost_deployments == "true" ]]; then
        has_run="true"
        say "Removing rpm-ostree pending and rollback deployments..."
        rpm-ostree cleanup --pending --rollback
    fi
    
    if [[ $has_run == "false" ]]; then
        die "No option specified (see --help)"
    fi
}
