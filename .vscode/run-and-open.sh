#!/bin/sh
# Run docker compose, then open the page of each service that was started.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
cd "$(dirname "$0")/.." || exit 1
docker compose "$@" || exit $?

services=""
skip_next=0
for arg in "$@"; do
  if [ $skip_next = 1 ]; then skip_next=0; continue; fi
  case "$arg" in
    -f|--file|-p|--project-name|--profile|--env-file) skip_next=1 ;;
    -*|up) ;;
    *) services="$services $arg" ;;
  esac
done
[ -z "$services" ] && services="admin client api"

for s in $services; do
  case "$s" in
    admin)  url="http://localhost:8002" ;;
    client) url="http://localhost:8081" ;;
    api)    url="http://localhost:8001/docs" ;;
    *)      continue ;;
  esac
  echo "Opening $s: $url"
  open "$url"
done
