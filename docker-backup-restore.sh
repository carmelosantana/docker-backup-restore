#!/bin/bash
# version 0.1.0

# Script will commit and save images to tar
# Run this script on the host machine, not inside a container, check if we're inside a docker container
# Script will create a backups folder in the current directory, or specified directory.
# Script will creare directories inside hostname/date/.
# All backups will be stored in the current date folder.
# Script can create a tar file for container
# Script can remove all tar files older than $expire_days.
# Script can remove all empty directories.
# Script can remove all dangling images

# https://docs.docker.com/desktop/backup-and-restore/
# How to back up and restore your Docker Desktop data
# Use the following procedure to save and restore your images and container data. This is useful if you want to reset your VM disk or to move your Docker environment to a new computer, for example.
# Should I back up my containers?
# If you use volumes or bind-mounts to store your container data, backing up your containers may not be needed, but make sure to remember the options that were used when creating the container or use a Docker Compose file if you want to re-create your containers with the same configuration after re-installation.
# Save your data
# Commit your containers to an image with docker container commit.
# Committing a container stores the container filesystem changes and some of the container's configuration, for example labels and environment-variables, as a local image. Be aware that environment variables may contain sensitive information such as passwords or proxy-authentication, so care should be taken when pushing the resulting image to a registry.
# Also note that filesystem changes in volume that are attached to the container are not included in the image, and must be backed up separately.
# If you used a named volume to store container data, such as databases, refer to the back up, restore, or migrate data volumes page in the storage section.
# Use docker push to push any images you have built locally and want to keep to the Docker Hub registry.
# Make sure to configure the repository's visibility as "private" for images that should not be publicly accessible.
# Alternatively, use docker image save -o images.tar image1 [image2 ...] to save any images you want to keep to a local tar file.
# After backing up your data, you can uninstall the current version of Docker Desktop and install a different version or reset Docker Desktop to factory defaults.
# Restore your data
# Use docker pull to restore images you pushed to Docker Hub.
# If you backed up your images to a local tar file, use docker image load -i images.tar to restore previously saved images.
# Re-create your containers if needed, using docker run, or Docker Compose.
# Refer to the backup, restore, or migrate data volumes page in the storage section to restore volume data.

# Arguments:
# Usage: ./docker-backup-restore.sh [options]
# Options:
# -b    Run backup. (default: true)
# -d    Backup directory. (default: ./backups)
# -D    Dry run. (default: false)
# -m    Interactive menu. (default: true)
# -r    Restore images. (default: false)
# -p    Purge backups. (default: false)
# -dd   Delete dangling images. (default: false)
# -u    User to update permissions. (default: $SUDO_USER)
# -v    Verbose output. (default: false)
# -h    Display help menu

# Set default values
backup=true
menu=true
backup_directory=./backups
dry_run=false
restore=false
purge=false
delete_dangling=false
verbose=false
remove_old=true
expire_days=7

# Parse arguments
while getopts "b:d:Dm:rpu:vh" opt; do
    case $opt in
    b)
        backup=$OPTARG
        ;;
    d)
        backup_directory=$OPTARG
        ;;
    D)
        dry_run=true
        ;;
    m)
        menu=$OPTARG
        ;;
    r)
        restore=$OPTARG
        ;;
    p)
        purge=$OPTARG
        ;;
    dd)
        delete_dangling=$OPTARG
        ;;
    u)
        user=$OPTARG
        ;;
    v)
        verbose=true
        ;;
    h)
        echo "Usage: ./docker-backup-restore.sh [options]"
        echo "Options:"
        echo "-b    Run backup. (default: true)"
        echo "-d    Backup directory. (default: ./backups)"
        echo "-D    Dry run. (default: false)"
        echo "-m    Interactive menu. (default: true)"
        echo "-r    Restore images. (default: false)"
        echo "-p    Purge backups. (default: false)"
        echo "-dd   Delete dangling images. (default: false)"
        echo "-u    User to update permissions. (default: $SUDO_USER)"
        echo "-v    Verbose output. (default: false)"
        echo "-h    Display help menu"
        exit 0
        ;;
    \?)
        echo "Invalid option: $OPTARG" 1>&2
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument." 1>&2
        exit 1
        ;;
    esac
done

# function to perform init checks
# Check if sudo or root
# Check if docker is installed
# Check if backup directory (with hostname and date) exixts, if not create it
# if any DIR does not exist, we error out
init() {
    # check for trailing slash, if present remove it
    if [[ "$backup_directory" == */ ]]; then
        backup_directory="${backup_directory%?}"
    fi
    # Add hostname to backup directory
    backup_directory=$backup_directory/$(hostname)

    # Add date to backup directory
    backup_directory=$backup_directory/$(date +%Y-%m-%d)

    # Check if backup directory exists, if not create it
    if [ ! -d "$backup_directory" ]; then
        if [ "$verbose" = true ]; then
            echo "Creating directory: $backup_directory"
        fi
        mkdir -p $backup_directory

        # Check if dirs exist, if not error out
        if [ ! -d "$backup_directory" ]; then
            echo "Backup directories do not exist, please check and run the script again."
            exit 1
        fi
    fi

    # Check if we have permission to write to backup directory
    if [ ! -w "$backup_directory" ]; then
        echo "No write permission to backup directory, please check and run the script again."
        exit 1
    fi
}

# Interactive menu if no arguments are passed
# User can select actions to perform
# If user is backingup we present user with a list of container names to select, or backup all containers
# If user is restoring we present user with a list of tar files to select, or restore all tar files, from backup DIR or specified DIR
# Function menu()
menu() {
    echo "Select an option:"
    echo "1) Backup"
    echo "2) Restore"
    echo "3) Purge backups"
    echo "4) Delete dangling images"
    echo "5) Exit"
    read -p "Enter option: " option

    case $option in
    1)
        select_containers
        backup_commit_image
        delete_dangling_images
        remove_old_backups
        ;;
    2)
        restore
        ;;
    3)
        remove_old_backups
        ;;
    4)
        delete_dangling_images
        ;;
    5)
        exit 0
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
    esac
}

# Allow user to select containers to backup
select_containers() {
    # Get list of containers
    containers=$(docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}")

    # Present user with list of containers
    echo "Select containers to backup:"
    echo "$containers"
    read -p "Enter container ID or name to backup: " container_select
}

backup_commit_image() {
    # Check if container_select is set, if yes commit only selected containers, if no commit all containers
    if [ -z "$container_select" ]; then
        containers=$(docker ps -a -q)
    else
        containers=$(echo $container_select | tr "," "\n")
    fi

    for container in $containers; do
        if [ "$verbose" = true ]; then
            echo "Committing container: $container"
        fi

        # add container name to image
        container_name=$(docker inspect --format='{{.Name}}' $container | sed 's/\///g')
        img_name=$(docker inspect --format='{{.Config.Image}}' $container)

        backup_file="$backup_directory/$container_name-$container.tar"
        cmd="docker commit $container $img_name"

        if [ "$dry_run" = false ]; then
            $cmd
        else
            echo "docker commit $container $img_name"
        fi

        if [ "$verbose" = true ]; then
            echo "Backing up image: $img_name"
        fi

        backup_file="$backup_directory/$container_name-$container.tar"

        # Alternatively, use docker image save -o images.tar image1 [image2 ...] to save any images you want to keep to a local tar file.
        if [ "$dry_run" = false ]; then
            docker save $img_name -o $backup_file
        else
            echo "docker save $img_name -o $backup_file"
        fi
    done

}

# Function to delete dangling images
delete_dangling_images() {
    if [ "$delete_dangling" = true ]; then
        if [ "$dry_run" = false ]; then
            docker rmi $(docker images -f "dangling=true" -q)
        else
            echo "docker rmi $(docker images -f "dangling=true" -q)"
        fi
    fi
}

# Function to remove empty directories
remove_empty_directories() {
    find $backup_directory -type d -empty -delete
}

# Function to remove old backups
remove_old_backups() {
    if [ "$remove_old" = true ]; then
        # if Dry run
        if [ "$dry_run" = false ]; then
            find $backup_directory -type f -name "*.tar" -mtime +$expire_days -delete
        else
            echo "find $backup_directory -type f -name "*.tar" -mtime +$expire_days -delete"
        fi
    fi
    remove_empty_directories
}

# Function to restore images
restore() {
    # Get list of tar files
    tar_files=$(find $backup_directory -type f -name "*.tar")

    # Present user with list of tar files
    # Echo folder date at the top
    # Then list only the base file name
    # User can copy and paste the base name "file.tar"
    # We will create the full path to the tar file
    echo "Backup directory: $backup_directory"
    echo "Select tar file to restore:"
    echo "Folder: $(basename $backup_directory)"
    echo "$tar_files" | awk -F/ '{print $NF}'
    read -p "Enter tar file to restore: " tar_file

    # Create full path to tar file
    tar_file="$backup_directory/$tar_file"

    # Check if tar file exists
    if [ ! -f "$tar_file" ]; then
        echo "Tar file does not exist, please check and run the script again."
        exit 1
    fi

    # Restore tar file
    docker load -i $tar_file
}

# Main function
main() {
    # Setup
    init

    # Interactive menu
    if [ "$menu" = true ]; then
        menu
    fi

    # Are we backing up, or restoring
    if [ "$backup" = true ]; then
        backup_commit_image
    fi

    if [ "$restore" = true ]; then
        restore
    fi

    if [ "$purge" = true ]; then
        remove_old_backups
    fi

    if [ "$delete_dangling" = true ]; then
        delete_dangling_images
    fi

    if [ "$verbose" = true ]; then
        echo "Backup directory: $backup_directory"
    fi

    # End of script
    exit 0
}

# Run main function
main
