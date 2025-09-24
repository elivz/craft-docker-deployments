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

# Check if deployment failed mid-process (web-new still exists)
if docker compose ps web-new >/dev/null 2>&1; then
    echo "🧹 Mid-deployment failure detected - cleaning up web-new containers..."
    docker compose --profile deployment stop web-new || true
    docker compose --profile deployment rm -f web-new || true
    echo "✅ Cleanup completed - original containers continue serving traffic"
else
    echo "🔄 Post-deployment failure detected - attempting image rollback..."
    
    # Try to rollback to previous image if available
    if [ -f ".last-stable-image" ]; then
        PREVIOUS_IMAGE=$(cat .last-stable-image)
        echo "📦 Rolling back to previous image: $PREVIOUS_IMAGE"
        
        # Update compose.yml with previous image
        # Use # as delimiter since image names contain / and :
        sed -i "s#image: .*#image: $PREVIOUS_IMAGE#g" compose.yml
        
        # Restart with previous image
        docker compose down web queue --timeout 30
        docker compose up --detach --no-build web queue redis
    else
        echo "⚠️  No previous stable image found"
    fi
fi

echo "✅ Rollback completed"