#!/bin/bash

set -euo pipefail

OUT="test_logs"
mkdir -p "$OUT/apache_style" "$OUT/json_logs" "$OUT/microservices_sim" "$OUT/noisy"

now_epoch() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

RANDOM_MESSAGES=("Request succeeded" "User login" "Token expired" "DB query slow" "Connection refused" "Cache miss" "Background job finished" "Timeout while calling API" "Failed to serialize response" "Permission denied")

# 1) Apache-style access log (common log format)
apache="$OUT/apache_style/access.log"
: > "$apache"
for i in $(seq 1 60); do
  ts=$(date -u -v-"$((RANDOM%60))"S +"%d/%b/%Y:%H:%M:%S +0000")
  ip="192.168.$((RANDOM%10)).$((RANDOM%255))"
  method=(GET POST PUT DELETE)
  path=("/" "/api/users" "/api/orders" "/login" "/static/img.png")
  code=(200 200 200 201 204 301 302 400 401 403 404 500 502)
  echo "$ip - - [$ts] \"${method[$RANDOM % ${#method[@]}]} ${path[$RANDOM % ${#path[@]}]} HTTP/1.1\" ${code[$RANDOM % ${#code[@]}]} $((RANDOM%5000+100))" >> "$apache"
done

# 2) JSON-structured logs (one JSON object per line)
json="$OUT/json_logs/app.jsonl"
: > "$json"
for i in $(seq 1 60); do
  ts=$(date -u -v-"$((RANDOM%3600))"S +"%Y-%m-%dT%H:%M:%SZ")
  svc=("api-service" "auth-service" "db-service" "worker")
  level_options=("INFO" "WARNING" "ERROR")
  lvl=${level_options[$RANDOM % ${#level_options[@]}]}
  msg="${RANDOM_MESSAGES[$RANDOM % ${#RANDOM_MESSAGES[@]}]}"
  echo "{\"timestamp\":\"$ts\",\"service\":\"${svc[$RANDOM % ${#svc[@]}]}\",\"level\":\"$lvl\",\"message\":\"$msg\",\"request_id\":\"req-$RANDOM\"}" >> "$json"
done

# 3) Microservices human-readable logs (service prefix + level)
micro_base="$OUT/microservices_sim"
: > "$micro_base/api.log"
: > "$micro_base/auth.log"
: > "$micro_base/db.log"
for i in $(seq 1 45); do
  ts=$(date -u -v-"$((RANDOM%7200))"S +"%Y-%m-%d %H:%M:%S")
  # api
  echo "$ts INFO api-service Request processed /api/items" >> "$micro_base/api.log"
  if (( RANDOM % 12 == 0 )); then
    echo "$ts ERROR api-service Request failed: 502 Bad Gateway" >> "$micro_base/api.log"
  fi
  if (( RANDOM % 8 == 0 )); then
    echo "$ts WARNING api-service High latency (>500ms)" >> "$micro_base/api.log"
  fi
  # auth
  echo "$ts INFO auth-service User login attempt user_id=$((1000 + RANDOM%200))" >> "$micro_base/auth.log"
  if (( RANDOM % 15 == 0 )); then
    echo "$ts ERROR auth-service Token validation failed" >> "$micro_base/auth.log"
  fi
  if (( RANDOM % 9 == 0 )); then
    echo "$ts WARNING auth-service Token nearing expiry" >> "$micro_base/auth.log"
  fi
  # db
  echo "$ts INFO database-service Query executed" >> "$micro_base/db.log"
  if (( RANDOM % 10 == 0 )); then
    echo "$ts ERROR database-service Connection timeout after 30s" >> "$micro_base/db.log"
  fi
  if (( RANDOM % 7 == 0 )); then
    echo "$ts WARNING database-service Slow query detected" >> "$micro_base/db.log"
  fi
done

# 4) Noisy / malformed
noisy="$OUT/noisy/noisy.log"
: > "$noisy"
echo "Startup sequence initiated" >> "$noisy"
for i in $(seq 1 30); do
  if (( RANDOM % 5 == 0 )); then
    echo "### random debug ### $(date -u +"%H:%M:%S")" >> "$noisy"
  else
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") INFO some-service ${RANDOM_MESSAGES[$RANDOM % ${#RANDOM_MESSAGES[@]}]}" >> "$noisy"
  fi
  if (( RANDOM % 11 == 0 )); then
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") ERROR subtle issue detected" >> "$noisy"
  fi
done

echo "Generated demo logs in $OUT (apache_style, json_logs, microservices_sim, noisy)"