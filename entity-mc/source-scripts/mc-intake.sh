#!/usr/bin/env bash
# Entity MC Intake — create Mission Control tasks from structured external signals.
#
# Conservative by design: this script does not watch chats or infer broad intent.
# Source-specific watchers can feed it explicit JSON/JSONL candidates.
set -euo pipefail

MC_URL="${ENTITY_MC_MC_URL:-${MC_URL:-http://localhost:3000}}"
AGENT="${MC_USER:-${ENTITY_MC_AGENT_NAME:-Agent}}"
CURL_MAX_TIME="${MC_CURL_MAX_TIME:-20}"
DEFAULT_COLUMN="${ENTITY_MC_INTAKE_DEFAULT_COLUMN:-backlog}"
DEFAULT_ASSIGNEE="${ENTITY_MC_INTAKE_DEFAULT_ASSIGNEE:-Enterprise Crew}"
STATE_DIR="${ENTITY_MC_STATE_DIR:-${HOME}/.entity-mc}"
INTAKE_STATE_DIR="${ENTITY_MC_INTAKE_STATE_DIR:-${STATE_DIR}/intake}"
SEEN_FILE="${ENTITY_MC_INTAKE_SEEN_FILE:-${INTAKE_STATE_DIR}/seen.jsonl}"
mkdir -p "$INTAKE_STATE_DIR"

usage() {
  cat <<'EOF'
Entity MC Intake

Commands:
  create --title TITLE [--description TEXT] [--assignee NAME] [--column backlog|todo]
         [--priority P1|P2|P3] [--model MODEL] [--skill SKILL]
         [--context a,b] [--source SOURCE] [--source-id ID] [--url URL]
         [--project PROJECT] [--estimate HOURS] [--dry-run] [--create-anyway]

  ingest --json [--dry-run]
         Read one JSON object from stdin. Accepted keys:
         title/name, description, assignee, column, priority, model, skill,
         context, source, source_id/sourceId, url, project, estimate_hours,
         create_anyway/createAnyway.

  scan-file PATH [--dry-run]
         Read JSONL file and ingest each line as one candidate.

  review [--limit N]
         Show recent intake-created tasks.
EOF
}

normalize_title() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/ /g; s/^ +| +$//g; s/ +/ /g'
}

fingerprint() {
  local source="$1" source_id="$2" title="$3" url="$4"
  if [ -n "$source_id" ] && [ "$source_id" != "null" ]; then
    printf '%s:%s' "$source" "$source_id" | shasum -a 256 | awk '{print $1}'
  elif [ -n "$url" ] && [ "$url" != "null" ]; then
    printf 'url:%s' "$url" | shasum -a 256 | awk '{print $1}'
  else
    printf 'title:%s' "$(normalize_title "$title")" | shasum -a 256 | awk '{print $1}'
  fi
}

seen_fingerprint() {
  local fp="$1"
  [ -f "$SEEN_FILE" ] || return 1
  grep -q "\"fingerprint\":\"$fp\"" "$SEEN_FILE" 2>/dev/null
}

record_seen() {
  local fp="$1" task_id="$2" title="$3" source="$4" source_id="$5" url="$6"
  jq -cn \
    --arg fingerprint "$fp" \
    --arg task_id "$task_id" \
    --arg title "$title" \
    --arg source "$source" \
    --arg source_id "$source_id" \
    --arg url "$url" \
    --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{fingerprint:$fingerprint, task_id:$task_id, title:$title, source:$source, source_id:$source_id, url:$url, created_at:$created_at}' >> "$SEEN_FILE"
}

active_duplicate_id() {
  local title="$1" norm
  norm="$(normalize_title "$title")"
  curl -s --max-time "$CURL_MAX_TIME" "$MC_URL/api/tasks" | jq -r --arg norm "$norm" '
    (.tasks // .)[]?
    | select((.column // "") as $c | ["backlog","todo","doing","review"] | index($c))
    | select(((.name // "") | ascii_downcase | gsub("[^a-z0-9]+"; " ") | gsub("^ +| +$"; "") | gsub(" +"; " ")) == $norm)
    | .id
  ' 2>/dev/null | head -1
}

build_payload() {
  local title="$1" desc="$2" assignee="$3" column="$4" priority="$5" model="$6" skill="$7" context="$8" source="$9" source_id="${10}" url="${11}" project="${12}" estimate="${13}" create_anyway="${14}"
  jq -cn \
    --arg name "$title" \
    --arg description "$desc" \
    --arg assignee "$assignee" \
    --arg column "$column" \
    --arg priority "$priority" \
    --arg model "$model" \
    --arg skill "$skill" \
    --arg context "$context" \
    --arg source "$source" \
    --arg source_id "$source_id" \
    --arg url "$url" \
    --arg project "$project" \
    --arg estimate "$estimate" \
    --arg actor "$AGENT" \
    --argjson create_anyway "$create_anyway" '
      {
        name:$name,
        description:$description,
        assignee:$assignee,
        column:$column,
        created_by:$actor,
        actor:$actor,
        create_anyway:$create_anyway,
        origin_channel:(if $source != "" then $source else null end),
        metadata:({
          intake: true,
          source: (if $source != "" then $source else null end),
          source_id: (if $source_id != "" then $source_id else null end),
          url: (if $url != "" then $url else null end),
          skill: (if $skill != "" then $skill else null end),
          context: (if $context != "" then ($context | split(",") | map(select(length>0))) else [] end),
          created_by: $actor
        } | with_entries(select(.value != null)) | tostring)
      }
      + (if $priority != "" then {priority:$priority} else {} end)
      + (if $model != "" then {model:$model} else {} end)
      + (if $project != "" then {project:$project} else {} end)
      + (if $estimate != "" then {estimate_hours:($estimate|tonumber)} else {} end)
    '
}

create_task() {
  local title="$1" desc="$2" assignee="$3" column="$4" priority="$5" model="$6" skill="$7" context="$8" source="$9" source_id="${10}" url="${11}" project="${12}" estimate="${13}" dry_run="${14}" create_anyway="${15}"
  [ -n "$title" ] || { jq -n '{action:"error", error:"title required"}'; return 2; }
  local fp existing_id payload response status body tmp
  fp="$(fingerprint "$source" "$source_id" "$title" "$url")"
  if [ "$create_anyway" != "true" ]; then
    if seen_fingerprint "$fp"; then
      jq -n --arg fp "$fp" --arg title "$title" '{action:"skip", reason:"seen_fingerprint", fingerprint:$fp, title:$title}'
      return 0
    fi
    existing_id="$(active_duplicate_id "$title" || true)"
    if [ -n "$existing_id" ] && [ "$existing_id" != "null" ]; then
      jq -n --arg id "$existing_id" --arg title "$title" '{action:"skip", reason:"active_duplicate", task_id:($id|tonumber), title:$title}'
      return 0
    fi
  fi
  payload="$(build_payload "$title" "$desc" "$assignee" "$column" "$priority" "$model" "$skill" "$context" "$source" "$source_id" "$url" "$project" "$estimate" "$create_anyway")"
  if [ "$dry_run" = "true" ]; then
    jq -n --argjson payload "$payload" --arg fp "$fp" '{action:"dry_run", fingerprint:$fp, payload:$payload}'
    return 0
  fi
  tmp="$(mktemp)"
  status="$(curl -sS --max-time "$CURL_MAX_TIME" -w '%{http_code}' -o "$tmp" -X POST "$MC_URL/api/tasks" -H 'Content-Type: application/json' -H "X-Agent-Name: $AGENT" -d "$payload" 2>/dev/null || echo 000)"
  body="$(cat "$tmp")"; rm -f "$tmp"
  if [ "$status" = "200" ] || [ "$status" = "201" ]; then
    local task_id
    task_id="$(printf '%s' "$body" | jq -r '.id // .task.id // empty' 2>/dev/null)"
    [ -n "$task_id" ] && record_seen "$fp" "$task_id" "$title" "$source" "$source_id" "$url"
    printf '%s' "$body" | jq --arg fp "$fp" '. + {intake:{action:"created", fingerprint:$fp}}'
    return 0
  fi
  printf '%s' "$body" | jq --arg status "$status" --arg fp "$fp" '. + {intake:{action:"error", status:$status, fingerprint:$fp}}' 2>/dev/null || jq -n --arg status "$status" --arg body "$body" --arg fp "$fp" '{action:"error", status:$status, body:$body, fingerprint:$fp}'
  return 1
}

parse_json_and_create() {
  local dry_run="$1" input
  input="$(cat)"
  jq -e . >/dev/null <<< "$input"
  local title desc assignee column priority model skill context source source_id url project estimate create_anyway
  title="$(jq -r '.title // .name // empty' <<< "$input")"
  desc="$(jq -r '.description // .body // .text // empty' <<< "$input")"
  assignee="$(jq -r '.assignee // empty' <<< "$input")"; [ -n "$assignee" ] || assignee="$DEFAULT_ASSIGNEE"
  column="$(jq -r '.column // empty' <<< "$input")"; [ -n "$column" ] || column="$DEFAULT_COLUMN"
  priority="$(jq -r '.priority // empty' <<< "$input")"
  model="$(jq -r '.model // empty' <<< "$input")"
  skill="$(jq -r '.skill // empty' <<< "$input")"
  context="$(jq -r 'if (.context|type)=="array" then .context|join(",") else (.context // "") end' <<< "$input")"
  source="$(jq -r '.source // empty' <<< "$input")"
  source_id="$(jq -r '.source_id // .sourceId // empty' <<< "$input")"
  url="$(jq -r '.url // empty' <<< "$input")"
  project="$(jq -r '.project // empty' <<< "$input")"
  estimate="$(jq -r '.estimate_hours // .estimate // empty' <<< "$input")"
  create_anyway="$(jq -r '(.create_anyway // .createAnyway // false) | if . then "true" else "false" end' <<< "$input")"
  create_task "$title" "$desc" "$assignee" "$column" "$priority" "$model" "$skill" "$context" "$source" "$source_id" "$url" "$project" "$estimate" "$dry_run" "$create_anyway"
}

cmd="${1:-help}"; shift || true
case "$cmd" in
  create|add|new)
    title=""; desc=""; assignee="$DEFAULT_ASSIGNEE"; column="$DEFAULT_COLUMN"; priority=""; model=""; skill=""; context=""; source="manual"; source_id=""; url=""; project=""; estimate=""; dry_run="false"; create_anyway="false"
    while [ $# -gt 0 ]; do
      case "$1" in
        --title|--name) title="$2"; shift 2 ;; --description|--desc|--body) desc="$2"; shift 2 ;;
        --assignee) assignee="$2"; shift 2 ;; --column) column="$2"; shift 2 ;;
        --priority) priority="$2"; shift 2 ;; --model) model="$2"; shift 2 ;;
        --skill) skill="$2"; shift 2 ;; --context) context="$2"; shift 2 ;;
        --source) source="$2"; shift 2 ;; --source-id|--sourceId) source_id="$2"; shift 2 ;;
        --url) url="$2"; shift 2 ;; --project) project="$2"; shift 2 ;;
        --estimate|--estimate-hours) estimate="$2"; shift 2 ;; --dry-run) dry_run="true"; shift ;;
        --create-anyway|--dedupe-override) create_anyway="true"; shift ;; --help|-h) usage; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
      esac
    done
    create_task "$title" "$desc" "$assignee" "$column" "$priority" "$model" "$skill" "$context" "$source" "$source_id" "$url" "$project" "$estimate" "$dry_run" "$create_anyway"
    ;;
  ingest)
    dry_run="false"; while [ $# -gt 0 ]; do case "$1" in --json) shift ;; --dry-run) dry_run="true"; shift ;; --help|-h) usage; exit 0 ;; *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;; esac; done
    parse_json_and_create "$dry_run"
    ;;
  scan-file)
    file="${1:-}"; shift || true; dry_run="false"; while [ $# -gt 0 ]; do case "$1" in --dry-run) dry_run="true"; shift ;; *) shift ;; esac; done
    [ -f "$file" ] || { echo "scan-file requires existing JSONL path" >&2; exit 2; }
    while IFS= read -r line; do [ -z "$line" ] && continue; printf '%s' "$line" | parse_json_and_create "$dry_run"; done < "$file"
    ;;
  review|recent)
    limit="20"; while [ $# -gt 0 ]; do case "$1" in --limit) limit="$2"; shift 2 ;; *) shift ;; esac; done
    curl -s --max-time "$CURL_MAX_TIME" "$MC_URL/api/tasks" | jq --argjson limit "$limit" '[.tasks[]? // .[]? | select((.metadata // "") | contains("\"intake\":true"))] | sort_by(.created_at) | reverse | .[:$limit] | map({id,name,column,assignee,created_at,origin_channel,metadata})'
    ;;
  help|--help|-h) usage ;;
  *) echo "Unknown command: $cmd" >&2; usage >&2; exit 2 ;;
esac
