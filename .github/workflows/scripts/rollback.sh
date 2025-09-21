#!/bin/bash

# Rollback script for failed Craft CMS Docker deployments
set -e
source ~/.bashrc

# Get parameters from environment variables
ENVIRONMENT="${ENVIRONMENT}"

# Validate required parameters
if [ -z "$ENVIRONMENT" ]; then
    echo "❌ Missing required environment variable: ENVIRONMENT"
    exit 1
fi

echo "🚨 Deployment failed, performing rollback for $ENVIRONMENT environment..."

# Navigate to environment directory
cd "$ENVIRONMENT"

# Clean up any failed deployment containers
echo "🧹 Cleaning up failed deployment containers..."
docker compose --profile deployment stop web-new || true
docker compose --profile deployment rm -f web-new || true

# Try to rollback to previous image if available
if [ -f ".last-stable-image" ]; then
    PREVIOUS_IMAGE=$(cat .last-stable-image)
    echo "📦 Rolling back to previous image: $PREVIOUS_IMAGE"
    
    # Update docker-compose.yml with previous image
    # Use # as delimiter since image names contain / and :
    sed -i "s#image: .*#image: $PREVIOUS_IMAGE#g" docker-compose.yml
    
    # Restart with previous image
    docker compose down web queue --timeout 30
    docker compose up --detach --no-build web queue redis
    
    # Simple health check
    echo "⏳ Verifying rollback..."
    for i in {1..10}; do
        if docker compose exec web curl -sf http://localhost:8080/actions/app/health-check >/dev/null 2>&1; then
            echo "✅ Rollback successful"
            exit 0
        fi
        sleep 3
    done
    
    echo "⚠️  Rollback health check failed, ensuring containers are running..."
fi

# Fallback: ensure current containers are running
echo "🔄 Ensuring containers are running..."
docker compose up --detach --no-build web queue redis

echo "✅ Rollback completed"