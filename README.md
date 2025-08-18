# Craft CMS Docker Deployments

A Docker-based deployment system for Craft CMS with automated CI/CD pipelines using GitHub Actions. This project provides a complete infrastructure setup for deploying Craft CMS applications to staging and production environments.

## Overview

This repository demonstrates a modern deployment workflow for Craft CMS applications using:

- **Docker** for containerization and consistent environments
- **GitHub Actions** for CI/CD automation
- **GitHub Container Registry (GHCR)** for Docker image storage
- **nginx-proxy** for reverse proxy and SSL termination
- **Multi-stage deployment** with health checks and rollback capabilities
- **Slack notifications** for deployment status updates

## Architecture

### Services

- **Web Container**: PHP 8.4 with nginx, serves the Craft CMS application
- **Queue Container**: Handles Craft CMS background jobs
- **Redis**: Caching and session storage
- **MySQL**: Database (local development only)

### Deployment Flow

1. **Build**: Docker images are built and pushed to GHCR
2. **Deploy**: Images are pulled and deployed to the target server
3. **Migrate**: Database migrations and cache clearing
4. **Verify**: Health check with automatic rollback on failure
5. **Notify**: Slack notifications for success/failure

## Local Development Setup

### Prerequisites

- Docker and Docker Compose
- Node.js (for frontend asset compilation)
- PHP 8.4+ (optional, for local Craft CLI usage)

### Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd craft-docker-deployments
   ```

2. **Copy environment configuration**
   ```bash
   cp .env.example.dev .env
   ```

3. **Update .env file**
   Edit `.env` with your local configuration:
   ```env
   CRAFT_APP_ID=your-app-id
   CRAFT_SECURITY_KEY=your-security-key
   CRAFT_ENVIRONMENT=dev
   CRAFT_DEV_MODE=true
   PRIMARY_SITE_URL=http://localhost:3010/
   ```

4. **Start the development environment**
   ```bash
   docker compose up -d
   ```

5. **Install Craft CMS**
   ```bash
   docker compose exec web php craft install
   ```

6. **Access the application**
   - Frontend: http://localhost:3010
   - Admin Panel: http://localhost:3010/admin
   - Database: localhost:3308 (user: app, password: app)

## Production Deployment Setup

### Server Requirements

- Ubuntu/Debian Linux server
- Docker and Docker Compose installed
- nginx-proxy network configured
- SSH access for deployment user

### Server Preparation

1. **Install Docker on your server**
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   sudo usermod -aG docker $USER
   ```

2. **Create nginx-proxy network**
   ```bash
   docker network create nginx-proxy
   ```

3. **Set up nginx-proxy**
   
   Copy the nginx-proxy configuration files to your server:
   ```bash
   # On your local machine, copy nginx-proxy files to server
   scp -r infra/nginx-proxy deploy@your-server.com:~/
   ```
   
   **Optional: Add SSL certificates**
   If you have SSL certificates, copy them to the certs directory:
   ```bash
   # Copy your certificate files to includes/certs/
   # Example for domain: your-domain.com
   cp your-domain.com.crt nginx-proxy/includes/certs/
   cp your-domain.com.key nginx-proxy/includes/certs/
   ```
   
   **Optional: Add basic authentication**
   If you need password protection for certain domains:
   ```bash
   # Install htpasswd utility
   sudo apt-get update && sudo apt-get install apache2-utils
   
   # Create htpasswd file for a domain
   htpasswd -c nginx-proxy/includes/htpasswd/staging.your-domain.com username
   ```
   
   Start the nginx-proxy container:
   ```bash
   # Make sure you're in the home directory
   cd ~/nginx-proxy
   
   # Start nginx-proxy using docker-compose
   docker compose up -d
   ```

4. **Create deployment user and directories**
   ```bash
   sudo useradd -m -s /bin/bash deploy
   sudo mkdir -p ~/{staging,production}
   sudo chown deploy:deploy ~/{staging,production}
   ```

### GitHub Repository Configuration

#### 1. Environment Setup

Create two environments in your GitHub repository:
- `staging`
- `production`

Go to: **Settings** → **Environments** → **New environment**

#### 2. Required GitHub Secrets

Configure the following secrets for each environment:

| Secret Name | Description | Example |
|------------|-------------|---------|
| `DEPLOY_HOST` | Server hostname or IP | `your-server.com` |
| `DEPLOY_USER` | SSH username for deployment | `deploy` |
| `DEPLOY_KEY` | Private SSH key for deployment user | `-----BEGIN OPENSSH PRIVATE KEY-----` |

**Optional Slack Integration:**
| Secret Name | Description |
|------------|-------------|
| `SLACK_WEBHOOK_URL` | Slack webhook URL for notifications |
| `SLACK_CHANNEL_ID` | Slack channel ID for notifications |

#### 3. Setting up SSH Keys

1. **Generate SSH key pair on your local machine**
   ```bash
   ssh-keygen -t ed25519 -C "deployment-key" -f ~/.ssh/deploy_key
   ```

2. **Add public key to server**
   ```bash
   ssh-copy-id -i ~/.ssh/deploy_key.pub deploy@your-server.com
   ```

3. **Add private key to GitHub Secrets**
   Copy the content of `~/.ssh/deploy_key` and add it as `DEPLOY_KEY` secret in GitHub.

### Environment Configuration

#### 1. Production .env file

Create `.env` file on your server in the deployment directories:

**For staging** (`~/staging/.env`):
```env
# Read about configuration, here:
# https://craftcms.com/docs/5.x/configure.html

# Set the hostname for the Craft CMS application.
# This is used by nginx-proxy to route requests to the correct container.
VIRTUAL_HOST=staging.craft-docker-deployment.elivz.com

# The application ID used to to uniquely store session and cache data, mutex locks, and more
CRAFT_APP_ID=your-app-id

# The environment Craft is currently running in (dev, staging, production, etc.)
CRAFT_ENVIRONMENT=staging

# Database connection settings
CRAFT_DB_DRIVER=mysql
CRAFT_DB_SERVER=your-db-server
CRAFT_DB_PORT=3306
CRAFT_DB_DATABASE=staging_database
CRAFT_DB_USER=staging_user
CRAFT_DB_PASSWORD=secure-password
CRAFT_DB_SCHEMA=public
CRAFT_DB_TABLE_PREFIX=

# General settings
CRAFT_SECURITY_KEY=your-security-key
CRAFT_DEV_MODE=false
CRAFT_ALLOW_ADMIN_CHANGES=false
CRAFT_DISALLOW_ROBOTS=true
CRAFT_STREAM_LOGS=true
```

**For production** (`~/production/.env`):
```env
# Read about configuration, here:
# https://craftcms.com/docs/5.x/configure.html

# Set the hostname for the Craft CMS application.
# This is used by nginx-proxy to route requests to the correct container.
VIRTUAL_HOST=craft-docker-deployment.elivz.com

# The application ID used to to uniquely store session and cache data, mutex locks, and more
CRAFT_APP_ID=your-app-id

# The environment Craft is currently running in (dev, staging, production, etc.)
CRAFT_ENVIRONMENT=production

# Database connection settings
CRAFT_DB_DRIVER=mysql
CRAFT_DB_SERVER=your-db-server
CRAFT_DB_PORT=3306
CRAFT_DB_DATABASE=production_database
CRAFT_DB_USER=production_user
CRAFT_DB_PASSWORD=secure-password
CRAFT_DB_SCHEMA=public
CRAFT_DB_TABLE_PREFIX=

# General settings
CRAFT_SECURITY_KEY=your-security-key
CRAFT_DEV_MODE=false
CRAFT_ALLOW_ADMIN_CHANGES=false
CRAFT_DISALLOW_ROBOTS=false
CRAFT_STREAM_LOGS=true
```

#### 2. Environment-specific Scaling (Optional)

Create additional environment variables on the server for resource management:

```bash
# In ~/production/.env
WEB_REPLICAS=2
WEB_MEMORY_LIMIT=4G
WEB_MEMORY_RESERVATION=2G
QUEUE_MEMORY_LIMIT=2G
QUEUE_MEMORY_RESERVATION=1G
REDIS_MAX_MEMORY=4gb
```

### Domain Configuration

Update the domain names in the workflow files:

1. **Staging**: Edit `.github/workflows/deployment-staging.yml`
   ```yaml
   domain: staging.your-domain.com
   ```

2. **Production**: Edit `.github/workflows/deployment-production.yml`
   ```yaml
   domain: www.your-domain.com
   ```

## Deployment Process

### Automatic Deployments

- **Staging**: Automatically deploys when code is pushed to `staging` branch
- **Production**: Automatically deploys when code is pushed to `main` branch

### Manual Deployments

Trigger manual deployments from GitHub Actions:

1. Go to **Actions** tab in your GitHub repository
2. Select the appropriate workflow (Deploy to Staging/Production)
3. Click **Run workflow**
4. Select the branch and click **Run workflow**

### Deployment Steps

Each deployment follows these steps:

1. **Build Phase**
   - Builds Docker image with multi-stage process
   - Compiles frontend assets with Vite
   - Installs PHP dependencies with Composer
   - Pushes image to GitHub Container Registry

2. **Deploy Phase**
   - Copies docker-compose.yml to server
   - Pulls latest images
   - Updates container configuration
   - Starts containers with zero-downtime deployment

3. **Migration Phase**
   - Runs Craft CMS database migrations
   - Clears compiled templates and caches
   - Invalidates cache tags

4. **Verification Phase**
   - Performs health check on `/actions/app/health-check`
   - Automatically rolls back on failure
   - Sends success/failure notifications

## Monitoring and Maintenance

### Health Checks

The application includes built-in health checks:
- **Web container**: `curl -sf http://localhost:8080/actions/app/health-check`
- **Queue container**: `php craft queue/info`
- **Redis**: `redis-cli ping`

### Logs

View application logs:
```bash
# On the server
cd ~/production  # or staging
docker compose logs -f web
docker compose logs -f queue
```

### Database Backups

Set up regular database backups:
```bash
# Example backup script
docker compose exec web php craft backup/db
```

### Scaling

Adjust container resources by updating environment variables in `.env`:
```env
WEB_REPLICAS=3
WEB_MEMORY_LIMIT=6G
QUEUE_MEMORY_LIMIT=3G
```

Then restart the deployment:
```bash
docker compose up -d --scale web=3
```

## Troubleshooting

### Common Issues

1. **Deployment fails with authentication error**
   - Verify `DEPLOY_KEY` secret is correctly formatted
   - Ensure SSH key is properly added to the server

2. **Health check fails**
   - Check application logs for errors
   - Verify database connectivity
   - Ensure all environment variables are set

3. **Image pull fails**
   - Check GitHub Container Registry permissions
   - Verify `GITHUB_TOKEN` has necessary permissions

4. **Database connection issues**
   - Verify database credentials in `.env`
   - Check database server accessibility
   - Ensure database and user exist

### Debug Commands

```bash
# Check container status
docker compose ps

# View application logs
docker compose logs web

# Access container shell
docker compose exec web bash

# Check Craft CMS status
docker compose exec web php craft status

# Run Craft commands
docker compose exec web php craft queue/info
docker compose exec web php craft cache/flush-all
```

## Security Considerations

- Always use strong, unique passwords for databases and Redis
- Keep the `CRAFT_SECURITY_KEY` secure and unique per environment
- Use SSH keys instead of passwords for server access
- Regularly update Docker images and dependencies
- Enable firewall on the server
- Use SSL/TLS certificates (handled by nginx-proxy)
- Limit database access to necessary hosts only

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment process
5. Submit a pull request

## License

This project is open-source and available under the MIT License.
