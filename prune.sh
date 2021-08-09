#!/usr/bin/env bash
# script to prune local backups old than 30 days
#
# NB: This is a PITA as each APP's full backup start on the month day
#     it was created. Then all of the differential files, one for each
#     day until the start of the next month.

set -u          # no unset variabled
set -e          # exit on any command failure
set -o pipefail # exit if any command in a pipe fails

# constants
_script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
_local_backup_dir="${_script_dir}/backups"

# main code starts here
_array_backup_apps=("${_local_backup_dir}"/*)

for _eleement_filename in "${_array_backup_apps[@]}"; do
    # Cut the name of the last directory the path, this is the user name
    #_user=$(basename "${_user}")
    #echo "User: $sites"

    # Split the line into array elements using _ as the deliminator
    IFS='_' read -r -a array <<<"$_eleement_filename"
    # Print each element
    _appname=${array[0]#"${_local_backup_dir}/"} #remove path from begining of string
    #echo "APP name      : ${_appname}"
    #echo "Month or date : ${array[1]}"
    #echo "Type of backup: ${array[2]}"

    # if this is a full backup, print it's backup date
    if [ "${array[2]}" = "full.7z" ]; then
        echo -e "\n${_appname} is a full backup file - month created: ${array[1]:4}"
        # print file modified date
        _creation_date=$(date -r "${_eleement_filename}" +"%Y-%m-%d")
        echo "Full file creation date is: $_creation_date"

        d1=$(date -d "$_creation_date" +%s)
        d2=$(date -d "00:00" +%s) #time now in seconds
        _diff=$((d2 - d1)) # date math :-)
        _diff=$((_diff / 86400)) # convert to days
        echo "This backup is ${_diff} days old"

    fi
done
