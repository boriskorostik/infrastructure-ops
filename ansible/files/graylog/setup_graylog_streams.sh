#!/usr/bin/env bash
set -euo pipefail

BASE=${GRAYLOG_BASE:-http://127.0.0.1:9000/api}
AUTH=${GRAYLOG_AUTH:?set GRAYLOG_AUTH as user:password}
INDEX_SET_ID=${GRAYLOG_INDEX_SET_ID:-}

api() {
  curl -s -u "$AUTH" -H "X-Requested-By: cli" -H "Content-Type: application/json" "$@"
}

get_default_index_set() {
  curl -s -u "$AUTH" -H "X-Requested-By: cli" "$BASE/system/indices/index_sets" |
    jq -r '.index_sets[] | select(.default == true) | .id' | head -n1
}

stream_id_by_title() {
  local title=$1
  curl -s -u "$AUTH" -H "X-Requested-By: cli" "$BASE/streams" |
    jq -r --arg title "$title" '.streams[] | select(.title == $title) | .id' |
    head -n1
}

ensure_stream() {
  local title=$1
  local description=$2
  local sid

  sid=$(stream_id_by_title "$title")
  if [[ -z "$sid" ]]; then
    sid=$(
      jq -n \
        --arg title "$title" \
        --arg description "$description" \
        --arg index_set_id "$INDEX_SET_ID" \
        '{
          title: $title,
          description: $description,
          matching_type: "OR",
          remove_matches_from_default_stream: false,
          index_set_id: $index_set_id
        }' |
        api -X POST "$BASE/streams" -d @- |
        jq -r '.stream_id // .id'
    )
    api -X POST "$BASE/streams/$sid/resume" >/dev/null
  fi

  echo "$sid"
}

ensure_rule() {
  local sid=$1
  local field=$2
  local value=$3
  local type=${4:-1}
  local description=${5:-"$field $value"}
  local exists

  exists=$(
    curl -s -u "$AUTH" -H "X-Requested-By: cli" "$BASE/streams/$sid/rules" |
      jq -r \
        --arg field "$field" \
        --arg value "$value" \
        --argjson type "$type" \
        '.stream_rules[]? |
          select(.field == $field and .value == $value and .type == $type and .inverted == false) |
          .id' |
      head -n1
  )

  if [[ -z "$exists" ]]; then
    jq -n \
      --arg field "$field" \
      --arg value "$value" \
      --arg description "$description" \
      --argjson type "$type" \
      '{
        type: $type,
        field: $field,
        value: $value,
        inverted: false,
        description: $description
      }' |
      api -X POST "$BASE/streams/$sid/rules" -d @- >/dev/null
  fi
}

make_source_stream() {
  local title=$1
  local source=$2
  local sid

  sid=$(ensure_stream "$title" "Logs for $title")
  ensure_rule "$sid" source "$source" 1 "source $source"
  printf '%s -> source:%s\n' "$title" "$source"
}

if [[ -z "$INDEX_SET_ID" ]]; then
  INDEX_SET_ID=$(get_default_index_set)
fi

make_source_stream "Object armbereg" "disp-23IGLG"
make_source_stream "Object armleaves" "armlives-310SC"
make_source_stream "Object armstories" "user"
make_source_stream "Object armstories2" "serp"
make_source_stream "Object armsky" "sere"
make_source_stream "Object pes4kainhome" "sandboxinhome"
make_source_stream "Object mikrot" "microt"
make_source_stream "Object firewall" "firewall-support"

sid=$(ensure_stream "CLVR Watchdog" "CLVR watchdog and systemd watchdog events")
ensure_rule "$sid" message "watchdog" 0 "message contains watchdog"
printf '%s -> message:watchdog\n' "CLVR Watchdog"

sid=$(ensure_stream "A7 Crashes and Restarts" "A7 crashes, stack traces and service restarts")
ensure_rule "$sid" message "A7HandlerCrash" 0 "A7 crash handler"
ensure_rule "$sid" message "a7smartbuildingserver.service" 0 "A7 service"
ensure_rule "$sid" message "/opt/A7SmartBuilding" 0 "A7 stack or path"
printf '%s -> A7 crash/service patterns\n' "A7 Crashes and Restarts"
