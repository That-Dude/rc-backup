#!/usr/bin/env bash
# script to backup Apps (vhosts) on runcloud servers to an S3 bucket

set -u          # no unset variabled
set -e          # exit on any command failure
set -o pipefail # exit if any command in a pipe fails
#trap 'echo "Error in function $FUNCNAME at line $LINENO"; exit 1' ERR

# *** User variables here ***
_target_bucket="s3backup/rcuser2-bucket/"

# *** Constants ***
_runcloud_user_dir="/home"
_apps_root_dir="webapps"
_today=$(date +%Y-%m-%d-%H%M%S)
_month=$(date +%Y%m)
_script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
_local_backup_dir="${_script_dir}/backups"
_bin="${_script_dir}/bin"
_exclude_files_list="${_script_dir}/exclude.lst"
_logfile_path="${_script_dir}/logs"
_logfile_name="$(date +%Y-%m-%d)_$(date +%H-%M-%S)-rc_backup.log"

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

###############################################################################
# Function: _calc_execution_time - used to time calls
#
# e.g _calc_execution_time _myvar=$(sleep 1)
###############################################################################
_calc_execution_time() {
    local start
    start=$(date +%s)
    "$@"
    local exit_code=$?
    _loggit "Execution time: ~$(($(date +%s) - start)) seconds. exited with ${exit_code}"
    return $exit_code
}

###############################################################################
# Main
###############################################################################
_loggit ""
_loggit "██████╗  ██████╗      ██████╗  █████╗  ██████╗██╗  ██╗██╗   ██╗██████╗ "
_loggit "██╔══██╗██╔════╝      ██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██║   ██║██╔══██╗"
_loggit "██████╔╝██║     █████╗██████╔╝███████║██║     █████╔╝ ██║   ██║██████╔╝"
_loggit "██╔══██╗██║     ╚════╝██╔══██╗██╔══██║██║     ██╔═██╗ ██║   ██║██╔═══╝ "
_loggit "██║  ██║╚██████╗      ██████╔╝██║  ██║╚██████╗██║  ██╗╚██████╔╝██║     "
_loggit "╚═╝  ╚═╝ ╚═════╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝     "
_loggit "Pre-flight checks" -info

# Check root access
if ((${EUID:-0} || "$(id -u)")); then
  _loggit "This script must be run as roo!"
else
  _loggit "Root access confirmed"
fi

###############################################################################
# Check that required binaries exist and are executable
###############################################################################
mkdir -p "${_bin}"
if [ -f "${_bin}/7zz" ]; then
    _loggit "Tool: 7zz - present"
    chmod +x "${_bin}/7zz"
else
    _loggit "Tool: 7zz not found in: ${_bin}"
    _7zip_download_ver="7z2301-linux-x64.tar.xz"
    wget -O "${_bin}/7z2301-linux-x64.tar.xz" "https://7-zip.org/a/${_7zip_download_ver}"
    cd "${_bin}"
    tar -xf "${_7zip_download_ver}" 7zz
    rm "${_7zip_download_ver}"
    cd "${_script_dir}"
fi

if [ -f "${_bin}/mc" ]; then
    _loggit "Tool: minio client - present"
    chmod +x "${_bin}/mc"
else
    _loggit "Tool: minio client not found in: ${_bin}"
    wget -O "${_bin}/mc" "https://dl.minio.io/client/mc/release/linux-amd64/mc"
    chmod +x "${_bin}/mc"
    _loggit "Minio client downloaded - now configre your S3 backup and run this script again"
    exit 1
fi

hash wp 2>/dev/null || {
    echo >&2 "Word-press CLI required but it's not installed.  Aborting."
    exit 1
}

###############################################################################
# Check directories
###############################################################################
# Are we running from the correct folder?
if [ "${_script_dir}" != "/root/rc-backup" ]; then
    _loggit "- INFO: Sctipt folder: ${_script_dir}"
    _loggit "- FATAL: This script should be in /root/rc-backup"
    exit 1
fi

mkdir -p "${_bin}"
mkdir -p "${_local_backup_dir}"
mkdir -p "${_local_backup_dir}/${_month}"

# Check RunCloud user directory exisits
if [ ! -d "${_runcloud_user_dir}" ]; then
    _loggit "RunCloud user directory does not exisit: ${_runcloud_user_dir}" -error
    exit 1
fi

# Check there are RunCloud users in the RunCloud user directory
_subdircount=$(find "${_runcloud_user_dir}" -maxdepth 1 -type d | wc -l)
if [[ "${_subdircount}" -eq 1 ]]; then
    _loggit "No runcloud users in ${_runcloud_user_dir}" -error
    exit 1
fi

# Check if list of files to exclude exsits
if [ -f "${_exclude_files_list}" ]; then
    _loggit "tar exlude file found: ${_yellow} ${_exclude_files_list} ${_no_color}"
else
    _loggit "No tar exlude file: ${_exclude_files_list}" -warning
fi

# Generate a list of files in the storage bucket and save it locally
#_loggit "Dumping files from backup storage to ${_script_dir}/${_bucket_file_list}"
#"${_script_dir}"/mc ls "${_target_bucket}" >"${_script_dir}/${_bucket_file_list}"

###############################################################################
# Generate array of RunCloud users and log them
###############################################################################

# generate an array of users from RunCloud users directory
_runcloud_users=("${_runcloud_user_dir}"/*/)
_loggit "There are ${#_runcloud_users[@]} users in ${_yellow} ${_runcloud_user_dir} ${_no_color}"
# print the user list
for _user in "${_runcloud_users[@]}"; do
    # Cut the name of the last directory the path, this is the user name
    _user=$(basename "${_user}")
    _loggit "User:${_yellow} ${_user} ${_no_color}" -logonly
done

###############################################################################
# Interate through RC users and their Apps
###############################################################################

for _user_directory in "${_runcloud_users[@]}"; do
    _loggit "Processing user folder: ${_green}${_user_directory}${_apps_root_dir}${_no_color}" -info

    # Check if user folder is empty (ie no runcloud apps for this user)
    _subdircount=$(find "${_user_directory}${_apps_root_dir}" -maxdepth 1 -type d | wc -l)
    if [[ "${_subdircount}" -eq 1 ]]; then
        _loggit "\n- WARNING: No Apps to backup in ${_user_directory}${_apps_root_dir}" -warning
        continue
    fi

    # Generate array of Apps for each user
    _applist=("${_user_directory}${_apps_root_dir}"/*/)
    # start the loop
    for _app in "${_applist[@]}"; do
        _app_name=$(basename "${_app}")
        _loggit "backing up runcloud app: ${_green}${_app_name}${_no_color}"

        _user=$(basename "${_user_directory}")

        _siteurl="empty"
        # Check to see if this APP is a wordpress site
        if [ -f "${_app}wp-config.php" ]; then

            # backup wordpress
            _loggit "This is a Wordpress APP"

            # get the siteurl
            _siteurl=$(sudo -u "${_user}" -i -- wp --path="${_app}" option get siteurl)
            _siteurl=${_siteurl#*//} #removes stuff upto // from begining
            _loggit "The site URL is: ${_green}${_siteurl}${_no_color}"

            # dump WP database
            _loggit "Export the Wordpress database to: ${_green}${_app}/${_siteurl}.sql${_no_color}"
            sudo -u "${_user}" -i -- wp --path="${_app}" --quiet db export "${_app}/${_siteurl}.sql"
        else
            # backup static site
            _loggit "This is a static website with no database to dump" -blue
        fi

        # compress the APP files and store in temp folder
        cd "${_user_directory}${_apps_root_dir}/${_app_name}"
        _full_backup_filename="${_local_backup_dir}/${_month}/${_app_name}/${_app_name}_${_month}_full.7z"

        if [ ! -f "${_full_backup_filename}" ]; then #no full backup for this month
            _loggit "Creating FULL backup to: ${_green}${_full_backup_filename}${_no_color}"
            "${_bin}"/7zz a "${_full_backup_filename}" . -x@"${_exclude_files_list}"
            _loggit "Copying ${_green}${_full_backup_filename}${_no_color} to S3" -bold
            # copy it to s3
            "${_bin}"/mc -no-color cp "${_full_backup_filename}" "${_target_bucket}/${_app_name}/"

        else
            _differential_backup_filename="${_local_backup_dir}/${_month}/${_app_name}/${_app_name}_${_today}_differential.7z"
            _loggit "Creating DIFFERENTIAL backup to: ${_green}${_differential_backup_filename}${_no_color}"
            _loggit "---- 7zip START ----" -blue
            # Switch -ms=off: Disable solid mode
            # -t7z = create a 7zip archive
            # -u- existing .7z archive will not be changed.
            # p0 - If "File exists in archive, but is not matched with wildcard" then remove the file from the archive.
            # q3 - If "File exists in archive, but doesn't exist on disk" then remove the file from the archive and remove it from the filesystem upon extraction.
            # r2 - If "File doesn't exist in archive, but exists on disk" then pack the file into the archive.
            # x2 - If "File in archive is newer than the file on disk" then "compress file from disk to new archive".
            # y2 - If "File in archive is older than the file on disk" then pack the newer file into the archive.
            # z1 - If "File in archive is same as the file on disk" then reuse the packed version of the file.
            # w2 - If file size is different then pack the modified file into the archive.
            "${_bin}"/7zz u "${_full_backup_filename}" . -t7z -u- -up0q3r2x2y2z0w2\!"${_differential_backup_filename}" -x@"${_exclude_files_list}"
            _loggit "---- 7zip END ----" -blue
            # if the differental backup file contains no changes delete it
            "${_bin}"/7zz l "${_differential_backup_filename}" >"/tmp/diff_files.txt"
            _grep_search=$(grep -F -e"....A" -e"D...." "/tmp/diff_files.txt") || true
            if [ -z "$_grep_search" ]; then
                _loggit "No changes in this differential backup file - deleting"
                rm "${_differential_backup_filename}"
            else
                _loggit "Copying ${_green}${_differential_backup_filename}${_no_color} to S3" -bold
                # copy it to s3
                "${_bin}"/mc -no-color cp "${_differential_backup_filename}" "${_target_bucket}/${_app_name}/"
                #>>"${_logfile_path}/${_logfile_name}"
            fi
        fi
        #remove the sql file
        if [ -f "${_app}/${_siteurl}.sql" ]; then
            _loggit "deleteing temporary Wordpress database dump ${_green}${_app}/${_siteurl}.sql${_no_color}"
            rm "${_app}${_siteurl}.sql"
        fi
    done
done

# Delete old local backs to conserve diskspace - UNTESTED
#_loggit "Delete local backups over 31 days old"
#find ~/rc-backup/backups -type f -mtime +31 -delete

_loggit "All backup operations complete" -blue
