#!/bin/bash

# Rollback script for failed Craft CMS Docker deployments
# This script cleans up failed deployments and ensures production containers are running

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

# Clean up failed new containers
echo "🧹 Cleaning up failed deployment containers..."
docker compose --profile deployment stop web-new queue-new || true
docker compose --profile deployment rm -f web-new queue-new || true

# Ensure production containers are running
echo "🔍 Ensuring production containers are healthy..."
docker compose up --detach --no-build web queue redis

echo "✅ Rollback completed - production is restored"