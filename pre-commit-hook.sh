#!/bin/bash
# Pre-Commit-Hook: Warnt vor import.meta.env in Server-Dateien
# Installation: cp pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

echo "🔍 Prüfe import.meta.env in Server-Dateien..."

# Finde import.meta.env in API-Dateien (NICHT in Client-Dateien)
VIOLATIONS=$(grep -rn 'import\.meta\.env' web/src/pages/api/ web/src/lib/ssr-client.ts web/src/lib/settings.ts web/src/lib/cookie-utils.ts web/src/middleware.ts 2>/dev/null | grep -v 'import\.meta\.env\.DEV' | grep -v '// import\.meta\.env' || true)

if [ -n "$VIOLATIONS" ]; then
  echo ""
  echo "⚠️  import.meta.env in Server-Dateien gefunden!"
  echo "   Server-Code MUSS process.env via config.ts nutzen."
  echo ""
  echo "$VIOLATIONS"
  echo ""
  echo "   Fix: import { getSupabaseUrl } from '../lib/config';"
  echo "   Dann: getSupabaseUrl() statt import.meta.env.PUBLIC_SUPABASE_URL"
  echo ""
  read -p "Trotzdem committen? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

echo "✅ Keine import.meta.env-Verstöße in Server-Dateien"
