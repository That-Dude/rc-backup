#!/usr/bin/env bash
# script to restore Apps (vhosts) created with rc-backup.sh

set -u          # no unset variabled
set -e          # exit on any command failure
set -o pipefail # exit if any command in a pipe fails

# *** User variables here ***
_tempfolder_name="temp555"
_script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
_logfile_path="${_script_dir}/logs"
_logfile_name="$(date +%Y-%m-%d)_$(date +%H-%M-%S)-rc_restore.log"

###############################################################################
# FUNCTION: _loggit
#
# Save message to logfile and optionally to screen with pretty icons & colours
#
# Required - declare these global vars in your script
#
#    _logfile_path="$HOME/logname.log"
#    _logfile_name="$(date +%Y-%m-%d)_$(date +%H-%M-%S)-rc_backup.log"
###############################################################################
_loggit() {
    _current_date_time="$(date +%H:%M:%S)"
    # Icons
    # codes: https://apps.timwhitlock.info/emoji/tables/unicode
    _icon_info='\xf0\x9f\x9a\x80'
    _icon_error='\xf0\x9f\x9a\xa8'
    _icon_warning='\xF0\x9F\x9A\xA7'
    _icon_delivery_truck='\xf0\x9f\x9a\x9a'

    # colours
    _red="$(tput -Txterm setaf 1)"
    _green="$(tput -Txterm setaf 2)"
    _yellow="$(tput -Txterm setaf 3)"
    _blue="$(tput -Txterm setaf 6)"
    _bold="$(tput -Txterm bold)"
    _no_color="$(tput -Txterm sgr0)"

    # Always output to log file
    mkdir -p "${_logfile_path}"
    echo -e "$_current_date_time - $1" >>"${_logfile_path}/${_logfile_name}"

    # Output to screen
    if [ -n "${2+x}" ]; then # check if var is unset
        case $2 in
        -error | -e | red)
            echo -e "\n ${_icon_error} $_current_date_time - ${_red}$1${_no_color}"
            ;;
        -blue)
            echo -e "    $_current_date_time - ${_blue}$1${_no_color}"
            ;;
        -yellow | -y | -warning)
            echo -e "\n ${_icon_warning} $_current_date_time - ${_yellow}$1${_no_color} \n"
            ;;
        -green | -info)
            echo -e "\n ${_icon_info} $_current_date_time - $1"
            ;;

        -bold)
            echo -e "\n ${_icon_delivery_truck} $_current_date_time - ${_bold}$1${_no_color}"
            ;;

        -sameline)
            # prints spaces the full width of the terminal
            printf "\r%0$(tput cols)d" 0 | tr '0' ' '
            # prints $1 to the same line
            echo -ne "\r ${_icon_info} $_current_date_time - ${_green}$1${_no_color}"
            ;;
        -logonly)
            # don't print anything to the screen
            ;;
        *)
            # if none of the options are selected above log to screen in vanilla
            echo -e "    $_current_date_time - $1"
            ;;
        esac
    else
        # if none of the options are selected above log to screen in vanilla
        echo -e "    $_current_date_time - $1"
    fi
}

function doesAnyFileExist() {
    local arg="$*"
    local files=($arg)
    [ ${#files[@]} -gt 1 ] || [ ${#files[@]} -eq 1 ] && [ -e "${files[0]}" ]
}

# *** main ***

# we need a FULL backup 7zip file to continue
if doesAnyFileExist "*full.7z"; then
    _loggit "Found 7Z FULL backup file"
    mkdir -p "${_tempfolder_name}"
    mv -- *.7z "${_tempfolder_name}/"
    _loggit "Moved 7z files to temp dir"
else
    _loggit "Missing 7z FULL backup file - Exiting..." -error
    exit 1
fi

# check for wp-config.php
if doesAnyFileExist "wp-config.php"; then
    _loggit "Found wp-config.php backup file"
    cp "wp-config.php" "${_tempfolder_name}/"
else
    _loggit "Missing wp-config.php" --error
    echo -e "\nThis script expects a fresh WP install"
    echo -e "in the directory where the script is run\n"
    exit 1
fi

# check for .htaccess file, not essental
if doesAnyFileExist ".htaccess"; then
    _loggit "Found .htaccess"
    cp ".htaccess" "${_tempfolder_name}/"
else
    _loggit "Missing htaccess" --warning
fi

# get runcloud user for this fresh WP install (we'll use this later to fix file perms)
_runcloud_user=$(pwd | cut -d / -f 3)
_loggit "Runcloud user: ${_runcloud_user}"

# get current dir
_app_dir=$(pwd)
_loggit "Current dir  : ${_app_dir}"

# get the siteurl
_siteurl=$(sudo -u "${_runcloud_user}" -i -- wp --path="${_app_dir}" option get siteurl)
# _siteurl=${_siteurl#*//} #removes stuff upto // from begining
_loggit "Site URL     : ${_siteurl}"

# clean the DB
# _siteurl=$(sudo -u "${_runcloud_user}" -i -- wp --path="${_app_dir}" --yes db clean)
# _loggit "Cleared the DB"

# delete everything except for our temp dir
find . -mindepth 1 ! -regex "^./${_tempfolder_name}\(/.*\)?" -delete
_loggit "deleteing everything on APP root folder"

# move the 7z files to the root app dir
mv "${_tempfolder_name}/"*.7z .
_loggit "Movning 7z files to root folder"

# decompress the full backup
~/rc-backup/bin/7zz x *_full.7z '-x!wp-config.php' >/dev/null 2>&1
_loggit "Decompressed FULL archive"

# decompres the DIFF if there is one
if doesAnyFileExist "*_differential.7z"; then
    _loggit "Found 7Z DIFF backup file"
    ~/rc-backup/bin/7zz x *_differential.7z '-x!wp-config.php' -aoa >/dev/null 2>&1
    _loggit "Decompressed DIFF archive"
else
    _loggit "No DIFF file found to decompress" -warn
fi

# copy .htaccess and wp-config.php to App dir
_loggit "Copy .htaccess and wp-config.php to APP dir"
cp "$_tempfolder_name/.htaccess" .
cp "$_tempfolder_name/wp-config.php" .

# fix file permisions
_loggit "Fixing file permisions for user: ${_runcloud_user}"
chown -R "${_runcloud_user}":"${_runcloud_user}" "${_app_dir}"

# import the SQL file
if doesAnyFileExist "*.sql"; then
    sql_filename=$(find . -maxdepth 1 -type f -name "*sql")
    sql_filename="${sql_filename:2}" # strip first 2 chars ./
    _loggit "SQL import file: $sql_filename"
    sudo -u "${_runcloud_user}" -i -- wp --path="${_app_dir}" db import "${_app_dir}/$sql_filename"
else
    _loggit "No SQL found to import - Exiting..." -error
    exit 1
fi

# Now extract the URL from the just imported DB
_imported_site_url=$(sudo -u "${_runcloud_user}" -i -- wp --path="${_app_dir}" option get siteurl)
_loggit "Imported site URL: ${_imported_site_url}"

#if _siteurl and _imported_site_url are equal - stop - we're done else do a search replace

_loggit "Fresh site URL: ${_siteurl}"
_loggit "Imported site URL: ${_imported_site_url}"

# search and replace
sudo -u "${_runcloud_user}" -i -- wp --path="${_app_dir}" search-replace "${_imported_site_url}" "${_siteurl}"

# double save the wp posts format
sudo -u "${_runcloud_user}" -i -- wp --path="${_app_dir}" rewrite flush
# clean-up
_loggit "Cleaning up..."
rm -f -- *.7z
rm -f -- *.sql
rm -rf "$_tempfolder_name"

_loggit "Restore complete"
