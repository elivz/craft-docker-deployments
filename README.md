# Craft Docker Deployments

A robust GitHub Actions workflow for deploying Craft CMS applications using Docker containers with **zero-downtime blue-green deployments** and automatic rollback capabilities.

## Features

- 🚀 **Automated Docker builds** using GitHub Container Registry
- 🔄 **Zero-downtime blue-green deployments** with automatic traffic switching
- 🏥 **Health checking** with configurable endpoints and timeouts
- 🔄 **Intelligent rollback** on deployment or health check failures
- 📢 **Slack notifications** for deployment status updates
- 🔒 **Secure deployments** with SSH-based container management
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

### 3. Repository Variables (Optional)

For Slack notifications, configure these variables:

| Variable | Description |
|----------|-------------|
| `SLACK_WEBHOOK_URL` | Slack incoming webhook URL |
| `SLACK_CHANNEL_ID` | Slack channel ID for notifications |

### 4. Server Setup

Ensure your deployment server has:
- Docker and Docker Compose installed
- SSH access configured for the deploy user
- GitHub Container Registry access (handled automatically)

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

### 2. Blue-Green Deployment Phase
- **Determines current state**: Identifies which color (blue/green) is currently active
- **Starts new deployment**: Deploys new version to the inactive color
- **Parallel operation**: Both old and new versions run simultaneously during switchover
- **nginx-proxy load balancing**: Automatically distributes traffic between active services

### 3. Health Check Phase
- Performs HTTP health checks against the configured endpoint on the new deployment
- Retries up to 6 times with 10-second intervals
- Supports basic authentication if configured
- **Zero-downtime**: Old version continues serving traffic during health checks

### 4. Completion Phase
- **Traffic migration**: nginx-proxy automatically includes healthy new containers in load balancing
- **Graceful shutdown**: Stops old color containers only after new ones are confirmed healthy
- **Clean state**: Removes old containers to maintain clean deployment state

### 5. Rollback on Failure
- **Automatic trigger**: Activates if deployment or health checks fail
- **Instant rollback**: Stops failed new deployment, ensures old deployment remains active
- **Zero-downtime**: Traffic continues flowing to working version throughout rollback
- **Detailed logging**: Provides comprehensive troubleshooting information

### 6. Post-Deployment
- Runs Craft CMS database migrations on the active deployment
- Clears application caches
- Sends status notifications to Slack

## Blue-Green Deployment System

The deployment workflow implements a **zero-downtime blue-green deployment strategy** using nginx-proxy for automatic load balancing and traffic switching.

### How Blue-Green Deployment Works
1. **Color determination**: The system identifies which color (blue/green) is currently active
2. **Parallel deployment**: New version deploys to the inactive color while old version continues serving traffic
3. **Health verification**: New deployment undergoes thorough health checks before traffic switching
4. **Automatic traffic migration**: nginx-proxy automatically includes healthy containers in load balancing pool
5. **Graceful shutdown**: Old deployment stops only after new deployment is confirmed stable

### Blue-Green Architecture
- **web-blue/web-green**: Parallel web service containers that can run simultaneously
- **queue-blue/queue-green**: Corresponding background job processing containers
- **Shared resources**: Redis and storage volumes are shared between deployments
- **nginx-proxy integration**: Uses `VIRTUAL_HOST` environment variable for automatic service discovery

### Traffic Switching Process
- **Gradual transition**: nginx-proxy naturally load balances between old and new containers
- **Health-based routing**: Only healthy containers receive traffic
- **Instant rollback capability**: Failed deployments are immediately removed from load balancing

### Zero-Downtime Benefits
- **No service interruption**: Users experience no downtime during deployments
- **Risk mitigation**: New versions are thoroughly tested before receiving production traffic
- **Instant recovery**: Rollbacks happen in seconds, not minutes
- **Confidence in deployments**: Safe to deploy during business hours

### When Rollback Triggers
- Docker Compose deployment failures
- Container startup failures  
- Health check failures (HTTP endpoint unreachable)
- Any critical error during the blue-green deployment process

### Rollback Process
- **Immediate action**: Failed target deployment is stopped instantly
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
- **Blue-green services**: Defines `web-blue`, `web-green`, `queue-blue`, `queue-green` for parallel deployments
- **nginx-proxy integration**: Uses `VIRTUAL_HOST` for automatic service discovery and load balancing
- **Shared resources**: Storage and Redis volumes are shared between blue/green deployments
- **Health checks**: Built-in container health monitoring for deployment verification
- **Resource limits**: Configurable memory and replica settings per environment
- **Legacy compatibility**: Maintains backward compatibility with single-service deployments

## Slack Notifications

Configure Slack notifications to keep your team informed:

1. Create a Slack app and incoming webhook
2. Add `SLACK_WEBHOOK_URL` and `SLACK_CHANNEL_ID` as repository variables
3. Notifications include:
   - Deployment start/success/failure status
   - Environment and domain information
   - Links to workflow runs and code changes
   - Visual status indicators with emojis

## Troubleshooting

### Common Issues

**Health checks timeout**
- Increase health check retry attempts or intervals in workflow
- Verify health check endpoint is accessible on both blue and green deployments
- Check basic auth credentials if required
- Ensure containers have sufficient startup time

**Blue-green state conflicts**
- Check for orphaned containers: `docker compose ps -a`
- Clean up stopped containers: `docker compose rm -f`
- Verify only one color is active: both blue and green running simultaneously indicates an interrupted deployment

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
- Both blue and green containers running: Check workflow logs for interruption point
- Manual cleanup: Stop one color manually and let the system stabilize
- Emergency rollback: Stop new deployment and ensure old deployment is running

### Debugging

Enable verbose logging by checking the GitHub Actions workflow logs:
- **Build logs**: Show Docker build output and caching information
- **Blue-green deployment logs**: Include color determination, parallel container startup, and traffic switching details
- **Health check logs**: Provide detailed information about endpoint testing and retry attempts
- **Rollback logs**: Show step-by-step restoration process for failed deployments

**Blue-Green Specific Debugging:**
- **Color state tracking**: Each deployment logs current and target colors
- **Container status verification**: Logs show which containers are running for each color
- **Traffic routing verification**: nginx-proxy integration status and health check results
- **Cleanup operations**: Detailed logging of old container shutdown and removal

## Best Practices

### Deployment Strategy
- **Zero-downtime deployments**: Use blue-green strategy to eliminate service interruption
- **Deploy during business hours**: Safe to deploy anytime with zero-downtime approach
- **Gradual rollouts**: Consider using feature flags for additional deployment safety
- **Monitor nginx-proxy**: Ensure load balancer is healthy and routing traffic correctly

### Security
- Use dedicated deploy user with minimal required permissions
- Rotate SSH keys regularly
- Keep secrets up to date and secure

### Monitoring
- Set up proper health check endpoints in your application
- Monitor deployment notifications in Slack
- Review GitHub Actions logs for any warnings

### Performance
- Keep Docker images lean to reduce deployment time
- Utilize build caching for faster CI builds
- Consider using multi-stage builds for optimization

## Advanced Configuration

### Custom Health Check Endpoint

Create a custom health check in your Craft CMS application:

```php
// In your controller or module
public function actionHealthCheck()
{
    // Check database connectivity
    $dbOk = Craft::$app->getDb()->getIsActive();
    
    // Check other services (Redis, external APIs, etc.)
    $redisOk = // your Redis check
    
    if ($dbOk && $redisOk) {
        return $this->asJson(['status' => 'ok']);
    }
    
    Craft::$app->getResponse()->setStatusCode(503);
    return $this->asJson(['status' => 'error']);
}
```

### Environment-Specific Configurations

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
      deployment-timeout: 300
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
      deployment-timeout: 600
```

## Contributing

When contributing to this deployment workflow:

1. Test changes in a staging environment first
2. Update documentation for any new features
3. Ensure backward compatibility when possible
4. Add appropriate error handling and logging

## License

This deployment workflow is open source and available under the [MIT License](LICENSE).
