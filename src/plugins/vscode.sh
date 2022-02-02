#!/usr/bin/env bash

_PLUGIN_TITLE="Visual Studio Code"
_PLUGIN_DESCRIPTION="Manage installation of Visual Studio Code"
_PLUGIN_OPTIONS=(
    "install;i;Install Visual Studio Code"
    "uninstall;u;Uninstall Visual Studio Code"
)
_PLUGIN_ROOT="true"

repo_content="[microsoft-vscode]
\nname=Visual Studio Code
\nbaseurl=https://packages.microsoft.com/yumrepos/vscode
\nenabled=1
\ngpgcheck=1
\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc"
repo_file="/etc/yum.repos.d/microsoft-vscode.repo"

function main() {
    if [[ $install == "true" ]]; then
        has_run="true"

        say $repo_content > $repo_file
        rpm-ostree install code
        
        if [[ $? -eq 0 ]]; then
            rost_apply_live
        else
            rm -f $repo_file
            die "Installation failed"
        fi
    fi
    
    if [[ $uninstall == "true" ]]; then
        has_run="true"
        
        rpm-ostree uninstall code
        
        if [[ $? -eq 0 ]]; then
            rm -f $repo_file
            rost_apply_live
        else
            die "Uninstallation failed"
        fi
    fi
    
    if [[ $has_run != "true" ]]; then
        die "No option specified (see --help)"
    fi
}
