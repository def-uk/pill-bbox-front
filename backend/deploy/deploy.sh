#!/usr/bin/env bash
# 맥미니에서 백엔드를 배포한다 (backend/README.md 5.3). deploy-backend.yml이 git pull 뒤에 부른다.
#
#   bash backend/deploy/deploy.sh
#
# 두 프로세스를 launchd로 띄운다.
#   com.pillbbox.api  127.0.0.1:8100  API (app.main)        ← api.<도메인>
#   com.pillbbox.web  127.0.0.1:8200  웹 빌드 (app.web)      ← www.<도메인>
# 웹 빌드 파일은 deploy-web.yml이 따로 올린다. 이 스크립트는 그 파일을 내보내는 서버만 띄운다.
#
# 처음 실행이면 데이터 폴더, .env, launchd 에이전트를 만든다. 그다음부터는 의존성을 맞추고 다시 띄운다.
# API의 /health가 지금 커밋을 돌려주지 않으면 직전 배포 커밋으로 되돌리고 실패로 끝낸다.
set -euo pipefail

API_PORT=8100
WEB_PORT=8200

# 스크립트 전체를 먼저 읽고 나서 실행한다. 되돌리기(git reset)가 실행 중인 이 파일을 바꿔도 안전하다.
main() {
  # SSH로 들어온 셸에는 Homebrew 경로가 없다.
  export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

  local backend repo data
  backend="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  repo="$(cd "$backend/.." && pwd)"
  data="${PILLBBOX_DATA:-$HOME/srv/pillbbox-data}"

  command -v uv > /dev/null || fail "uv가 없습니다. 맥미니에서 brew install uv"
  launchctl print "gui/$(id -u)" > /dev/null 2>&1 \
    || fail "로그인한 세션이 없습니다. 맥미니에 한 번 로그인해 주세요 (FileVault를 켠 맥은 재부팅 뒤 필요)"

  mkdir -p "$data/data/samples" "$data/backups" "$data/logs" "$data/web/releases"
  if [[ ! -f $data/.env ]]; then
    cat > "$data/.env" << EOF
PILLBBOX_DATABASE_URL=sqlite:///$data/data/pillbbox.db
PILLBBOX_SAMPLES_DIR=$data/data/samples
PILLBBOX_CORS_ORIGINS=http://localhost:8080
PILLBBOX_COMMIT=
EOF
    log ".env를 만들었습니다: $data/.env. 웹 주소(https://www.<도메인>)를 PILLBBOX_CORS_ORIGINS에 넣어 주세요"
  fi
  # 예전에 만든 .env에는 웹 폴더가 없다.
  grep -q '^PILLBBOX_WEB_DIR=' "$data/.env" || echo "PILLBBOX_WEB_DIR=$data/web/current" >> "$data/.env"

  local commit previous
  commit="$(git -C "$repo" rev-parse HEAD)"
  previous="$(cat "$data/deployed" 2> /dev/null || true)"
  log "배포: ${commit:0:7} (직전 ${previous:0:7})"

  backup_db "$data"
  if start "$backend" "$data" "$commit"; then
    echo "$commit" > "$data/deployed"
    log "완료: ${commit:0:7}"
    return 0
  fi

  log "새 버전이 뜨지 않았습니다. 로그: $data/logs/"
  tail -n 30 "$data/logs/api.log" "$data/logs/web.log" >&2 || true
  if [[ -n $previous && $previous != "$commit" ]]; then
    log "직전 배포 ${previous:0:7}로 되돌립니다"
    git -C "$repo" reset --hard "$previous"
    start "$backend" "$data" "$previous" || log "되돌린 버전도 뜨지 않았습니다"
  fi
  return 1
}

# 의존성을 맞추고 두 에이전트를 다시 띄운 뒤, API가 [commit]을 돌려주고 웹 서버가 답하는지 본다.
start() {
  local backend=$1 data=$2 commit=$3
  (cd "$backend" && uv sync --frozen --no-dev --quiet)

  # .env의 커밋을 바꾼다. 다른 줄은 그대로 둔다.
  grep -v '^PILLBBOX_COMMIT=' "$data/.env" > "$data/.env.tmp" || true
  echo "PILLBBOX_COMMIT=$commit" >> "$data/.env.tmp"
  mv "$data/.env.tmp" "$data/.env"

  agent "$backend" "$data" com.pillbbox.api app.main:create_app "$API_PORT" api
  agent "$backend" "$data" com.pillbbox.web app.web:create_app "$WEB_PORT" web

  local i api_ok="" web_ok=""
  for i in $(seq 1 20); do
    [[ -z $api_ok ]] && curl -sf "http://127.0.0.1:$API_PORT/health" \
      | grep -q "\"commit\":\"$commit\"" && api_ok=1
    # 웹은 첫 웹 배포 전이면 404다. 답만 하면 된다.
    [[ -z $web_ok ]] && [[ $(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$WEB_PORT/") != 000 ]] \
      && web_ok=1
    [[ -n $api_ok && -n $web_ok ]] && return 0
    sleep 1
  done
  [[ -n $api_ok ]] || log "API가 답하지 않습니다"
  [[ -n $web_ok ]] || log "웹 서버가 답하지 않습니다"
  return 1
}

# launchd 에이전트를 틀(launchd.plist)에서 만들어 등록하거나 다시 띄운다.
agent() {
  local backend=$1 data=$2 label=$3 app=$4 port=$5 logname=$6
  local plist="$HOME/Library/LaunchAgents/$label.plist"
  mkdir -p "$(dirname "$plist")"
  sed -e "s|__UV__|$(command -v uv)|" -e "s|__DATA__|$data|g" -e "s|__BACKEND__|$backend|" \
    -e "s|__LABEL__|$label|" -e "s|__APP__|$app|" -e "s|__PORT__|$port|" -e "s|__LOG__|$logname|g" \
    "$backend/deploy/launchd.plist" > "$plist.new"
  if launchctl print "gui/$(id -u)/$label" > /dev/null 2>&1 && cmp -s "$plist" "$plist.new"; then
    rm "$plist.new"
    launchctl kickstart -k "gui/$(id -u)/$label"
    return 0
  fi

  # 처음이거나 plist가 바뀌었으면 다시 등록한다.
  launchctl bootout "gui/$(id -u)/$label" 2> /dev/null || true
  mv "$plist.new" "$plist"
  # bootout이 끝나기 전에 bootstrap하면 실패하므로 몇 번 다시 해 본다.
  local tries
  for tries in 1 2 3 4 5; do
    launchctl bootstrap "gui/$(id -u)" "$plist" 2> /dev/null && return 0
    sleep 1
  done
  fail "launchd에 등록하지 못했습니다: $plist"
}

# 배포 전에 DB를 복사해 둔다. 14일 넘은 복사본은 지운다.
backup_db() {
  local data=$1 db="$1/data/pillbbox.db"
  [[ -f $db ]] || return 0
  sqlite3 "$db" ".backup '$data/backups/pillbbox-$(date +%Y%m%d-%H%M%S).db'"
  find "$data/backups" -name 'pillbbox-*.db' -mtime +14 -delete
}

log() { echo "[deploy] $*"; }
fail() {
  echo "[deploy] $*" >&2
  exit 1
}

main "$@"
exit $?
