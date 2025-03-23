#!/bin/bash

# setup.sh - Digital Ocean Server Deployment Tool Setup
# This script creates the necessary directory structure and files for the tool

set -e

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "======================================================"
echo "      Digital Ocean Server Deployment Tool Setup      "
echo "======================================================"
echo -e "${NC}"

# Create necessary directories
echo -e "${YELLOW}Creating directory structure...${NC}"

mkdir -p playbooks
mkdir -p roles/{common,nginx,apache,mysql,php,redis,rabbitmq,ssl}/{tasks,handlers,templates,defaults,vars}
mkdir -p server-deploy-config/inventory
mkdir -p templates

# Make main scripts executable
echo -e "${YELLOW}Making scripts executable...${NC}"

chmod +x server-deploy.sh
chmod +x nginx-config
chmod +x deploy

# Create necessary roles handlers
echo -e "${YELLOW}Creating role handlers...${NC}"

# Nginx handlers
cat > roles/nginx/handlers/main.yml <<EOF
---
# Nginx role handlers

- name: Reload Nginx
  systemd:
    name: nginx
    state: reloaded

- name: Restart Nginx
  systemd:
    name: nginx
    state: restarted
EOF

# PHP handlers
cat > roles/php/handlers/main.yml <<EOF
---
# PHP role handlers

- name: Restart PHP-FPM
  systemd:
    name: "php{{ php_version }}-fpm"
    state: restarted
EOF

# Redis handlers
cat > roles/redis/handlers/main.yml <<EOF
---
# Redis role handlers

- name: Restart Redis
  systemd:
    name: redis-server
    state: restarted
EOF

# RabbitMQ handlers
cat > roles/rabbitmq/handlers/main.yml <<EOF
---
# RabbitMQ role handlers

- name: Restart RabbitMQ
  systemd:
    name: rabbitmq-server
    state: restarted
EOF

# Apache handlers
cat > roles/apache/handlers/main.yml <<EOF
---
# Apache role handlers

- name: Reload Apache
  systemd:
    name: apache2
    state: reloaded

- name: Restart Apache
  systemd:
    name: apache2
    state: restarted
EOF

# Create PHP template files
echo -e "${YELLOW}Creating PHP configuration templates...${NC}"

cat > roles/php/templates/php-custom.ini.j2 <<EOF
; Custom PHP Settings

; Maximum execution time
max_execution_time = 60

; Maximum input variables
max_input_vars = 3000

; Maximum upload size
upload_max_filesize = 20M
post_max_size = 25M

; Memory limit
memory_limit = 256M

; Error reporting
display_errors = Off
display_startup_errors = Off
log_errors = On
error_log = /var/log/php/php-error.log

; OPcache
opcache.enable = 1
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 8
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 60
opcache.fast_shutdown = 1
opcache.enable_cli = 1

; Session
session.save_handler = files
session.save_path = /var/lib/php/sessions
session.gc_maxlifetime = 1440
EOF

cat > roles/php/templates/php-fpm.conf.j2 <<EOF
[www]
user = www-data
group = www-data
listen = /run/php/php{{ php_version }}-fpm.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 10
pm.start_servers = 3
pm.min_spare_servers = 2
pm.max_spare_servers = 5
pm.max_requests = 500
EOF

# Create Redis template
echo -e "${YELLOW}Creating Redis configuration template...${NC}"

cat > roles/redis/templates/redis.conf.j2 <<EOF
# Redis configuration file

bind 127.0.0.1
protected-mode yes
port 6379
tcp-backlog 511
timeout 0
tcp-keepalive 300

daemonize yes
supervised systemd
pidfile /var/run/redis/redis-server.pid
loglevel notice
logfile /var/log/redis/redis-server.log

databases 16

save 900 1
save 300 10
save 60 10000

stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /var/lib/redis

maxclients 10000
maxmemory 256mb
maxmemory-policy allkeys-lru

appendonly no
appendfilename "appendonly.aof"
appendfsync everysec
EOF

# Create Nginx main configuration template
echo -e "${YELLOW}Creating Nginx configuration template...${NC}"

cat > roles/nginx/templates/nginx.conf.j2 <<EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    # MIME
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    
    # Logging Settings
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    # Gzip Settings
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # Virtual Host Configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Create common role
echo -e "${YELLOW}Creating common role...${NC}"

cat > roles/common/tasks/main.yml <<EOF
---
# Common role tasks

- name: Update and upgrade packages
  apt:
    upgrade: dist
    update_cache: yes
    cache_valid_time: 3600

- name: Set timezone
  timezone:
    name: UTC

- name: Create swap file if not exists
  command: dd if=/dev/zero of=/swapfile bs=1M count=2048
  args:
    creates: /swapfile

- name: Set swap file permissions
  file:
    path: /swapfile
    mode: '0600'
  when: ansible_swaptotal_mb < 1

- name: Make swap
  command: mkswap /swapfile
  when: ansible_swaptotal_mb < 1

- name: Enable swap
  command: swapon /swapfile
  when: ansible_swaptotal_mb < 1
  ignore_errors: yes

- name: Add swap to fstab
  lineinfile:
    path: /etc/fstab
    line: "/swapfile none swap sw 0 0"
    state: present
  when: ansible_swaptotal_mb < 1

- name: Set up basic firewall
  ufw:
    rule: allow
    name: "{{ item }}"
    state: enabled
  with_items:
    - OpenSSH
    - "WWW Full"

- name: Enable UFW
  ufw:
    state: enabled
EOF

# Create Apache role
echo -e "${YELLOW}Creating Apache role...${NC}"

cat > roles/apache/tasks/main.yml <<EOF
---
# Apache role tasks

- name: Install Apache
  apt:
    name:
      - apache2
      - libapache2-mod-php{{ php_version }}
    state: present

- name: Enable required Apache modules
  apache2_module:
    name: "{{ item }}"
    state: present
  with_items:
    - rewrite
    - ssl
    - headers
    - proxy
    - proxy_fcgi
  notify: Restart Apache

- name: Enable and start Apache service
  systemd:
    name: apache2
    state: started
    enabled: yes

- name: Create Apache virtual host
  template:
    src: apache-site.conf.j2
    dest: /etc/apache2/sites-available/{{ domain_name }}.conf
    owner: root
    group: root
    mode: '0644'
  notify: Reload Apache

- name: Enable Apache virtual host
  file:
    src: /etc/apache2/sites-available/{{ domain_name }}.conf
    dest: /etc/apache2/sites-enabled/{{ domain_name }}.conf
    state: link
  notify: Reload Apache

- name: Disable default Apache site
  command: a2dissite 000-default
  args:
    removes: /etc/apache2/sites-enabled/000-default.conf
  notify: Reload Apache

- name: Create document root
  file:
    path: "{{ doc_root }}"
    state: directory
    owner: "{{ ansible_user }}"
    group: www-data
    mode: '0755'
EOF

# Create Apache virtual host template
cat > roles/apache/templates/apache-site.conf.j2 <<EOF
<VirtualHost *:80>
    ServerName {{ domain_name }}
    ServerAlias www.{{ domain_name }}
    
    DocumentRoot {{ doc_root }}
    
    <Directory {{ doc_root }}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/{{ domain_name }}-error.log
    CustomLog \${APACHE_LOG_DIR}/{{ domain_name }}-access.log combined
</VirtualHost>
EOF

# Create .env template for Laravel applications
cat > templates/env.j2 <<EOF
APP_NAME="{{ domain_name }}"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://{{ domain_name }}

LOG_CHANNEL=stack
LOG_LEVEL=error

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE={{ db_name | default('laravel') }}
DB_USERNAME={{ db_user | default('laravel') }}
DB_PASSWORD={{ db_password | default('password') }}

BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS=null
MAIL_FROM_NAME="\${APP_NAME}"

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=

PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
PUSHER_APP_CLUSTER=mt1
EOF

# Create Nginx-related playbooks
echo -e "${YELLOW}Creating Nginx management playbooks...${NC}"

# Nginx list playbook
cat > playbooks/nginx-list.yml <<EOF
---
# Playbook to list all Nginx configurations

- name: List Nginx configurations
  hosts: servers
  become: yes
  
  tasks:
    - name: Get all Nginx site configurations
      find:
        paths: /etc/nginx/sites-available
        patterns: "*.conf"
      register: nginx_configs
    
    - name: Get enabled Nginx site configurations
      find:
        paths: /etc/nginx/sites-enabled
        patterns: "*.conf"
      register: nginx_enabled
    
    - name: Show Nginx configurations
      debug:
        msg: "{{ item.path | basename }} ({{ 'enabled' if item.path | basename in (nginx_enabled.files | map(attribute='path') | map('basename')) else 'disabled' }})"
      with_items: "{{ nginx_configs.files }}"
EOF

# Nginx create playbook
cat > playbooks/nginx-create.yml <<EOF
---
# Playbook to create a new Nginx site configuration

- name: Create Nginx site configuration
  hosts: servers
  become: yes
  vars:
    php_support: "{{ php_support | default('y') }}"
    default_server: "{{ default_server | default('n') }}"
  
  tasks:
    - name: Create Nginx server block
      template:
        src: ../roles/nginx/templates/nginx-site.conf.j2
        dest: /etc/nginx/sites-available/{{ domain }}.conf
        owner: root
        group: root
        mode: '0644'
    
    - name: Create document root
      file:
        path: "{{ doc_root }}"
        state: directory
        owner: "{{ ansible_user }}"
        group: www-data
        mode: '0755'
    
    - name: Create test PHP file
      copy:
        content: |
          <?php
          phpinfo();
        dest: "{{ doc_root }}/index.php"
        owner: "{{ ansible_user }}"
        group: www-data
        mode: '0644'
      when: php_support == 'y'
    
    - name: Create test HTML file
      copy:
        content: |
          <!DOCTYPE html>
          <html>
          <head>
              <title>Welcome to {{ domain }}</title>
          </head>
          <body>
              <h1>Welcome to {{ domain }}</h1>
              <p>Your Nginx site is working!</p>
          </body>
          </html>
        dest: "{{ doc_root }}/index.html"
        owner: "{{ ansible_user }}"
        group: www-data
        mode: '0644'
      when: php_support != 'y'
EOF

# Nginx enable playbook
cat > playbooks/nginx-enable.yml <<EOF
---
# Playbook to enable an Nginx site configuration

- name: Enable Nginx site configuration
  hosts: servers
  become: yes
  
  tasks:
    - name: Check if configuration exists
      stat:
        path: /etc/nginx/sites-available/{{ domain }}.conf
      register: config_exists
    
    - name: Fail if configuration doesn't exist
      fail:
        msg: "Nginx configuration for {{ domain }} does not exist!"
      when: not config_exists.stat.exists
    
    - name: Enable Nginx site configuration
      file:
        src: /etc/nginx/sites-available/{{ domain }}.conf
        dest: /etc/nginx/sites-enabled/{{ domain }}.conf
        state: link
    
    - name: Test Nginx configuration
      command: nginx -t
      register: nginx_test
      failed_when: nginx_test.rc != 0
    
    - name: Reload Nginx
      service:
        name: nginx
        state: reloaded
EOF

# Nginx disable playbook
cat > playbooks/nginx-disable.yml <<EOF
---
# Playbook to disable an Nginx site configuration

- name: Disable Nginx site configuration
  hosts: servers
  become: yes
  
  tasks:
    - name: Check if configuration is enabled
      stat:
        path: /etc/nginx/sites-enabled/{{ domain }}.conf
      register: config_enabled
    
    - name: Disable Nginx site configuration
      file:
        path: /etc/nginx/sites-enabled/{{ domain }}.conf
        state: absent
      when: config_enabled.stat.exists
    
    - name: Test Nginx configuration
      command: nginx -t
      register: nginx_test
      failed_when: nginx_test.rc != 0
    
    - name: Reload Nginx
      service:
        name: nginx
        state: reloaded
EOF

# Nginx delete playbook
cat > playbooks/nginx-delete.yml <<EOF
---
# Playbook to delete an Nginx site configuration

- name: Delete Nginx site configuration
  hosts: servers
  become: yes
  
  tasks:
    - name: Check if configuration exists
      stat:
        path: /etc/nginx/sites-available/{{ domain }}.conf
      register: config_exists
    
    - name: Fail if configuration doesn't exist
      fail:
        msg: "Nginx configuration for {{ domain }} does not exist!"
      when: not config_exists.stat.exists
    
    - name: Disable Nginx site configuration
      file:
        path: /etc/nginx/sites-enabled/{{ domain }}.conf
        state: absent
    
    - name: Delete Nginx site configuration
      file:
        path: /etc/nginx/sites-available/{{ domain }}.conf
        state: absent
    
    - name: Test Nginx configuration
      command: nginx -t
      register: nginx_test
      failed_when: nginx_test.rc != 0
    
    - name: Reload Nginx
      service:
        name: nginx
        state: reloaded
EOF

# Nginx SSL playbook
cat > playbooks/nginx-ssl.yml <<EOF
---
# Playbook to set up SSL for a domain

- name: Set up SSL for domain
  hosts: servers
  become: yes
  vars:
    include_www: "{{ include_www | default('y') }}"
  
  tasks:
    - name: Check if Nginx configuration exists
      stat:
        path: /etc/nginx/sites-available/{{ domain }}.conf
      register: config_exists
    
    - name: Fail if configuration doesn't exist
      fail:
        msg: "Nginx configuration for {{ domain }} does not exist!"
      when: not config_exists.stat.exists
    
    - name: Install Certbot
      apt:
        name:
          - certbot
          - python3-certbot-nginx
        state: present
    
    - name: Obtain SSL certificate
      command: >
        certbot --nginx 
        -d {{ domain }} 
        {% if include_www == 'y' %}-d www.{{ domain }}{% endif %} 
        --non-interactive --agree-tos 
        --redirect
      register: certbot_result
    
    - name: Set up auto-renewal
      cron:
        name: certbot-renewal
        job: "certbot renew --quiet --deploy-hook 'systemctl reload nginx'"
        hour: "3"
        minute: "30"
        weekday: "1"
EOF

# Nginx reload playbook
cat > playbooks/nginx-reload.yml <<EOF
---
# Playbook to reload Nginx configuration

- name: Reload Nginx configuration
  hosts: servers
  become: yes
  
  tasks:
    - name: Test Nginx configuration
      command: nginx -t
      register: nginx_test
      failed_when: nginx_test.rc != 0
    
    - name: Reload Nginx
      service:
        name: nginx
        state: reloaded
EOF

echo -e "${GREEN}Setup complete! You can now use the Digital Ocean Server Deployment Tool.${NC}"
echo
echo "To get started, run ./server-deploy.sh"