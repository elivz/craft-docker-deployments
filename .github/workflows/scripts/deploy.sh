#!/bin/bash

# Zero-downtime deployment script for Craft CMS Docker containers
# This script implements a deployment strategy using nginx-proxy for load balancing
# between old and new containers to achieve zero downtime.

set -e
source ~/.bashrc

# Get parameters from environment variables passed by GitHub Actions
ENVIRONMENT="${ENVIRONMENT}"
DOMAIN="${DOMAIN}"
GHCR_REGISTRY="${GHCR_REGISTRY}"
GHCR_REPOSITORY="${GHCR_REPOSITORY}"
GITHUB_TOKEN="${GITHUB_TOKEN}"
GITHUB_ACTOR="${GITHUB_ACTOR}"

# Validate required parameters
if [ -z "$ENVIRONMENT" ] || [ -z "$DOMAIN" ] || [ -z "$GHCR_REGISTRY" ] || [ -z "$GHCR_REPOSITORY" ] || [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_ACTOR" ]; then
    echo "❌ Missing required environment variables"
    echo "Required: ENVIRONMENT, DOMAIN, GHCR_REGISTRY, GHCR_REPOSITORY, GITHUB_TOKEN, GITHUB_ACTOR"
    exit 1
fi

echo "🚀 Starting zero-downtime deployment for $ENVIRONMENT environment..."
echo "📝 Domain: $DOMAIN"
echo "📦 Repository: $GHCR_REPOSITORY"

# Setup environment directory
echo "📁 Setting up environment directory..."
mkdir -p "$ENVIRONMENT"
cd "$ENVIRONMENT"

# Save current stable image before deployment (for rollback purposes)
if docker compose ps web >/dev/null 2>&1; then
    CURRENT_IMAGE=$(docker compose config | grep "image:" | head -1 | awk '{print $2}')
    if [ ! -z "$CURRENT_IMAGE" ]; then
        echo "💾 Saving current stable image for rollback: $CURRENT_IMAGE"
        echo "$CURRENT_IMAGE" > .last-stable-image
    fi
fi

# Login to container registry
echo "🔐 Logging into GitHub Container Registry..."
echo "$GITHUB_TOKEN" | docker login --username "$GITHUB_ACTOR" --password-stdin "$GHCR_REGISTRY"

# Configure docker-compose file with environment-specific values
echo "⚙️ Configuring docker-compose file..."
sed -i -e "s|{BRANCH}|$ENVIRONMENT|g" docker-compose.yml
sed -i -e "s|{VIRTUAL_HOST}|$DOMAIN|g" docker-compose.yml
sed -i -e "s|{GHCR_REGISTRY}|$GHCR_REGISTRY|g" docker-compose.yml
sed -i -e "s|{GHCR_REPOSITORY}|$GHCR_REPOSITORY|g" docker-compose.yml

# Pull new container images
echo "📥 Pulling new images..."
docker compose pull -q

# Start new containers alongside existing production
# Both will have the same VIRTUAL_HOST, so nginx-proxy will load balance
echo "🔬 Starting new containers alongside current production..."
docker compose --profile deployment up --detach --wait --no-build web-new --scale web-new=1

# Verify new containers are healthy before proceeding
echo "🔍 Verifying new containers are healthy..."
for i in {1..12}; do
  if docker compose exec -T web-new curl -sf http://localhost:8080/actions/app/health-check > /dev/null; then
    echo "✅ New container health check passed (attempt $i)"
    break
  else
    echo "⏳ New container not ready yet (attempt $i/12)..."
    if [ $i -eq 12 ]; then
      echo "❌ New container failed health check after 12 attempts"
      exit 1
    fi
    sleep 5
  fi
done

echo "✅ New services are healthy and ready"
echo "🌐 nginx-proxy is now load balancing between old and new containers"

# Gracefully stop old containers (traffic automatically goes to new ones)
echo "⏹️ Gracefully stopping old production containers..."
docker compose stop web
docker compose rm -f web

# Start fresh production containers BEFORE stopping the temporary new ones
echo "🚀 Starting fresh production containers alongside -new containers..."
docker compose up --detach --no-build web queue --wait

# Give nginx-proxy a moment to detect the new production containers
echo "⏳ Allowing nginx-proxy to detect new production containers..."
sleep 10

# NOW we can safely stop the -new containers
echo "⏹️ Stopping and removing temporary -new containers..."
docker compose --profile deployment stop web-new
docker compose --profile deployment rm -f web-new

echo "✅ Zero-downtime deployment completed successfully!"