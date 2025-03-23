#!/bin/bash

# server-deploy.sh - Digital Ocean Server Automation Tool
# This script automates the setup of a LEMP stack with Redis and RabbitMQ on a Digital Ocean droplet

set -e

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Config directory
CONFIG_DIR="$(pwd)/server-deploy-config"
PLAYBOOKS_DIR="$(pwd)/playbooks"
ANSIBLE_CONFIG="$(pwd)/ansible.cfg"

# Script logo and intro
function show_intro() {
    clear
    echo -e "${BLUE}"
    echo "======================================================"
    echo "      Digital Ocean Server Deployment Automation      "
    echo "======================================================"
    echo -e "${NC}"
    echo "This tool will automate the setup of a LEMP stack with Redis,"
    echo "RabbitMQ, and other services on your Digital Ocean droplet."
    echo
}

# Check for dependencies
function check_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"
    
    # Check for Ansible
    if ! command -v ansible >/dev/null 2>&1; then
        echo -e "${RED}Ansible is not installed. Installing now...${NC}"
        sudo apt-get update
        sudo apt-get install -y software-properties-common
        sudo apt-add-repository --yes --update ppa:ansible/ansible
        sudo apt-get install -y ansible
    fi
    
    # Check for sshpass for password-based SSH
    if ! command -v sshpass >/dev/null 2>&1; then
        echo -e "${RED}sshpass is not installed. Installing now...${NC}"
        sudo apt-get install -y sshpass
    fi
    
    echo -e "${GREEN}All dependencies are installed.${NC}"
}

# Create necessary directories if they don't exist
function create_directories() {
    echo -e "${YELLOW}Setting up configuration directories...${NC}"
    
    # Create configuration directory
    mkdir -p "$CONFIG_DIR"
    # Create inventory directory
    mkdir -p "$CONFIG_DIR/inventory"
    
    echo -e "${GREEN}Configuration directories created.${NC}"
}

# Collect server information
function collect_server_info() {
    echo -e "${YELLOW}Please provide your server information:${NC}"
    
    # Collect server IP
    read -p "Server IP address: " SERVER_IP
    
    # Collect SSH credentials
    read -p "SSH username (default: root): " SSH_USER
    SSH_USER=${SSH_USER:-root}
    
    # Ask for either password or key file
    echo "How would you like to authenticate?"
    echo "1) Password"
    echo "2) SSH key file"
    read -p "Choice (1/2): " AUTH_CHOICE
    
    if [ "$AUTH_CHOICE" == "1" ]; then
        read -sp "SSH password: " SSH_PASSWORD
        echo
        AUTH_METHOD="password"
    else
        read -p "Path to SSH key file: " SSH_KEY_FILE
        AUTH_METHOD="key"
    fi
    
    # Save server information to config
    echo "# Server configuration" > "$CONFIG_DIR/server.cfg"
    echo "SERVER_IP=$SERVER_IP" >> "$CONFIG_DIR/server.cfg"
    echo "SSH_USER=$SSH_USER" >> "$CONFIG_DIR/server.cfg"
    
    # Create Ansible inventory file
    echo "[servers]" > "$CONFIG_DIR/inventory/hosts"
    echo "server ansible_host=$SERVER_IP ansible_user=$SSH_USER" >> "$CONFIG_DIR/inventory/hosts"
    
    if [ "$AUTH_METHOD" == "password" ]; then
        echo "ansible_ssh_pass=$SSH_PASSWORD" >> "$CONFIG_DIR/server.cfg"
        echo "server ansible_host=$SERVER_IP ansible_user=$SSH_USER ansible_ssh_pass=$SSH_PASSWORD" > "$CONFIG_DIR/inventory/hosts"
    else
        echo "ansible_ssh_private_key_file=$SSH_KEY_FILE" >> "$CONFIG_DIR/server.cfg"
        echo "server ansible_host=$SERVER_IP ansible_user=$SSH_USER ansible_ssh_private_key_file=$SSH_KEY_FILE" > "$CONFIG_DIR/inventory/hosts"
    fi
    
    # Add additional Ansible options
    echo "[servers:vars]" >> "$CONFIG_DIR/inventory/hosts"
    echo "ansible_python_interpreter=/usr/bin/python3" >> "$CONFIG_DIR/inventory/hosts"
    
    echo -e "${GREEN}Server information saved.${NC}"
}

# Collect application configuration
function collect_app_config() {
    echo -e "${YELLOW}Please provide application configuration:${NC}"
    
    # Database configuration
    read -p "MySQL root password: " MYSQL_ROOT_PASSWORD
    read -p "Create a database? (y/n): " CREATE_DB
    
    if [ "$CREATE_DB" == "y" ]; then
        read -p "Database name: " DB_NAME
        read -p "Database user: " DB_USER
        read -p "Database password: " DB_PASSWORD
    fi
    
    # Web configuration
    read -p "Domain name (e.g., example.com): " DOMAIN_NAME
    read -p "Document root path (default: /var/www/html): " DOC_ROOT
    DOC_ROOT=${DOC_ROOT:-/var/www/html}
    
    # Save app configuration
    echo "# Application configuration" > "$CONFIG_DIR/app.cfg"
    echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" >> "$CONFIG_DIR/app.cfg"
    
    if [ "$CREATE_DB" == "y" ]; then
        echo "DB_NAME=$DB_NAME" >> "$CONFIG_DIR/app.cfg"
        echo "DB_USER=$DB_USER" >> "$CONFIG_DIR/app.cfg"
        echo "DB_PASSWORD=$DB_PASSWORD" >> "$CONFIG_DIR/app.cfg"
    fi
    
    echo "DOMAIN_NAME=$DOMAIN_NAME" >> "$CONFIG_DIR/app.cfg"
    echo "DOC_ROOT=$DOC_ROOT" >> "$CONFIG_DIR/app.cfg"
    
    # Create Ansible variables file
    echo "---" > "$CONFIG_DIR/vars.yml"
    echo "mysql_root_password: \"$MYSQL_ROOT_PASSWORD\"" >> "$CONFIG_DIR/vars.yml"
    
    if [ "$CREATE_DB" == "y" ]; then
        echo "mysql_databases:" >> "$CONFIG_DIR/vars.yml"
        echo "  - name: $DB_NAME" >> "$CONFIG_DIR/vars.yml"
        echo "    encoding: utf8mb4" >> "$CONFIG_DIR/vars.yml"
        echo "    collation: utf8mb4_unicode_ci" >> "$CONFIG_DIR/vars.yml"
        echo "mysql_users:" >> "$CONFIG_DIR/vars.yml"
        echo "  - name: $DB_USER" >> "$CONFIG_DIR/vars.yml"
        echo "    password: $DB_PASSWORD" >> "$CONFIG_DIR/vars.yml"
        echo "    priv: '$DB_NAME.*:ALL'" >> "$CONFIG_DIR/vars.yml"
        echo "    host: '%'" >> "$CONFIG_DIR/vars.yml"
    fi
    
    echo "domain_name: $DOMAIN_NAME" >> "$CONFIG_DIR/vars.yml"
    echo "doc_root: $DOC_ROOT" >> "$CONFIG_DIR/vars.yml"
    
    echo -e "${GREEN}Application configuration saved.${NC}"
}

# Select services to install
function select_services() {
    echo -e "${YELLOW}Select services to install:${NC}"
    
    # Web server
    echo "1) Nginx (recommended)"
    echo "2) Apache"
    read -p "Web server choice (1/2): " WEB_SERVER_CHOICE
    
    case $WEB_SERVER_CHOICE in
        1) WEB_SERVER="nginx" ;;
        2) WEB_SERVER="apache" ;;
        *) WEB_SERVER="nginx" ;;
    esac
    
    # Ask for PHP version
    echo "Select PHP version:"
    echo "1) PHP 7.4"
    echo "2) PHP 8.0"
    echo "3) PHP 8.1"
    echo "4) PHP 8.2"
    read -p "PHP version choice (1-4): " PHP_CHOICE
    
    case $PHP_CHOICE in
        1) PHP_VERSION="7.4" ;;
        2) PHP_VERSION="8.0" ;;
        3) PHP_VERSION="8.1" ;;
        4) PHP_VERSION="8.2" ;;
        *) PHP_VERSION="8.1" ;;
    esac
    
    # Optional services
    read -p "Install Redis? (y/n): " INSTALL_REDIS
    read -p "Install RabbitMQ? (y/n): " INSTALL_RABBITMQ
    read -p "Install Let's Encrypt SSL? (y/n): " INSTALL_SSL
    read -p "Set up Laravel queue workers? (y/n): " SETUP_QUEUE_WORKERS
    
    # Save service selections
    echo "# Service selections" > "$CONFIG_DIR/services.cfg"
    echo "WEB_SERVER=$WEB_SERVER" >> "$CONFIG_DIR/services.cfg"
    echo "PHP_VERSION=$PHP_VERSION" >> "$CONFIG_DIR/services.cfg"
    echo "INSTALL_REDIS=$INSTALL_REDIS" >> "$CONFIG_DIR/services.cfg"
    echo "INSTALL_RABBITMQ=$INSTALL_RABBITMQ" >> "$CONFIG_DIR/services.cfg"
    echo "INSTALL_SSL=$INSTALL_SSL" >> "$CONFIG_DIR/services.cfg"
    echo "SETUP_QUEUE_WORKERS=$SETUP_QUEUE_WORKERS" >> "$CONFIG_DIR/services.cfg"

    # Update Ansible variables
    echo "web_server: $WEB_SERVER" >> "$CONFIG_DIR/vars.yml"
    echo "php_version: $PHP_VERSION" >> "$CONFIG_DIR/vars.yml"
    echo "install_redis: $([ "$INSTALL_REDIS" == "y" ] && echo "true" || echo "false")" >> "$CONFIG_DIR/vars.yml"
    echo "install_rabbitmq: $([ "$INSTALL_RABBITMQ" == "y" ] && echo "true" || echo "false")" >> "$CONFIG_DIR/vars.yml"
    echo "install_ssl: $([ "$INSTALL_SSL" == "y" ] && echo "true" || echo "false")" >> "$CONFIG_DIR/vars.yml"
    echo "setup_queue_workers: $([ "$SETUP_QUEUE_WORKERS" == "y" ] && echo "true" || echo "false")" >> "$CONFIG_DIR/vars.yml"

    echo -e "${GREEN}Service selections saved.${NC}"
}

# Run Ansible playbooks to set up the server
function run_ansible_playbooks() {
    echo -e "${YELLOW}Setting up your server. This may take a while...${NC}"
    
    # Set ANSIBLE_CONFIG environment variable
    export ANSIBLE_CONFIG="$ANSIBLE_CONFIG"
    
    # Run main playbook
    ansible-playbook -i "$CONFIG_DIR/inventory/hosts" "$PLAYBOOKS_DIR/main.yml" --extra-vars "@$CONFIG_DIR/vars.yml"
    
    echo -e "${GREEN}Server setup completed successfully!${NC}"
}

# Create a deployment command
function setup_deployment() {
    echo -e "${YELLOW}Setting up deployment command...${NC}"
    
    # Create deployment script
    cat > ./deploy <<EOF
#!/bin/bash
# Deployment script

if [ \$# -lt 1 ]; then
    echo "Usage: ./deploy <path_to_project>"
    exit 1
fi

PROJECT_PATH=\$1
SERVER_IP="$SERVER_IP"
SSH_USER="$SSH_USER"

echo "Deploying project from \$PROJECT_PATH to server..."
ansible-playbook -i "$CONFIG_DIR/inventory/hosts" "$PLAYBOOKS_DIR/deploy.yml" --extra-vars "project_path=\$PROJECT_PATH"
echo "Deployment completed successfully!"
EOF
    
    chmod +x ./deploy
    
    echo -e "${GREEN}Deployment command created. Use ./deploy <path_to_project> to deploy your project.${NC}"
}

# Main function
function main() {
    show_intro
    check_dependencies
    create_directories
    collect_server_info
    collect_app_config
    select_services
    
    # Confirm before proceeding
    echo
    echo -e "${YELLOW}Ready to set up your server with the following configuration:${NC}"
    echo "Server IP: $SERVER_IP"
    echo "Web Server: $WEB_SERVER"
    echo "PHP Version: $PHP_VERSION"
    echo "Domain: $DOMAIN_NAME"
    
    echo
    read -p "Proceed with setup? (y/n): " CONFIRM
    
    if [ "$CONFIRM" == "y" ]; then
        run_ansible_playbooks
        setup_deployment
        
        echo
        echo -e "${GREEN}==================================${NC}"
        echo -e "${GREEN}Server setup completed!${NC}"
        echo -e "${GREEN}==================================${NC}"
        echo
        echo "Your server is now set up with the following services:"
        echo "- $WEB_SERVER web server"
        echo "- PHP $PHP_VERSION"
        echo "- MySQL database server"
        
        if [ "$INSTALL_REDIS" == "y" ]; then
            echo "- Redis"
        fi
        
        if [ "$INSTALL_RABBITMQ" == "y" ]; then
            echo "- RabbitMQ"
        fi
        
        echo
        echo "To deploy your application, use:"
        echo "./deploy <path_to_your_project>"
        
        echo
        echo "To manage Nginx configurations, use:"
        echo "./nginx-config <command> [options]"
    else
        echo -e "${RED}Setup cancelled.${NC}"
    fi
}

# Run the main function
main