#!/usr/bin/env bash
# pre-commit Secret-Scan für carp24
# Blockt Commits mit echten Secret-Werten. Erlaubt .env.example (keine Werte) und ${VAR}-Referenzen.
set -u

# Echte Werte (Basis64/Alnum > 20 Zeichen) nach "=" — NICHT ${VAR} oder leer
PATTERNS=(
  'JWT_SECRET=[A-Za-z0-9._-]\{20,\}'
  'GOTRUE_JWT_SECRET=[A-Za-z0-9._-]\{20,\}'
  'SERVICE_ROLE_KEY=[A-Za-z0-9._-]\{20,\}'
  'ANON_KEY=[A-Za-z0-9._-]\{20,\}'
  'POSTGRES_PASSWORD=[A-Za-z0-9._-]\{20,\}'
  'DASHBOARD_PASSWORD=[A-Za-z0-9._-]\{8,\}'
  'PG_META_CRYPTO_KEY=[A-Za-z0-9._-]\{20,\}'
  'sk-[A-Za-z0-9]\{20,\}'
)

# Whitelist: Dateien die Variablen-Referenzen/Generator-Logik enthalten dürfen
WHITELIST='\.env\.example$|utils/|docker-compose'

fail=0
for file in $(git diff --cached --name-only); do
  # Nur Textdateien prüfen
  file -b "$file" 2>/dev/null | grep -qi text || continue
  for pat in "${PATTERNS[@]}"; do
    if grep -qE "$pat" "$file" 2>/dev/null; then
      if ! echo "$file" | grep -qE "$WHITELIST"; then
        echo "❌ SECRET-SCAN: $file enthält potenzielles Secret: $pat"
        fail=1
      fi
    fi
  done
done

if [ "$fail" -eq 1 ]; then
  echo "Commit abgebrochen — echte Secrets dürfen nie in Git."
  exit 1
fi
exit 0
