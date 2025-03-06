#!/bin/bash

# Function to install SuiteCRM

# Check and install dependencies

set -e

# Define project directory
PROJECT_DIR="/path/to/your/project"

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo "Unable to detect OS. Only Ubuntu 24.04, 22.04, Debian 11, 12"
        exit 1
    fi

    case "$OS" in
        ubuntu|debian)
            echo "OS $OS $VERSION is supported."
            ;;
        *)
            echo "OS $OS is not supported. Exiting."
            exit 1
            ;;
    esac
}

# Get user input
get_input() {
    read -p "$1: " value
    echo $value
}

# Get internal IP
get_internal_ip() {
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127' | head -n1
}

# Install dependencies
install_dependencies() {
    case "$OS" in
        ubuntu|debian)
            if [ ! -f /etc/apt/keyrings/charm.gpg ] || [ ! -f /usr/bin/gum ]; then
                sudo mkdir -p /etc/apt/keyrings
                apt install curl
                curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
                echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
                sudo apt update && sudo apt install -y gum
                echo "OLOLO"
            fi
            ;;
    esac

    if ! command -v gum &> /dev/null; then
        echo "Gum installation error. Check the repositories or install them manually."
        exit 1
    fi
}

# Install Docker and Certbot
install_docker() {
    if ! command -v docker &> /dev/null || [ ! -f /usr/bin/docker ]; then
        echo "Docker not found, installation..."
        apt update && sudo apt install -y docker.io docker-compose certbot gum
    fi
}

# Asking domain name before installation SuiteCRM
ask_domain() {
    DOMAIN_NAME=$(gum input --placeholder "Enter the domain name for SuiteCRM")
    check_domain
    PROJECT_DIR="$DOMAIN_NAME"
    mkdir -p "$PROJECT_DIR"
}


# Check domain
check_domain() {
    # Check if the domain resolves to an IP address
    if ! getent hosts "$DOMAIN_NAME" >/dev/null; then
        echo "Warning: The domain '$DOMAIN_NAME' does not exist or is not pointing to this server."
        echo "Please create an A record for '$DOMAIN_NAME' and point it to your server's IP address."
        return 1
    fi

    echo "The domain '$DOMAIN_NAME' exists and resolves correctly."
    #return 0
}


install_suitecrm() {
    echo "Installing SuiteCRM..."

    # User's request: to use a domain or IP
    use_domain=$(gum choose "Yes" "No" --header "Do you want to use a domain name?")
    if [[ "$use_domain" == "Yes" ]]; then
        DOMAIN_NAME=$(gum input --placeholder "Enter your domain name")
        
        if check_domain "$DOMAIN_NAME"; then
            echo "Proceeding with further setup..."
        else
            echo "Setup aborted due to missing DNS record."
            exit 1
        fi
        
        PROJECT_DIR="./$DOMAIN_NAME"
    else
        server_name=$(get_internal_ip)
        PROJECT_DIR="./$server_name"
        echo "Using server IP: $server_name"
    fi

    CONFIG_NAME="${DOMAIN_NAME:-$server_name}"
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "Error: variables DOMAIN_NAME and server_name not set!" >&2
        exit 1
    fi

    # Set Database User and Password
    db_name=$(gum input --placeholder "Enter your MariaDB database")
    db_user=$(gum input --placeholder "Enter your MariaDB username")
    db_pass=$(gum input --password --placeholder "Enter your MariaDB password")
    db_root_pass=$(gum input --password --placeholder "Please enter MariaDB root password!")

    echo "Configuration MariaDB complete!"
    
    # Set SuiteCRM admin User and Password
    suitecrm_name=$(gum input --placeholder "Please set SuiteCRM username")
    suitecrm_password=$(gum input --password --placeholder "Please set SuiteCRM password")
    
    echo "Installing and configuring SuiteCRM in docker"
    mkdir -p $PROJECT_DIR/mariadb-persistence
    mkdir -p $PROJECT_DIR/suitecrm-persistence
    chown -R 1001:1001 $PROJECT_DIR
    
    cat << EOF | tee $PROJECT_DIR/docker-compose.yaml
version: '3.8'

services:
  mariadb:
    image: bitnami/mariadb:latest
    container_name: mariadb
    environment:
      - MARIADB_ROOT_PASSWORD=$db_root_pass
      - MARIADB_DATABASE=$db_name
      - MARIADB_USER=$db_user
      - MARIADB_PASSWORD=$db_pass
    volumes:
      - ./mariadb-persistence:/bitnami/mariadb
    networks:
      - suitecrm-network

  suitecrm:
    image: bitnami/suitecrm:latest
    container_name: suitecrm
    environment:
      - SUITECRM_DATABASE_HOST=mariadb
      - SUITECRM_DATABASE_PORT_NUMBER=3306
      - SUITECRM_DATABASE_NAME=$db_name
      - SUITECRM_DATABASE_USER=$db_user
      - SUITECRM_DATABASE_PASSWORD=$db_pass
      - SUITECRM_USERNAME=$suitecrm_name
      - SUITECRM_PASSWORD=$suitecrm_password
    ports:
      - "80:8080"
      - "443:8443"
    volumes:
       - ./suitecrm-persistence:/bitnami/suitecrm
    depends_on:
      - mariadb
    networks:
      - suitecrm-network

networks:
  suitecrm-network:
    driver: bridge

EOF


    cd $PROJECT_DIR && /usr/bin/docker-compose up -d
    
    echo "Installation completed please wait when  SuiteCRM will be configured"
}


setup_backups() {
    # Requesting a project name
    PROJECT_NAME=$(gum input --placeholder "Enter your project name")

    # Checking if the project name is entered
    if [ -z "$PROJECT_NAME" ]; then
        echo "Error: PROJECT_NAME is not set." >&2
        exit 1
    fi

    # Getting the absolute path to the current directory
    CURRENT_DIR=$(pwd)

    # Checking the existence of the project directory
    if [ ! -d "$CURRENT_DIR/$PROJECT_NAME" ]; then
        echo "Error: The project directory '$CURRENT_DIR/$PROJECT_NAME' does not exist." >&2
        exit 1
    fi

    # Choosing a backup time
    BACKUP_TIME=$(gum choose "03:00" "05:00" "23:00")

    # Creating a backup directory
    mkdir -p "${PROJECT_NAME}_backup"
    PROJECT_BACKUP_PATH=$(cd "${PROJECT_NAME}_backup" && pwd)
    PROJECT_PATH=$(cd "${PROJECT_NAME}" && pwd)

    # Dividing time into hours and minutes
    BACKUP_HOUR=${BACKUP_TIME%%:*}
    BACKUP_MINUTE=${BACKUP_TIME##*:}

    # Ensuring the crontab file exists
    touch "/var/spool/cron/crontabs/$USER"

    # Adding a task to cron
    (crontab -l 2>/dev/null; echo "$BACKUP_MINUTE $BACKUP_HOUR * * * tar -czf $PROJECT_BACKUP_PATH/suitecrm_backup_$(date +\%F).tar.gz -C $PROJECT_PATH .") | crontab -

    # Creating the backup immediately
    tar -czf "$PROJECT_BACKUP_PATH/suitecrm_backup_$(date +\%F).tar.gz" -C "$PROJECT_PATH" .

    echo "Your backup has been created and added to cron job everyday at $BACKUP_TIME"
}

manage_containers() {
  # Requesting a project name
    PROJECT_NAME=$(gum input --placeholder "Enter your project name")

    # Checking if the project name is entered
    if [ -z "$PROJECT_NAME" ]; then
        echo "Error: PROJECT_NAME is not set." >&2
        exit 1
    fi

    # Getting the absolute path to the current directory
    CURRENT_DIR=$(pwd)

    # Checking the existence of the project directory
    if [ ! -d "$CURRENT_DIR/$PROJECT_NAME" ]; then
        echo "Error: The project directory '$CURRENT_DIR/$PROJECT_NAME' does not exist." >&2
        exit 1
    fi
    
    ACTION=$(gum choose "Show containers status" "Restart containers" "Stop containers" "Delete containers and data" "Back")
    case $ACTION in
        "Show containers status")
            docker-compose -f "$PROJECT_NAME/docker-compose.yaml" ps
            ;;
        "Restart containers")
            docker-compose -f "$PROJECT_NAME/docker-compose.yaml" restart
            ;;
        "Stop containers")
            docker-compose -f "$PROJECT_NAME/docker-compose.yaml" down
            ;;
        "Delete containers and data")
            delete_project=$(gum choose "Yes" "No" --header "Are you sure that you want to delete the folder with all data for project?")
            if [[ "$delete_project" == "Yes" ]]; then
                docker-compose -f "$PROJECT_NAME/docker-compose.yaml" down -v
                rm -rf "$PROJECT_NAME"
            else
                return 1
            fi
            ;;
        "Back")
            main_menu
            ;;
    esac
}

# Function to display the main menu
main_menu() {
    CHOICE=$(gum choose "Install SuiteCRM" "Make a complete archive of the database and website" "Container management" "Log out")
    case $CHOICE in
        "Install SuiteCRM")
            install_docker
            install_suitecrm
            #ask_domain
            ;;
        "Make a complete archive of the database and website")
            setup_backups
            echo "Creating backup..."
            #tar -czvf "$PROJECT_NAME/backups/suitecrm_backup_$(date +%F).tar.gz" "$PROJECT_DIR"
            echo "Backup created."
        
        # fi
        # echo "The project $PROJECT_NAME doesn't exist, please check of you put correct project name"
            ;;
        "Container management")
            echo "Managing containers..."
            manage_containers
            ;;
        "Log out")
            echo "Exiting..."
            exit 0
            ;;
    esac
}

# Main script logic
detect_os
install_dependencies

# Run the main menu in a loop
while true; do
    main_menu
done
