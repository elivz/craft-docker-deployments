#!/bin/bash

# Migration script for Craft CMS Docker deployments
# This script runs database migrations and clears caches on the active deployment

set -e
source ~/.bashrc

# Get parameters from environment variables
ENVIRONMENT="${ENVIRONMENT}"

# Validate required parameters
if [ -z "$ENVIRONMENT" ]; then
    echo "❌ Missing required environment variable: ENVIRONMENT"
    exit 1
fi

echo "🗃️ Running migrations and cache clearing for $ENVIRONMENT environment..."

# Navigate to environment directory
cd "$ENVIRONMENT"

# Verify the active web container is running
WEB_RUNNING=$(docker compose ps --services --filter "status=running" | grep -E "^web$" | wc -l)

if [ "$WEB_RUNNING" -eq 0 ]; then
  echo "❌ Active web container not found or not running"
  exit 1
fi

echo "🗃️ Running migrations on active web container..."
docker compose exec -T web php craft up --interactive=0

echo "🧹 Clearing caches..."
docker compose exec -T web php craft clear-caches/compiled-classes --interactive=0
docker compose exec -T web php craft clear-caches/compiled-templates --interactive=0
docker compose exec -T web php craft invalidate-tags/all --interactive=0

echo "✅ Migrations and cache clearing completed"