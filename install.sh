#!/usr/bin/env bash
set -euo pipefail

INSTALLER_VERSION="0.1.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ENV="$SCRIPT_DIR/.env"
COMPOSE_TEMPLATE="$SCRIPT_DIR/docker-compose.yml.example"
BACKUP_DIR_NAME="backups"

log()  { echo "[i] $*"; }
ok()   { echo "[✔] $*"; }
warn() { echo "[!] $*"; }
err()  { echo "[x] $*" >&2; exit 1; }

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

require_root() {
  [[ "$EUID" -eq 0 ]] || err "Запусти так: sudo bash install.sh"
}

ask() {
  local prompt="$1" default="${2:-}" answer
  if [[ -n "$default" ]]; then
    read -r -p "$prompt [$default]: " answer || true
    answer="$(trim "$answer")"
    printf '%s' "${answer:-$default}"
  else
    read -r -p "$prompt: " answer || true
    printf '%s' "$(trim "$answer")"
  fi
}

ask_secret() {
  local prompt="$1" default="${2:-}" answer
  read -r -s -p "$prompt [$default]: " answer || true
  echo
  answer="$(trim "$answer")"
  printf '%s' "${answer:-$default}"
}

ask_yes_no() {
  local prompt="$1" default="${2:-Y}" answer shown
  if [[ "$default" == "Y" ]]; then shown='[Y/n]'; else shown='[y/N]'; fi
  read -r -p "$prompt $shown: " answer || true
  answer="$(trim "$answer")"
  answer="${answer:-$default}"
  case "${answer,,}" in
    y|yes) return 0 ;;
    n|no) return 1 ;;
    *) [[ "$default" == "Y" ]] && return 0 || return 1 ;;
  esac
}

random_hex() { openssl rand -hex 32; }
random_password() { openssl rand -hex 16; }

ensure_requirements() {
  [[ -f "$COMPOSE_TEMPLATE" ]] || err "Не найден $COMPOSE_TEMPLATE"
  if ! command -v python3 >/dev/null 2>&1; then
    apt-get update >/dev/null 2>&1
    apt-get install -y python3 >/dev/null 2>&1
  fi
}

ensure_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    ok "Docker уже установлен"
    return
  fi
  log "Установка Docker..."
  apt-get update >/dev/null 2>&1
  apt-get install -y ca-certificates curl gnupg >/dev/null 2>&1
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
  ok "Docker установлен"
}

generate_jwt() {
  local secret="$1" role="$2"
  python3 - "$secret" "$role" <<'PY'
import base64, json, hmac, hashlib, sys, time
secret = sys.argv[1].encode()
role = sys.argv[2]
header = {"alg": "HS256", "typ": "JWT"}
payload = {"role": role, "iss": "supabase", "iat": int(time.time()), "exp": 2524608000}
def b64url(data: bytes) -> bytes:
    return base64.urlsafe_b64encode(data).rstrip(b'=')
segments = [b64url(json.dumps(header, separators=(",", ":")).encode()), b64url(json.dumps(payload, separators=(",", ":")).encode())]
signing_input = b'.'.join(segments)
signature = b64url(hmac.new(secret, signing_input, hashlib.sha256).digest())
print((signing_input + b'.' + signature).decode())
PY
}

write_env() {
  cat > "$PROJECT_ENV" <<EOF2
STACK_VERSION=$INSTALLER_VERSION
INSTALL_DIR=$INSTALL_DIR
SUPABASE_DB_IMAGE=supabase/postgres:15.8.1.048
SUPABASE_REST_IMAGE=postgrest/postgrest:v12.2.12
SUPABASE_AUTH_IMAGE=supabase/gotrue:v2.174.0
SUPABASE_META_IMAGE=supabase/postgres-meta:v0.89.3
SUPABASE_KONG_IMAGE=kong:2.8.1
SUPABASE_STUDIO_IMAGE=supabase/studio:2026.01.07-sha-037e5f9
STUDIO_CLI_VERSION=2.67.1
POSTGRES_HOSTNAME=supabase-db
POSTGRES_HOST=supabase-db
POSTGRES_PORT=5432
DB_PUBLIC_PORT=$DB_PUBLIC_PORT
POSTGRES_DB=$POSTGRES_DB
SERVICE_PASSWORD_POSTGRES=$SERVICE_PASSWORD_POSTGRES
SERVICE_PASSWORD_JWT=$SERVICE_PASSWORD_JWT
JWT_EXPIRY=$JWT_EXPIRY
KONG_HTTP_PORT=$KONG_HTTP_PORT
STUDIO_PORT=$STUDIO_PORT
EXTERNAL_MODE=$EXTERNAL_MODE
EXTERNAL_HOST=$EXTERNAL_HOST
SERVICE_URL_SUPABASEKONG=$SERVICE_URL_SUPABASEKONG
SERVICE_URL_SUPABASEKONG_8000=$SERVICE_URL_SUPABASEKONG_8000
API_EXTERNAL_URL=$API_EXTERNAL_URL
ADDITIONAL_REDIRECT_URLS=$ADDITIONAL_REDIRECT_URLS
SERVICE_USER_ADMIN=$SERVICE_USER_ADMIN
SERVICE_PASSWORD_ADMIN=$SERVICE_PASSWORD_ADMIN
SERVICE_SUPABASEANON_KEY=$SERVICE_SUPABASEANON_KEY
SERVICE_SUPABASESERVICE_KEY=$SERVICE_SUPABASESERVICE_KEY
DISABLE_SIGNUP=$DISABLE_SIGNUP
ENABLE_EMAIL_SIGNUP=true
ENABLE_ANONYMOUS_USERS=false
ENABLE_EMAIL_AUTOCONFIRM=false
ENABLE_PHONE_SIGNUP=true
ENABLE_PHONE_AUTOCONFIRM=true
SMTP_ADMIN_EMAIL=
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
SMTP_SENDER_NAME=
MAILER_URLPATHS_INVITE=/auth/v1/verify
MAILER_URLPATHS_CONFIRMATION=/auth/v1/verify
MAILER_URLPATHS_RECOVERY=/auth/v1/verify
MAILER_URLPATHS_EMAIL_CHANGE=/auth/v1/verify
STUDIO_DEFAULT_ORGANIZATION=Default Organization
STUDIO_DEFAULT_PROJECT=Default Project
OPENAI_API_KEY=
PGRST_DB_SCHEMAS=public,storage,graphql_public
EOF2
  chmod 600 "$PROJECT_ENV"
}

validate_env() {
  local bad
  bad="$(grep -nEv '^[A-Z0-9_]+=.*$|^#|^$' "$PROJECT_ENV" || true)"
  [[ -z "$bad" ]] || { echo "$bad"; err ".env поврежден"; }
}

check_required_templates() {
  local required=(
    "$SCRIPT_DIR/volumes/db/realtime.sql"
    "$SCRIPT_DIR/volumes/db/_supabase.sql"
    "$SCRIPT_DIR/volumes/db/pooler.sql"
    "$SCRIPT_DIR/volumes/db/webhooks.sql"
    "$SCRIPT_DIR/volumes/db/roles.sql"
    "$SCRIPT_DIR/volumes/db/jwt.sql"
    "$SCRIPT_DIR/volumes/db/logs.sql"
    "$SCRIPT_DIR/volumes/api/kong.yml"
  )
  local missing=0
  for f in "${required[@]}"; do
    if [[ ! -f "$f" ]]; then echo "[x] Не найден файл: $f"; missing=1; fi
  done
  [[ "$missing" -eq 0 ]] || err "Замени заглушки реальными SQL/Kong файлами перед установкой"
}

install_files() {
  log "Создание директорий..."
  mkdir -p "$INSTALL_DIR/$BACKUP_DIR_NAME" "$INSTALL_DIR/volumes/db" "$INSTALL_DIR/volumes/api"
  log "Копирование конфигурации..."
  cp "$COMPOSE_TEMPLATE" "$INSTALL_DIR/docker-compose.yml"
  cp "$PROJECT_ENV" "$INSTALL_DIR/.env"
  cp "$SCRIPT_DIR/volumes/db/realtime.sql" "$INSTALL_DIR/volumes/db/realtime.sql"
  cp "$SCRIPT_DIR/volumes/db/_supabase.sql" "$INSTALL_DIR/volumes/db/_supabase.sql"
  cp "$SCRIPT_DIR/volumes/db/pooler.sql" "$INSTALL_DIR/volumes/db/pooler.sql"
  cp "$SCRIPT_DIR/volumes/db/webhooks.sql" "$INSTALL_DIR/volumes/db/webhooks.sql"
  cp "$SCRIPT_DIR/volumes/db/roles.sql" "$INSTALL_DIR/volumes/db/roles.sql"
  cp "$SCRIPT_DIR/volumes/db/jwt.sql" "$INSTALL_DIR/volumes/db/jwt.sql"
  cp "$SCRIPT_DIR/volumes/db/logs.sql" "$INSTALL_DIR/volumes/db/logs.sql"
  cp "$SCRIPT_DIR/volumes/api/kong.yml" "$INSTALL_DIR/volumes/api/kong.yml"
  chmod 600 "$INSTALL_DIR/.env"
}

start_stack() {
  log "Запуск контейнеров..."
  cd "$INSTALL_DIR"
  docker compose up -d
}

show_summary() {
  echo
  log "Итоговые параметры:"
  echo "  install dir:        $INSTALL_DIR"
  echo "  external mode:      $EXTERNAL_MODE"
  echo "  external host:      $EXTERNAL_HOST"
  echo "  postgres db:        $POSTGRES_DB"
  echo "  postgres public:    $DB_PUBLIC_PORT"
  echo "  api/kong public:    $KONG_HTTP_PORT"
  echo "  studio public:      $STUDIO_PORT"
  echo "  service url:        $SERVICE_URL_SUPABASEKONG"
  echo "  signup disabled:    $DISABLE_SIGNUP"
  echo
}

main() {
  require_root
  ensure_requirements
  clear || true
  cat <<'EOF2'
╔══════════════════════════════════════════════╗
║   Supabase lightweight интерактивная установка   ║
╚══════════════════════════════════════════════╝
EOF2
  echo
  echo "1) Внешний доступ:"
  echo "   1 - домен + reverse proxy + HTTPS"
  echo "   2 - прямой доступ по IP:порт"

  local mode
  mode="$(ask "Выберите режим" "2")"
  case "$mode" in
    1)
      EXTERNAL_MODE="domain"
      EXTERNAL_HOST="$(ask "Домен Supabase" "supabase.example.com")"
      SERVICE_URL_SUPABASEKONG="https://$EXTERNAL_HOST"
      SERVICE_URL_SUPABASEKONG_8000="https://$EXTERNAL_HOST"
      API_EXTERNAL_URL="https://$EXTERNAL_HOST"
      ;;
    2)
      EXTERNAL_MODE="ip"
      EXTERNAL_HOST="$(ask "IP или hostname сервера")"
      [[ -n "$EXTERNAL_HOST" ]] || err "IP или hostname не указан"
      ;;
    *) err "Неверный режим. Выбери 1 или 2." ;;
  esac

  INSTALL_DIR="$(ask "Папка установки" "/opt/supabase")"
  POSTGRES_DB="$(ask "PostgreSQL database" "postgres")"
  DB_PUBLIC_PORT="$(ask "Внешний порт PostgreSQL" "6543")"
  KONG_HTTP_PORT="$(ask "Внешний порт API/Kong" "8000")"
  STUDIO_PORT="$(ask "Внешний порт Studio" "3000")"
  JWT_EXPIRY="$(ask "JWT expiry (sec)" "3600")"

  if [[ "$EXTERNAL_MODE" == "ip" ]]; then
    SERVICE_URL_SUPABASEKONG="http://$EXTERNAL_HOST:$KONG_HTTP_PORT"
    SERVICE_URL_SUPABASEKONG_8000="$SERVICE_URL_SUPABASEKONG"
    API_EXTERNAL_URL="$SERVICE_URL_SUPABASEKONG"
  fi

  SERVICE_PASSWORD_POSTGRES="$(ask_secret "PostgreSQL password" "$(random_password)")"
  SERVICE_PASSWORD_JWT="$(ask_secret "JWT secret" "$(random_hex)")"
  SERVICE_USER_ADMIN="$(ask "Dashboard admin user" "admin")"
  SERVICE_PASSWORD_ADMIN="$(ask_secret "Dashboard admin password" "$(random_password)")"

  if ask_yes_no "Разрешить регистрацию новых пользователей?" "Y"; then
    DISABLE_SIGNUP="false"
  else
    DISABLE_SIGNUP="true"
  fi

  ADDITIONAL_REDIRECT_URLS=""
  SERVICE_SUPABASEANON_KEY="$(generate_jwt "$SERVICE_PASSWORD_JWT" "anon")"
  SERVICE_SUPABASESERVICE_KEY="$(generate_jwt "$SERVICE_PASSWORD_JWT" "service_role")"

  show_summary
  ask_yes_no "Сохранить эти настройки в .env и продолжить?" "Y" || err "Отменено"
  write_env
  validate_env
  ok ".env сохранён: $PROJECT_ENV"
  check_required_templates
  ask_yes_no "Начать установку?" "Y" || err "Отменено"
  ensure_docker
  install_files
  start_stack
  echo
  ok "Установка завершена"
  echo "  API:    $SERVICE_URL_SUPABASEKONG"
  echo "  Studio: http://$EXTERNAL_HOST:$STUDIO_PORT"
}

main "$@"
