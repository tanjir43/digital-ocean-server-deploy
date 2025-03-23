# Digital Ocean Server Deployment Tool - Developer Documentation
This document provides technical details about the internal workings and structure of the Digital Ocean Server Deployment Tool for developers and contributors.
## Architecture Overview
This tool utilizes a combination of Bash scripts for user interaction and Ansible for the underlying automation. The architecture follows these core principles:
* **Modularity**: Each service is encapsulated in its own Ansible role
* **Idempotency**: Scripts can be run multiple times without causing issues
* **Minimal dependencies**: Only requires Ansible and SSH access
* **Security-focused**: Implements security best practices by default
## Directory Structure
```

├── server-deploy.sh            # Main entry script for server Setup
├── nginx-config                # Nginx configuration management script
├── deploy                      # Application deployment script
├── setup.sh                    # Package initialization script
├── ansible.cfg                 # Ansible configuration
├── server-deploy-config/       # Generated configuration storage
│   ├── inventory/              # Ansible inventory
│   │   └── hosts               # Server definitions
│   ├── vars.yml                # Global variables
│   ├── server.cfg              # Server connection info
│   ├── app.cfg                 # Application configuration
│   └── services.cfg            # Service selection
├── playbooks/                  # Ansible playbooks
│   ├── main.yml                # Server setup playbook
│   ├── deploy.yml              # Deployment playbook
│   ├── nginx-list.yml          # Nginx site listing
│   ├── nginx-create.yml        # Nginx site creation

│   ├── nginx-enable.yml        # Nginx site enabling
│   ├── nginx-disable.yml       # Nginx site disabling
│   ├── nginx-delete.yml        # Nginx site deletion
│   ├── nginx-ssl.yml           # SSL certificate setup
│   └── nginx-reload.yml        # Nginx reload handler
├── roles/                      # Ansible roles
│   ├── common/                 # Base server configuration
│   ├── nginx/                  # Nginx web server
│   ├── apache/                 # Apache web server
│   ├── mysql/                  # MySQL database
│   ├── php/                    # PHP runtime
│   ├── redis/                  # Redis cache server
│   ├── rabbitmq/               # RabbitMQ message broker
│   └── ssl/                    # Let's Encrypt SSL
└── templates/                  # Application templates
└── env.j2                  # Environment file template

## Key Components


### 1. Shell Scripts
#### server-deploy.sh
The main entry point that:
* Collects server information and credentials
* Configures application settings
* Selects services to install
* Runs the Ansible playbooks
#### nginx-config
Manages Nginx configuration:
* Creates/enables/disables/deletes virtual hosts
* Sets up SSL certificates
* Lists configurations
* Reloads Nginx
#### deploy
Handles application deployment:
* Copies code to the server
* Sets up symlinks for zero-downtime deployment
* Installs dependencies
* Sets proper permissions
* Links environment files


### 2. Ansible Components
#### Playbooks
Orchestrate the server setup and management tasks:
* `main.yml`: Primary server provisioning
* `deploy.yml`: Application deployment
* `nginx-*.yml`: Nginx management
#### Roles
Encapsulate service-specific tasks:
* `common`: Basic server setup (swap, firewall, etc.)
* `nginx`/`apache`: Web server configuration
* `mysql`: Database server setup
* `php`: PHP runtime and extensions
* `redis`: Redis cache server
* `rabbitmq`: Message broker
* `ssl`: Let's Encrypt SSL certificate management
## Workflow
### Server Setup Flow
1. User runs `server-deploy.sh`
2. Script collects configuration through interactive prompts
3. Configuration is stored in `server-deploy-config/`
4. Ansible playbook `main.yml` is executed with collected variables
5. Roles are applied based on selected services
6. Post-tasks create initial configuration
### Deployment Flow
1. User runs `./deploy /path/to/project`
2. Script builds a timestamped release directory
3. Code is synchronized to the server
4. Dependencies are installed (if applicable)
5. Shared resources are linked (storage, .env)
6. Symbolic links are updated for zero-downtime deployment
7. Services are restarted as needed
## Development Guidelines
### Adding New Services
To add a new service:
1. Create a new role under `roles/`
2. Add the role to `main.yml` with appropriate conditions
3. Update `server-deploy.sh` to include the new service option
4. Add any templates needed for configuration
### Modifying Templates
Service templates are located in each role's `templates/` directory. They use Jinja2 syntax with variables defined in:
* `server-deploy-config/vars.yml`
* Role-specific defaults in `roles/<role>/defaults/main.yml`
### Security Considerations
When contributing, ensure:
* No passwords or keys are hardcoded
* File permissions are properly set
* User input is properly validated
* Security-related configurations follow best practices
## Debugging
### Common Issues
* **SSH Connection Failures**: Check the inventory file and SSH credentials
* **Playbook Errors**: Run Ansible with `-vvv` for verbose output
* **Template Errors**: Verify variables are defined and syntax is correct
### Logs
* Script logs are stored in `server-deploy-logs.txt`
* Ansible logs can be enabled by setting `ANSIBLE_LOG_PATH`
* Service-specific logs are in their standard locations on the server
## Testing
Before submitting changes:
1. Run `./setup.sh` to rebuild the package
2. Test against a clean Ubuntu server on Digital Ocean
3. Verify all scripts run without errors
4. Test a full deployment cycle
## License

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.
## Initial Folder

server-deploy.sh             # Main entry script 
nginx-config                 # Nginx configuration manager 
playbooks/main.yml           # Main Ansible playbook
playbooks/deploy.yml         # Deployment playbook 
ansible.cfg                  # Ansible configuration 
roles/nginx/tasks/main.yml   # Nginx role tasks 
roles/nginx/templates/nginx-site.conf.j2  # Nginx site template 
roles/mysql/tasks/main.yml   # MySQL role tasks 
roles/mysql/handlers/main.yml  # MySQL handlers 
roles/mysql/templates/mysql-custom.cnf.j2  # MySQL configuration 
roles/php/tasks/main.yml     # PHP role tasks 
roles/redis/tasks/main.yml   # Redis role tasks 
roles/rabbitmq/tasks/main.yml  # RabbitMQ role tasks 
roles/ssl/tasks/main.yml     # SSL role tasks 
README.md                    # Documentation 
setup.sh                     # Package setup script

*For user-facing documentation, please refer to the standard README.md file.*