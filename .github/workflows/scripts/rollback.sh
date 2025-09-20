#!/bin/bash

# Rollback script for failed Craft CMS Docker deployments
# This script handles rollback scenarios including post-deployment failures

set -e
source ~/.bashrc

# Get parameters from environment variables
ENVIRONMENT="${ENVIRONMENT}"
GHCR_REGISTRY="${GHCR_REGISTRY:-ghcr.io}"
GHCR_REPOSITORY="${GHCR_REPOSITORY}"

# Validate required parameters
if [ -z "$ENVIRONMENT" ]; then
    echo "❌ Missing required environment variable: ENVIRONMENT"
    exit 1
fi

echo "🚨 Deployment failed, performing rollback for $ENVIRONMENT environment..."

# Navigate to environment directory
cd "$ENVIRONMENT"

# Check if we're in a mid-deployment state (web-new containers exist)
if docker compose ps web-new >/dev/null 2>&1; then
    echo "🧹 Cleaning up mid-deployment failure..."
    
    # Clean up failed new containers
    docker compose --profile deployment stop web-new|| true
    docker compose --profile deployment rm -f web-new|| true
    
    # Ensure production containers are running
    echo "🔍 Ensuring production containers are healthy..."
    docker compose up --detach --no-build web queue redis
    
else
    echo "🔄 Post-deployment failure detected - attempting restore from previous image..."
    
    # Try to find and restore from previous stable image
    if [ -f ".last-stable-image" ]; then
        PREVIOUS_IMAGE=$(cat .last-stable-image)
        echo "📦 Found previous stable image: $PREVIOUS_IMAGE"
        
        # Create a temporary docker-compose file with the previous image
        cp docker-compose.yml docker-compose.rollback.yml
        
        # Replace the current image with the previous stable image
        sed -i "s|image: .*|image: $PREVIOUS_IMAGE|g" docker-compose.rollback.yml
        
        echo "🔄 Restarting with previous stable image..."
        docker compose -f docker-compose.rollback.yml down web queue
        docker compose -f docker-compose.rollback.yml up --detach --no-build web queue redis
        
        # Wait for container to be ready
        echo "⏳ Waiting for rollback container to be ready..."
        for i in {1..30}; do
            # Perform health check with proper validation
            RESPONSE=$(docker compose -f docker-compose.rollback.yml exec web curl -s -w "%{http_code}" http://localhost:8080/actions/app/health-check 2>/dev/null || echo "000")
            HTTP_CODE="${RESPONSE: -3}"
            BODY="${RESPONSE%???}"
            
            if [ "$HTTP_CODE" = "200" ] && [ -z "$BODY" ]; then
                echo "✅ Rollback container is healthy"
                
                # Replace the main docker-compose.yml with the rollback version
                mv docker-compose.rollback.yml docker-compose.yml
                break
            fi
            
            if [ $i -eq 30 ]; then
                echo "❌ Rollback container failed to become healthy"
                echo "❌ Final status - HTTP: $HTTP_CODE, Body: '$BODY'"
                rm -f docker-compose.rollback.yml
                exit 1
            fi
            
            echo "⏳ Attempt $i/30 - waiting for container... HTTP: $HTTP_CODE, Body: '$BODY'"
            sleep 5
        done
        
    else
        echo "⚠️  No previous stable image found - ensuring current containers are running..."
        
        # Fallback: just make sure current containers are running
        docker compose up --detach --no-build web queue redis
        
        echo "⚠️  WARNING: Could not restore to previous version - current containers restarted"
        echo "⚠️  Manual intervention may be required to restore to a known-good state"
    fi
fi

echo "✅ Rollback completed"