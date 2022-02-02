#!/usr/bin/env bash

_PLUGIN_TITLE="Nvidia"
_PLUGIN_DESCRIPTION="Manage proprietary Nvidia drivers"
_PLUGIN_OPTIONS=(
    "install;i;Install proprietary Nvidia drivers"
    "uninstall;u;Uninstall proprietary Nvidia drivers"
    "force;f;Force usage even if no Nvidia GPUs are detected"
    "driver;d;Select which driver to install (defaults to 495)"
)
_PLUGIN_ROOT="true"

driver_packages="akmod-nvidia xorg-x11-drv-nvidia-cuda"

function main() {
    if [[ $install == "true" ]]; then
        has_run="true"
        
        case $driver in
            "495"|"latest"|"true"|"")
                driver_packages="akmod-nvidia xorg-x11-drv-nvidia-cuda"
                ;;
            "470")
                driver_packages="akmod-nvidia-470xx xorg-x11-drv-nvidia-470xx-cuda"
                ;;
            "390")
                driver_packages="akmod-nvidia-390xx xorg-x11-drv-nvidia-390xx-cuda"
                ;;
            "340")
                driver_packages="akmod-nvidia-340xx xorg-x11-drv-nvidia-340xx-cuda"
                ;;
            *)
                die_message="Invalid --driver selection, choose either:\n"
                die_message+=" - 495/latest: current GeForce/Quadro/Tesla\n"
                die_message+=" - 470: legacy GeForce 600/700\n"
                die_message+=" - 390: legacy GeForce 400/500\n"
                die_message+=" - 340: legacy GeForce 8/9/200/300 (EOL)"

                die $die_message
                ;;
        esac
        
        invoke_install
    fi
    
    if [[ $uninstall == "true" ]]; then
        has_run="true"
        invoke_uninstall
    fi
    
    if [[ $has_run != "true" ]]; then
        die "No option specified (see --help)"
    fi
}

function invoke_install() {
    check_nvidia_gpu

    if [[ ! -f /etc/yum.repos.d/rpmfusion-nonfree.repo ]]; then
        echo "Installing RPMFusion repos..."
        rpm-ostree install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    fi
    
    echo "Installing Nvidia packages..."
    rpm-ostree install $driver_packages
    
    echo "Setting kernel arguments..."
    rpm-ostree kargs --append=rd.driver.blacklist=nouveau --append=modprobe.blacklist=nouveau --append=nvidia-drm.modeset=1
    
    echo "Reboot required after installation."
}

function invoke_uninstall() {
    check_nvidia_gpu
    die "Not implemented"
}

function check_nvidia_gpu() {
    if [[ $force != "true" ]]; then
        if [[ ! -d /proc/drivers/nvidia ]]; then
            die "No Nvidia GPU detected (use --force to override)"
        fi
    fi
}
