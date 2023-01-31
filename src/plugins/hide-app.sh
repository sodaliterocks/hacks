#!/usr/bin/env bash

_PLUGIN_TITLE="Hide Application"
_PLUGIN_DESCRIPTION="Hide (or show) item from Applications menu"
_PLUGIN_OPTIONS=(
    "desktop-file;d;Application .desktop file"
    "show;s;Show item if hidden"
    "confirm-before-hiding;;Ask before hiding .desktop file"
)

function main() {
    found="false"
    found_app_name=""
    local_app_dir="$HOME/.local/share/applications"
    hidden_app_file_contents="# hidden (rocks.sodalite.hacks hide-app)"

    [[ $desktop_file == "" ]] && die "No value provided for --desktop-file"
    [[ $desktop_file != *".desktop" ]] && desktop_file="$desktop_file.desktop"

    for p in ${XDG_DATA_DIRS//:/ }; do 
        for f in $p/applications/*.desktop; do
            if [[ "$desktop_file" == "$(basename "$f")" ]]; then
                if [[ "$desktop_file" != "$HOME/.local/share/applications"* ]]; then
                    found="true"
                    #found_app_name="$(get_property $f "Name")"
                    found_app_name="$(echo $desktop_file | sed s/.desktop//)"
                    break
                fi
            fi
        done
    done

    if [[ $found == "true" ]]; then
        if [[ -f "$local_app_dir/$desktop_file" ]]; then
            if [[ $show == "true" ]]; then
                if [[ "$(cat "$local_app_dir/$desktop_file")" == "$hidden_app_file_contents" ]]; then
                    rm "$local_app_dir/$desktop_file"
                    say "Unhidden '$found_app_name'"
                else
                    die "Not hidden with hide-app. Inspect and remove '$local_app_dir/$desktop_file' manually."
                fi
            else
                die "'$found_app_name' already hidden"
            fi
        else
            [[ $show == "true" ]] && die "'$found_app_name' not hidden"
            hide="false"

            if [[ $confirm_before_hiding ]]; then
                confirm_question="Are you sure you want to hide '$found_app_name'?"

                if [[ $DISPLAY != "" ]]; then
                    zenity --question \
                        --title "Hide App" \
                        --text "$confirm_question"
                    [[ $? == 0 ]] && hide="true"
                else
                    if [[ $(get_answer "$confirm_question") == "y" ]]; then
                        hide="true"
                    fi
                fi
            else
                hide="true"
            fi

            if [[ $hide == "true" ]]; then
                touch "$local_app_dir/$desktop_file"
                echo "$hidden_app_file_contents" > "$local_app_dir/$desktop_file"
                say "Hidden '$found_app_name'"
            fi
        fi
    else
        die "No desktop file matches '$desktop_file'"
    fi
}
