#!/usr/bin/env bash

_PLUGIN_TITLE="oemconf"
_PLUGIN_DESCRIPTION="Generator for /etc/oem.conf"
_PLUGIN_OPTIONS=(
    "generate;g;Generate /etc/oem.conf"
    "dry-run;;Print generated /etc/oem.conf"
)
_PLUGIN_ROOT="true"
_PLUGIN_HIDDEN="true"

OCG_LOGO_BASE_URL="https://git.zio.sh/sodaliterocks/lfs/raw/branch/main/oem-logos/"
OCG_OEMCONF_FILE="/etc/oem.conf"
OCG_OEMLOGO_FILE="/etc/oem-logo.png"

function main() {
    if [[ $generate == "true" ]]; then
        has_run="true"
        invoke_generate
    fi

    if [[ $dry_run == "true" ]]; then
        has_run="true"
        invoke_dry_run
    fi

    if [[ $has_run != "true" ]]; then
        die "No option specified (see --help)"
    fi
}

function invoke_generate() {
    say "Writing to /etc/oem.conf..."
    echo -e $(generate_oemconf) > $OCG_OEMCONF_FILE
}

function invoke_dry_run() {
    echo -e $(generate_oemconf)
}

function generate_oemconf() {
    dmidecode_type=1

    if [[ $(get_hwinfo 'Serial Number') == "To be filled by O.E.M." ]]; then
        # This is a custom build here so we'll use the motherboard info instead
        dmidecode_type=2
    fi

    hw_manufacturer=$(get_hwinfo 'Manufacturer' $dmidecode_type)
    hw_product=$(get_hwinfo 'Product Name' $dmidecode_type)
    hw_version=$(get_hwinfo 'Version' $dmidecode_type)
    hw_logo=""
    hw_url=""

    if {
        [[ $hw_version == "1.0" ]] ||
        [[ $hw_version == "Type1ProductConfigId" ]];
    }; then
        hw_version=""
    fi

    case ${hw_manufacturer,,} in
        "asus"|"asustek"*) # ASUS (ASUSTek Computer Inc.)
            hw_manufacturer="ASUS"
            hw_url="https://www.asus.com/support"
            ;;
        "dell"|"dell inc"*) # Dell (Dell Inc.)
            hw_manufacturer="Dell"
            hw_url="https://www.dell.com/support"
            ;;
        "gigabyte technology"*|"giga-byte technology"*) # GIGABYTE (Gigabyte Technology Co., Ltd)
            hw_manufacturer="GIGABYTE"
            hw_url="https://www.gigabyte.com/Support"
            ;;
        "hp"|"hewlett-packard") # HP (HP Inc.)
            hw_manufacturer="HP"
            hw_url="https://support.hp.com"
            ;;
        "msi"|"micro-star international"*) # MSI (Micro-Star International Co., Ltd)
            hw_manufacturer="MSI"
            hw_url="https://www.msi.com/support"
            ;;
        "microsoft"|"microsoft corp"*) # Microsoft (Microsoft Corp.)
            hw_manufacturer="Microsoft"
            hw_url="https://support.microsoft.com"
            ;;
        "vmware"*) # VMware (VMware, Inc.)
            hw_manufacturer="VMware"
            hw_url="https://www.vmware.com/support"
            ;;
        "acer")
            hw_url="https://acer.com/support"
            ;;
        "apple")
            hw_url="https://support.apple.com"
            ;;
        "huawei")
            hw_url="https://consumer.huawei.com" # No canon URL to support site
            ;;
        "ibm"|"lenovo")
            hw_url="https://support.lenovo.com"
            ;;
        "lg")
            hw_url="https://www.lg.com/support"
            ;;
        "medion")
            hw_url="https://www.medion.com" # No canon URL to support site
            ;;
        "qemu")
            hw_url="https://www.qemu.org/docs/master"
            ;;
        "samsung")
            hw_url="https://www.samsung.com/support"
            ;;
        "system76"*)
            hw_url="https://support.system76.com"
            ;;
    esac

    if [[ $OCG_NO_HACKS != true ]]; then
        case ${hw_manufacturer,,} in # The hw_manufacturer may have been modified up above
            "asus")
                if [[ $hw_product =~ (([A-Za-z]{1,})_ASUSLaptop ([A-Za-z0-9]{1,})[_]{0,}([A-Za-z0-9]{0,})) ]]; then
                    hw_product="${BASH_REMATCH[2]}"
                    hw_version="${BASH_REMATCH[4]}"
                fi
                ;;
            "dell")
                if [[ $hw_product =~ (Dell System ([A-Za-z0-9\-\ ]{1,})) ]]; then
                    hw_product="${BASH_REMATCH[2]}"
                fi
                ;;
            "google") # Chromebook's (are annoying)
                if [[ $hw_manufacturer == "GOOGLE" ]]; then
                    hw_version=$hw_product
                    hw_manufacturer="Google"
                    hw_product="Chromebook"
                fi
                ;;
            "hp")
                if [[ $hw_product == HP* ]]; then
                    if [[ $hw_product =~ (HP ([A-Za-z0-9\ ]{1,})-([A-Za-z0-9]{1,})) ]];then
                        hw_product="${BASH_REMATCH[2]}"
                        hw_version="${BASH_REMATCH[3]}"
                    fi
                fi
                ;;
            "microsoft")
                [[ $hw_product == "Virtual Machine" ]] && hw_product="Hyper-V VM"
                ;;
            "msi")
                if [[ $hw_product =~ ((.+) \(([A-Za-z0-9\-]{1,})\)) ]]; then
                    hw_product="${BASH_REMATCH[2]}"
                    hw_version="${BASH_REMATCH[3]}"
                fi
                ;;
        esac
    fi

    if [[ $OPT == "dry-run" ]]; then
        hw_logo=$OCG_OEMLOGO_FILE
    else
        hw_logo=$(get_logo ${hw_manufacturer,,})
    fi

    oem_file_content="[OEM]\n"
    [[ ! -z $hw_manufacturer ]] && oem_file_content+="Manufacturer=$hw_manufacturer\n"
    [[ ! -z $hw_product ]] && oem_file_content+="Product=$hw_product\n"
    [[ ! -z $hw_version ]] && oem_file_content+="Version=$hw_version\n"
    [[ ! -z $hw_logo ]] && oem_file_content+="Logo=$hw_logo\n"
    [[ ! -z $hw_url ]] && oem_file_content+="URL=$hw_url"

    echo $oem_file_content
}

function get_cpu_vendor() {
    cpu_vendor=$(cat /proc/cpuinfo | grep vendor_id | uniq)
    cpu_vendor=${cpu_vendor#*\:}

    echo $cpu_vendor
}

function get_logo() {
    manufacturer=$1
    url="$OCG_LOGO_BASE_URL$manufacturer.png"

    http_code=$(curl -s -o /dev/null --head -w "%{http_code}" $url)

    if { [[ $http_code == "2"* ]] || [[ $http_code == "3"* ]]; }; then
        curl $url \
            --output $OCG_OEMLOGO_FILE \
            --silent

        echo $OCG_OEMLOGO_FILE
    else
        rm -rf $OGC_OEM_LOGO_FILE
    fi
}

function get_hwinfo() {
    key=$1
    type=$2

    [[ -z $type ]] && type="1"

    value=$(dmidecode -t$type | grep "$key:" | sed 's/\t'"${key}"': //g')

    if [[ -z value ]]; then
        echo "Unknown $key"
    else
        echo $value
    fi
}
