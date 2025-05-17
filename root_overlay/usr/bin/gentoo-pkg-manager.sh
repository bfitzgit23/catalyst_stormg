#!/bin/bash
# Gentoo Package Manager GUI - Complete Version

# Fixed window size
window_width=800
window_height=600
verbose_mode=false

# Function to enable verbose output
verbose_output() {
    local command="$1"
    if [ "$verbose_mode" = true ]; then
        echo -e "\n\e[1;33mVERBOSE OUTPUT:\e[0m"
        eval "$command"
    fi
}

# Function to prompt for sudo password
get_sudo_password() {
    sudo_password=$(yad --title "Authentication Required" --entry --hide-text \
        --text="Enter your sudo password:" --button="OK:0" --button="Cancel:1" \
        --width=$window_width --height=$window_height)
    [ $? -ne 0 ] && exit 1
    echo "$sudo_password"
}

# Function to run commands with sudo
run_with_sudo() {
    local cmd="$1"
    local password=$(get_sudo_password)
    echo "$password" | sudo -S bash -c "$cmd" 2>&1
}

# Function to toggle verbose mode
toggle_verbose() {
    verbose_mode=$(yad --title "Verbose Mode" --list --radiolist \
        --column "Select" --column "Mode" \
        $([ "$verbose_mode" = true ] && echo TRUE || echo FALSE) "Enabled" \
        $([ "$verbose_mode" = false ] && echo TRUE || echo FALSE) "Disabled" \
        --width=$window_width --height=$window_height --button="OK:0")
    
    [[ "$verbose_mode" == *"Enabled"* ]] && verbose_mode=true || verbose_mode=false
}

# Function to search for packages
search_packages() {
    search_term=$(yad --title "Search Packages" --entry --text "Enter package name or keyword:" \
        --button="OK:0" --button="Cancel:1" --width=$window_width --height=$window_height)
    [ $? -eq 0 ] || return
    
    results=$(eix "$search_term")
    verbose_output "eix '$search_term'"
    yad --title "Search Results" --text-info --width=$window_width --height=$window_height \
        --button="Close:0" <<< "$results"
}

# Function to install a package
install_package() {
    package=$(yad --title "Install Package" --entry --text "Enter package name to install:" \
        --button="OK:0" --button="Cancel:1" --width=$window_width --height=$window_height)
    [ $? -eq 0 ] || return
    
    emerge_output=$(run_with_sudo "emerge -av $package")
    verbose_output "emerge -av $package"
    yad --title "Installation Log" --text-info --width=$window_width --height=$window_height \
        --button="Close:0" <<< "$emerge_output"
}

# Function to remove a package
remove_package() {
    package=$(yad --title "Remove Package" --entry --text "Enter package name to remove:" \
        --button="OK:0" --button="Cancel:1" --width=$window_width --height=$window_height)
    [ $? -eq 0 ] || return
    
    emerge_output=$(run_with_sudo "emerge -Cav $package")
    verbose_output "emerge -Cav $package"
    yad --title "Removal Log" --text-info --width=$window_width --height=$window_height \
        --button="Close:0" <<< "$emerge_output"
}

# Function to update packages
update_packages() {
    emerge_output=$(run_with_sudo "emerge -avuDN @world")
    verbose_output "emerge -avuDN @world"
    yad --title "Update Log" --text-info --width=$window_width --height=$window_height \
        --button="Close:0" <<< "$emerge_output"
}

# Function to sync Portage tree
sync_portage() {
    sync_choice=$(yad --title "Sync Portage Tree" --form \
        --field="Select Sync Mode:CB" "Verbose!Quiet" \
        --button="OK:0" --button="Cancel:1" --width=$window_width --height=$window_height)
    [ $? -eq 0 ] || return
    
    case $sync_choice in
        "Verbose|")
            emerge_output=$(run_with_sudo "emerge --sync")
            verbose_output "emerge --sync"
            ;;
        "Quiet|")
            emerge_output=$(run_with_sudo "emerge --sync --quiet")
            ;;
        *) return ;;
    esac
    
    yad --title "Sync Log" --text-info --width=$window_width --height=$window_height \
        --button="Close:0" <<< "$emerge_output"
}

# Function to clear package cache
clear_pkg_cache() {
    confirm=$(yad --title "Clear Package Cache" --question \
        --text="Are you sure you want to clear the package cache?\nThis will remove files from /var/cache/binpkgs and /var/cache/distfiles." \
        --button="Yes:0" --button="No:1" --width=$window_width --height=$window_height)
    [ $? -eq 0 ] || return
    
    clear_output=$(run_with_sudo "rm -rf /var/cache/binpkgs/* /var/cache/distfiles/*")
    verbose_output "rm -rf /var/cache/binpkgs/* /var/cache/distfiles/*"
    yad --title "Clear Cache Log" --text-info --width=$window_width --height=$window_height \
        --button="Close:0" <<< "$clear_output"
}

# Function to clear Catalyst build directory
clear_catalyst() {
    confirm=$(yad --title "Clear Catalyst Build Directory" --question \
        --text="Are you sure you want to clear the Catalyst build directory?\nThis will remove files from /var/tmp/catalyst." \
        --button="Yes:0" --button="No:1" --width=$window_width --height=$window_height)
    [ $? -eq 0 ] || return
    
    clear_output=$(run_with_sudo "rm -rf /var/tmp/catalyst/*")
    verbose_output "rm -rf /var/tmp/catalyst/*"
    yad --title "Clear Catalyst Log" --text-info --width=$window_width --height=$window_height \
        --button="Close:0" <<< "$clear_output"
}

# Main menu
main_menu() {
    while true; do
        choice=$(yad --title "Gentoo Package Manager" --form \
            --field="Select Action:CB" "Search!Install!Remove!Update!Sync!Clear Cache!Clear Catalyst!Verbose Mode!Quit" \
            --button="OK:0" --button="Cancel:1" \
            --width=$window_width --height=$window_height)

        case $choice in
            "Search|") search_packages ;;
            "Install|") install_package ;;
            "Remove|") remove_package ;;
            "Update|") update_packages ;;
            "Sync|") sync_portage ;;
            "Clear Cache|") clear_pkg_cache ;;
            "Clear Catalyst|") clear_catalyst ;;
            "Verbose Mode|") toggle_verbose ;;
            "Quit|"|*) exit 0 ;;
        esac
    done
}

# Start main menu
main_menu
