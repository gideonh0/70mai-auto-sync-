#!/usr/bin/env bash

MESSAGE="$1"

if [ -n "$WEBHOOK_URL" ]; then
    curl -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"🚗 **70mai Auto-Sync:** ${MESSAGE}\"}" > /dev/null 2>&1
fi
