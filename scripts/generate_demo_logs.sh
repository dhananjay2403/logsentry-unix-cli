#!/usr/bin/env bash
#
# Regenerates the realistic demo log datasets used for screenshots and manual
# testing: an Apache-style access log, JSON lines, a multi-service set, and a
# noisy/malformed log.
#
# Runs on both macOS and Linux: BSD date and GNU date disagree about relative
# times, so the style is detected once up front (see seconds_ago).

set -euo pipefail

OUT="${1:-tests/fixtures/realistic}"
mkdir -p "$OUT/apache_style" "$OUT/json_logs" "$OUT/microservices_sim" "$OUT/noisy"

# BSD date (macOS) offsets with -v, GNU date (Linux) with -d.
if date -u -v-1S +%s >/dev/null 2>&1; then
  DATE_STYLE="bsd"
else
  DATE_STYLE="gnu"
fi

seconds_ago() { # seconds format -> formatted timestamp that many seconds ago
  if [ "$DATE_STYLE" = "bsd" ]; then
    date -u -v-"$1"S +"$2"
  else
    date -u -d "@$(($(date -u +%s) - $1))" +"$2"
  fi
}

MESSAGES=(
  "Request succeeded" "User login" "Token expired" "DB query slow"
  "Connection refused" "Cache miss" "Background job finished"
  "Timeout while calling API" "Failed to serialize response" "Permission denied"
)
METHODS=(GET POST PUT DELETE)
PATHS=("/" "/api/users" "/api/orders" "/login" "/static/img.png")
CODES=(200 200 200 201 204 301 302 400 401 403 404 500 502)
SERVICES=("api-service" "auth-service" "db-service" "worker")
LEVELS=(INFO WARNING ERROR)

# 1) Apache-style access log (common log format)
apache="$OUT/apache_style/access.log"
: > "$apache"
for _ in $(seq 1 60); do
  ts=$(seconds_ago "$((RANDOM % 60))" "%d/%b/%Y:%H:%M:%S +0000")
  ip="192.168.$((RANDOM % 10)).$((RANDOM % 255))"
  printf '%s - - [%s] "%s %s HTTP/1.1" %s %s\n' \
    "$ip" "$ts" "${METHODS[$RANDOM % ${#METHODS[@]}]}" \
    "${PATHS[$RANDOM % ${#PATHS[@]}]}" "${CODES[$RANDOM % ${#CODES[@]}]}" \
    "$((RANDOM % 5000 + 100))" >> "$apache"
done

# 2) JSON-structured logs (one JSON object per line)
json="$OUT/json_logs/app.jsonl"
: > "$json"
for _ in $(seq 1 60); do
  ts=$(seconds_ago "$((RANDOM % 3600))" "%Y-%m-%dT%H:%M:%SZ")
  printf '{"timestamp":"%s","service":"%s","level":"%s","message":"%s","request_id":"req-%s"}\n' \
    "$ts" "${SERVICES[$RANDOM % ${#SERVICES[@]}]}" "${LEVELS[$RANDOM % ${#LEVELS[@]}]}" \
    "${MESSAGES[$RANDOM % ${#MESSAGES[@]}]}" "$RANDOM" >> "$json"
done

# 3) Microservices logs (service prefix + level), one file per service
micro="$OUT/microservices_sim"
: > "$micro/api.log"
: > "$micro/auth.log"
: > "$micro/db.log"
for _ in $(seq 1 45); do
  ts=$(seconds_ago "$((RANDOM % 7200))" "%Y-%m-%d %H:%M:%S")

  printf '%s INFO api-service Request processed /api/items\n' "$ts" >> "$micro/api.log"
  if ((RANDOM % 12 == 0)); then
    printf '%s ERROR api-service Request failed: 502 Bad Gateway\n' "$ts" >> "$micro/api.log"
  fi
  if ((RANDOM % 8 == 0)); then
    printf '%s WARNING api-service High latency (>500ms)\n' "$ts" >> "$micro/api.log"
  fi

  printf '%s INFO auth-service User login attempt user_id=%s\n' "$ts" "$((1000 + RANDOM % 200))" >> "$micro/auth.log"
  if ((RANDOM % 15 == 0)); then
    printf '%s ERROR auth-service Token validation failed\n' "$ts" >> "$micro/auth.log"
  fi
  if ((RANDOM % 9 == 0)); then
    printf '%s WARNING auth-service Token nearing expiry\n' "$ts" >> "$micro/auth.log"
  fi

  printf '%s INFO database-service Query executed\n' "$ts" >> "$micro/db.log"
  if ((RANDOM % 10 == 0)); then
    printf '%s ERROR database-service Connection timeout after 30s\n' "$ts" >> "$micro/db.log"
  fi
  if ((RANDOM % 7 == 0)); then
    printf '%s WARNING database-service Slow query detected\n' "$ts" >> "$micro/db.log"
  fi
done

# 4) Noisy / malformed log
noisy="$OUT/noisy/noisy.log"
: > "$noisy"
printf 'Startup sequence initiated\n' >> "$noisy"
for _ in $(seq 1 30); do
  ts=$(seconds_ago 0 "%Y-%m-%dT%H:%M:%SZ")
  if ((RANDOM % 5 == 0)); then
    printf '### random debug ### %s\n' "$(seconds_ago 0 '%H:%M:%S')" >> "$noisy"
  else
    printf '%s INFO some-service %s\n' "$ts" "${MESSAGES[$RANDOM % ${#MESSAGES[@]}]}" >> "$noisy"
  fi
  if ((RANDOM % 11 == 0)); then
    printf '%s ERROR subtle issue detected\n' "$ts" >> "$noisy"
  fi
done

printf 'Generated demo logs in %s (apache_style, json_logs, microservices_sim, noisy)\n' "$OUT"
