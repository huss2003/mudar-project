#!/bin/bash
# Jasfo n8n Credential Setup Script
# Usage: N8N_URL=http://localhost:5678 bash setup-credentials.sh

N8N_URL="${N8N_URL:-http://localhost:5678}"
API_KEY="${N8N_API_KEY:-}"

AUTH=""
if [ -n "$API_KEY" ]; then
  AUTH="-H 'X-N8N-API-KEY: $API_KEY'"
fi

echo "=== Jasfo Credential Setup ==="
echo "Target: $N8N_URL"
echo ""

# 1. Supabase DB (Postgres)
echo "Creating Supabase DB credential..."
curl -s -X POST "$N8N_URL/api/v1/credentials" \
  $AUTH \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Supabase DB",
    "type": "postgres",
    "data": {
      "host": "db.nswlrolnbvjzgbkyxrkp.supabase.co",
      "port": 5432,
      "database": "postgres",
      "user": "postgres",
      "password": "2j@n2006H1234",
      "ssl": true,
      "sslDefaults": true
    }
  }' | jq .

# 2. Jasfo Telegram Bot
echo "Creating Telegram Bot credential..."
curl -s -X POST "$N8N_URL/api/v1/credentials" \
  $AUTH \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Jasfo Telegram Bot",
    "type": "telegramApi",
    "data": {
      "accessToken": "8688503635:AAH4obxx3lGXYhoke1hR8mFJvoTvflVRrnE"
    }
  }' | jq .

# 3. OpenCode GO API (HTTP Header Auth)
echo "Creating OpenCode GO credential..."
curl -s -X POST "$N8N_URL/api/v1/credentials" \
  $AUTH \
  -H "Content-Type: application/json" \
  -d '{
    "name": "OpenCode GO API",
    "type": "httpHeaderAuth",
    "data": {
      "name": "Authorization",
      "value": "Bearer sk-MmeX9RLWQrIFngobzyoLIoVjLx58ObW5ZhUmqYbwhPucZc8Nn46jQbvw4Vuf2yCA"
    }
  }' | jq .

# 4. Firecrawl API (HTTP Header Auth)
echo "Creating Firecrawl API credential..."
curl -s -X POST "$N8N_URL/api/v1/credentials" \
  $AUTH \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Firecrawl API",
    "type": "httpHeaderAuth",
    "data": {
      "name": "Authorization",
      "value": "Bearer fc-03ee582d75c647c59555df35374d8fa2"
    }
  }' | jq .

echo ""
echo "=== Done ==="
echo "Set N8N_URL=http://your-n8n-host:port if not on localhost:5678"
echo "Set N8N_API_KEY=your-key if using API key auth (Settings > API Tokens)"
