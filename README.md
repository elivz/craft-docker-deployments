# Craft Docker Deployments

A robust GitHub Actions workflow for deploying Craft CMS applications using Docker containers with automatic rollback capabilities.

## Features

- 🚀 **Automated Docker builds** using GitHub Container Registry
- 🔄 **Intelligent rollback** on deployment or health check failures
- 🏥 **Health checking** with configurable endpoints and timeouts
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
| `deployment-timeout` | ❌ | `300` | Deployment timeout in seconds |

### Example with Custom Configuration

```yaml
jobs:
  deploy:
    uses: ./.github/workflows/deployment.yml
    with:
      environment: production
      domain: yoursite.com
      health-check-path: /health
      deployment-timeout: 600
    secrets: inherit
```

## How It Works

### 1. Build Phase
- Checks out code and logs into GitHub Container Registry
- Builds Docker images using `docker-compose.ci.yml`
- Pushes images with environment-specific tags
- Utilizes GitHub Actions cache for faster builds

### 2. Deployment Phase
- Copies Docker Compose configuration to server
- **Backs up current running images** for rollback capability
- Pulls and deploys new container images
- Waits for containers to start successfully

### 3. Health Check Phase
- Performs HTTP health checks against the configured endpoint
- Retries up to 6 times with 10-second intervals
- Supports basic authentication if configured

### 4. Rollback on Failure
- **Automatically triggers** if deployment or health checks fail
- Restores previous working container images
- Verifies rollback success with container status checks
- Provides detailed logging for troubleshooting

### 5. Post-Deployment
- Runs Craft CMS database migrations
- Clears application caches
- Sends status notifications to Slack

## Rollback System

The deployment workflow includes an intelligent rollback mechanism:

### How Rollback Works
1. **Before deployment**: Current running images are tagged as `{environment}-previous`
2. **On failure**: Containers are stopped and previous images are restored
3. **Verification**: Rollback success is verified by checking container status
4. **Logging**: Detailed status information helps with troubleshooting

### When Rollback Triggers
- Docker Compose deployment failures
- Container startup failures
- Health check failures (HTTP endpoint unreachable)
- Any critical error during the deployment process

## Docker Compose Files

### `docker-compose.ci.yml`
Used for building and pushing images during CI:
- Defines build context and Dockerfile location
- Configures image tags and registry settings

### `docker-compose.deployment.yml`
Template for production deployments:
- Uses placeholder variables for environment-specific configuration
- Includes health checks and resource limits
- Configured automatically during deployment

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

**Deployment Fails with "name invalid" error**
- ✅ **Fixed**: The improved workflow properly handles image rollback
- Previous images are now preserved during deployment

**Health checks timeout**
- Increase `deployment-timeout` input value
- Verify health check endpoint is accessible
- Check basic auth credentials if required

**SSH connection failures**
- Verify `DEPLOY_HOST`, `DEPLOY_USER`, and `DEPLOY_KEY` secrets
- Ensure SSH key has proper permissions on the server
- Test SSH connection manually: `ssh user@host`

**Rollback fails**
- Check server logs for container status
- Verify Docker images exist on the server
- Ensure sufficient disk space for image storage

### Debugging

Enable verbose logging by checking the GitHub Actions workflow logs:
- Build logs show Docker build output and caching information
- Deployment logs include container startup and health check details
- Rollback logs provide step-by-step restoration information

## Best Practices

### Branch Strategy
- Use separate workflows for different environments
- Deploy staging from `staging` branch, production from `main`
- Test deployments in staging before promoting to production

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
