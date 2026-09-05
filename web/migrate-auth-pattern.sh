#!/bin/bash

# Migration script to convert API endpoints from createServerClient to Astro.locals pattern

FILES_TO_MIGRATE=(
    "src/pages/api/admin/feature-flags.ts"
    "src/pages/api/admin/vapid-key.ts"
    "src/pages/api/admin/stats.ts"
    "src/pages/api/admin/integrations.ts"
    "src/pages/api/admin/stripe-key.ts"
    "src/pages/api/admin/openrouter-key.ts"
    "src/pages/api/admin/content.ts"
    "src/pages/api/admin/notifications.ts"
    "src/pages/api/admin/reports.ts"
    "src/pages/api/admin/user-feed.ts"
    "src/pages/api/admin/users.ts"
    "src/pages/api/account/delete.ts"
    "src/pages/api/push/send.ts"
    "src/pages/api/push/notify.ts"
    "src/pages/api/push/subscribe.ts"
    "src/pages/api/stripe/checkout.ts"
    "src/pages/api/stripe/portal.ts"
)

echo "Starting migration of ${#FILES_TO_MIGRATE[@]} API endpoints to Astro.locals pattern..."

for file in "${FILES_TO_MIGRATE[@]}"; do
    echo "Processing: $file"
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        echo "❌ File not found: $file"
        continue
    fi
    
    # Create backup
    cp "$file" "${file}.backup"
    
    # Migration logic would go here
    echo "✅ Backed up: $file -> ${file}.backup"
done

echo "Migration script completed. Manual migration needed for each file."