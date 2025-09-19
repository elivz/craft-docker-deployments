# Craft Docker Deployments

A robust GitHub Actions workflow for deploying Craft CMS applications using Docker containers with **zero-downtime deployments** and automatic rollback capabilities.

## Features

- 🚀 **Automated Docker builds** using GitHub Container Registry
- 🔄 **Zero-downtime deployments** with nginx-proxy load balancing
- 🏥 **Health checking** with configurable endpoints and automatic verification
- 🔄 **Intelligent rollback** on deployment or health check failures
- ⚡ **Fast builds** with Docker layer caching
- 🔧 **Database migrations** and cache clearing automation

## Quick Start

### 1. Repository Setup

Add the deployment workflow to your repository by creating `.github/workflows/deploy-staging.yml`:

```yaml
name: Deploy to Staging

on:
  push:
    branches: [staging]

jobs:
  deploy:
    uses: ./.github/workflows/deployment.yml
    with:
      environment: staging
      domain: staging.yoursite.com
      basic-auth: ${{ secrets.STAGING_BASIC_AUTH }}
    secrets: inherit
```

### 2. Required Repository Secrets

Configure these secrets in your GitHub repository settings:

| Secret | Description | Example |
|--------|-------------|---------|
| `DEPLOY_HOST` | Server hostname or IP | `your-server.com` |
| `DEPLOY_USER` | SSH username | `deploy` |
| `DEPLOY_KEY` | SSH private key | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `STAGING_BASIC_AUTH` | Basic auth for staging (optional) | `username:password` |

### 3. Server Setup

Ensure your deployment server has:
- Docker and Docker Compose installed
- SSH access configured for the deploy user
- GitHub Container Registry access (handled automatically)

### 4. Slack Notifications (Optional)

Set up deployment notifications using GitHub's official Slack app for better integration and easier management:

1. **Install GitHub for Slack**: Visit [slack.github.com](https://slack.github.com/) and install the GitHub app to your Slack workspace
2. **Connect your repository**: In your Slack channel, run `/github subscribe owner/repo-name`
3. **Configure notifications**: Subscribe to workflow events:
   ```
   /github subscribe owner/repo-name workflows
   ```
4. **Customize notifications**: You can also subscribe to specific events:
   ```
   /github subscribe owner/repo-name workflows:* deployments
   ```

This provides automatic notifications for:
- Workflow runs (started, completed, failed)
- Deployment status updates
- Direct links to workflow logs and commit details
- Rich formatting with status indicators

## Configuration Options

### Workflow Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `environment` | ✅ | - | Environment name (staging, production, etc.) |
| `domain` | ✅ | - | Domain name for the deployment |
| `basic-auth` | ❌ | - | Basic authentication credentials |
| `health-check-path` | ❌ | `/actions/app/health-check` | Health check endpoint path |

### Example with Custom Configuration

```yaml
jobs:
  deploy:
    uses: ./.github/workflows/deployment.yml
    with:
      environment: production
      domain: yoursite.com
      health-check-path: /health
    secrets: inherit
```

## How It Works

### 1. Build Phase
- Checks out code and logs into GitHub Container Registry
- Builds Docker images using `docker-compose.ci.yml`
- Pushes images with environment-specific tags
- Utilizes GitHub Actions cache for faster builds

### 2. Zero-Downtime Deployment Phase
- **Starts new containers**: Deploys new version alongside current production containers
- **Load balancing**: nginx-proxy automatically distributes traffic between old and new containers
- **Health verification**: Internal health checks ensure new containers are ready before proceeding
- **Traffic migration**: nginx-proxy balances traffic between old and new containers

### 3. Completion Phase
- **Graceful shutdown**: Stops old containers only after new ones are verified healthy
- **Container promotion**: New containers are promoted to production names (web, queue)
- **Clean state**: Removes temporary containers to maintain clean deployment state

### 4. Final Health Check Phase
- Performs HTTP health checks against the public domain
- Confirms the entire deployment is working correctly
- Uses configurable retry attempts and timeouts

### 5. Rollback on Failure
- **Automatic trigger**: Activates if any deployment step or health check fails
- **Instant rollback**: Stops failed containers, ensures production containers remain active
- **Zero-downtime**: Traffic continues flowing to working version throughout rollback
- **Detailed logging**: Provides comprehensive troubleshooting information

### 6. Post-Deployment
- Runs Craft CMS database migrations on the active deployment
- Clears application caches
- Cleans up old Docker images to maintain server storage

## Zero-Downtime Deployment System

The deployment workflow implements a **zero-downtime deployment strategy** using nginx-proxy for automatic load balancing and traffic switching.

### How Zero-Downtime Deployment Works
1. **Parallel deployment**: New containers start alongside current production containers
2. **Load balancing**: nginx-proxy automatically includes new containers in traffic distribution
3. **Health verification**: Internal health checks ensure new containers are fully ready
4. **Graceful transition**: Old containers stop only after new containers are verified healthy
5. **Container promotion**: New containers are promoted to production names for consistency

### Deployment Architecture
- **web/web-new**: Current production and temporary deployment containers
- **queue/queue-new**: Background job processing containers for each deployment
- **Shared resources**: Redis and storage volumes are shared between deployments
- **nginx-proxy integration**: Uses `VIRTUAL_HOST` environment variable for automatic service discovery

### Traffic Switching Process
- **Automatic load balancing**: nginx-proxy distributes traffic between all healthy containers
- **Health-based routing**: Only containers passing health checks receive traffic
- **Seamless transition**: Users experience no downtime during the container switchover
- **Instant rollback capability**: Failed deployments are immediately excluded from load balancing

### Zero-Downtime Benefits
- **No service interruption**: Users experience no downtime during deployments
- **Risk mitigation**: New versions are thoroughly tested before serving production traffic
- **Instant recovery**: Rollbacks happen in seconds, not minutes
- **Safe deployments**: Deploy confidently during business hours

### When Rollback Triggers
- Docker Compose deployment failures
- Container startup failures  
- Internal container health check failures
- External health check failures (HTTP endpoint unreachable)
- Any critical error during the deployment process

### Rollback Process
- **Immediate action**: Failed deployment containers are stopped instantly
- **Traffic preservation**: Original working deployment continues serving all traffic
- **State verification**: System confirms working deployment is healthy
- **Clean recovery**: Failed deployment artifacts are cleaned up automatically

## Docker Compose Files

### `docker-compose.ci.yml`
Used for building and pushing images during CI:
- Defines build context and Dockerfile location
- Configures image tags and registry settings

### `docker-compose.deployment.yml`
Template for zero-downtime production deployments:
- **Web services**: Defines `web` (production) and `web-new` (deployment) containers
- **Queue services**: Defines `queue` (production) and `queue-new` (deployment) containers  
- **nginx-proxy integration**: Uses `VIRTUAL_HOST` for automatic service discovery and load balancing
- **Shared resources**: Storage and Redis volumes are shared between deployments
- **Health checks**: Built-in container health monitoring for deployment verification
- **Resource limits**: Configurable memory and replica settings per environment
- **YAML anchors**: Uses anchors to reduce duplication between services

## Deployment Scripts

The workflow uses modular bash scripts for better maintainability and reusability:

### `.github/workflows/scripts/deploy.sh`
Main zero-downtime deployment script that:
- Sets up the environment and logs into the container registry
- Configures docker-compose files with environment-specific values
- Starts new containers alongside production containers
- Performs internal health checks on new containers
- Gracefully transitions traffic from old to new containers
- Promotes new containers to production names

### `.github/workflows/scripts/rollback.sh`
Rollback script for deployment failures that:
- Cleans up failed deployment containers
- Ensures production containers are running and healthy
- Restores the system to a known good state

### `.github/workflows/scripts/migrate.sh`
Database migration script that:
- Runs Craft CMS database migrations on the active container
- Clears compiled caches and templates
- Invalidates application caches

### Script Architecture Benefits
- **Maintainability**: Scripts can be edited and tested independently
- **Reusability**: Scripts can be run manually for debugging or emergency deployments
- **Version control**: Script changes are tracked with the workflow
- **Modularity**: Each script has a single, clear responsibility

## Troubleshooting

### Common Issues

**Health checks timeout**
- Increase health check retry attempts or intervals in workflow
- Verify health check endpoint is accessible in new containers
- Check basic auth credentials if required
- Ensure containers have sufficient startup time

**Container state conflicts**
- Check for orphaned containers: `docker compose ps -a`
- Clean up stopped containers: `docker compose rm -f`
- Verify proper container state: only `web` and `queue` should be running in production

**SSH connection failures**
- Verify `DEPLOY_HOST`, `DEPLOY_USER`, and `DEPLOY_KEY` secrets
- Ensure SSH key has proper permissions on the server
- Test SSH connection manually: `ssh user@host`

**nginx-proxy not routing traffic**
- Verify `VIRTUAL_HOST` environment variable is set correctly
- Check nginx-proxy logs: `docker logs nginx-proxy`
- Ensure containers are on the `nginx-proxy` network
- Confirm containers are healthy and passing health checks

**Deployment stuck in mixed state**
- Both web and web-new containers running: Check workflow logs for interruption point
- Manual cleanup: Stop temporary containers manually and let the system stabilize
- Emergency rollback: Stop new deployment and ensure production deployment is running

### Debugging

Enable verbose logging by checking the GitHub Actions workflow logs:
- **Build logs**: Show Docker build output and caching information
- **Deployment logs**: Include container startup, health checks, and traffic switching details
- **Health check logs**: Provide detailed information about endpoint testing and retry attempts
- **Rollback logs**: Show step-by-step restoration process for failed deployments

**Deployment-Specific Debugging:**
- **Container status tracking**: Each deployment logs current container states
- **Health check verification**: Logs show internal and external health check results
- **Traffic routing verification**: nginx-proxy integration status and load balancing behavior
- **Cleanup operations**: Detailed logging of container shutdown and removal processes

## Best Practices

### Deployment Strategy
- **Zero-downtime deployments**: Use nginx-proxy load balancing to eliminate service interruption
- **Deploy during business hours**: Safe to deploy anytime with zero-downtime approach
- **Gradual rollouts**: Consider using feature flags for additional deployment safety
- **Monitor nginx-proxy**: Ensure load balancer is healthy and routing traffic correctly

### Security
- Use dedicated deploy user with minimal required permissions
- Rotate SSH keys regularly
- Keep secrets up to date and secure

### Monitoring
- Set up proper health check endpoints in your application
- Use GitHub's official Slack app for deployment notifications
- Review GitHub Actions logs for any warnings
- Monitor nginx-proxy logs for traffic routing issues

### Performance
- Keep Docker images lean to reduce deployment time
- Utilize build caching for faster CI builds
- Consider using multi-stage builds for optimization

## Troubleshooting

### Common Issues

**Deployment fails with "Health check timeout"**
- Check that your web container is starting properly: `docker compose logs web-new`
- Verify the health check endpoint is accessible: `curl -sf http://localhost:8080/actions/app/health-check`
- Increase health check timeout in the deployment script if needed

**Containers fail to start**
- Check for port conflicts: `docker ps -a`
- Verify the container image exists: `docker images | grep your-repo`
- Check Docker Compose logs: `docker compose logs web-new queue-new`

**Domain not responding after deployment**
- Check nginx-proxy status: `docker compose -f nginx-proxy/docker-compose.yml logs`
- Verify container is registered with nginx-proxy: `docker network inspect nginx-proxy_default`
- Test internal container connectivity: `docker compose exec web curl -sf http://web:8080`

**Database migrations fail**
- Check Craft CLI access: `docker compose exec web ./craft migrate/all --interactive=0`
- Verify database connectivity: `docker compose exec web ./craft db/backup`
- Check migration logs: `docker compose logs web`

### Manual Recovery

If a deployment gets stuck or fails partially:

```bash
# Clean up failed deployment
docker compose --profile deployment down
docker compose --profile deployment rm -f

# Reset to stable state
docker compose up -d web queue
docker compose exec web ./craft clear-caches/all

# Verify system health
curl -sf https://your-domain.com/actions/app/health-check
```

### Monitoring and Alerts

Consider setting up monitoring for:
- Container health status
- Response time and availability
- Database connection status
- Disk space and resource usage

Example health check for monitoring systems:
```bash
#!/bin/bash
# Simple health check script for monitoring
response=$(curl -sf https://your-domain.com/actions/app/health-check)
if [ $? -eq 0 ]; then
    echo "Site is healthy: $response"
    exit 0
else
    echo "Site health check failed"
    exit 1
fi
```

## Environment-Specific Configurations

Use different configurations for each environment:

```yaml
# .github/workflows/deploy-staging.yml
on:
  push:
    branches: [staging]
jobs:
  deploy:
    uses: ./.github/workflows/deployment.yml
    with:
      environment: staging
      domain: staging.yoursite.com
      basic-auth: ${{ secrets.STAGING_BASIC_AUTH }}

# .github/workflows/deploy-production.yml  
on:
  push:
    branches: [main]
jobs:
  deploy:
    uses: ./.github/workflows/deployment.yml
    with:
      environment: production
      domain: yoursite.com
```

## Contributing

When contributing to this deployment workflow:

1. Test changes in a staging environment first
2. Update documentation for any new features
3. Ensure backward compatibility when possible
4. Add appropriate error handling and logging

## License

This deployment workflow is open source and available under the [MIT License](LICENSE).
