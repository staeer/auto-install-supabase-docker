#!/usr/bin/env bash
set -euo pipefail

INSTALLER_VERSION="0.1.2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ENV="$SCRIPT_DIR/.env"
COMPOSE_TEMPLATE="$SCRIPT_DIR/docker-compose.yml.example"
BACKUP_DIR_NAME="backups"

log(){ echo "[i] $*"; }
ok(){ echo "[✔] $*"; }
warn(){ echo "[!] $*"; }
err(){ echo "[x] $*" >&2; exit 1; }

trim(){ local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }
require_root(){ [[ "$EUID" -eq 0 ]] || err "Запусти так: sudo bash install.sh"; }

ask(){
  local p="$1" d="${2:-}" a
  if [[ -n "$d" ]]; then
    read -r -p "$p [$d]: " a || true
    a="$(trim "$a")"
    printf '%s' "${a:-$d}"
  else
    read -r -p "$p: " a || true
    printf '%s' "$(trim "$a")"
  fi
}

ask_required(){
  local p="$1" a
  while true; do
    read -r -p "$p: " a || true
    a="$(trim "$a")"
    [[ -n "$a" ]] && { printf '%s' "$a"; return; }
    warn "Поле не должно быть пустым"
  done
}

ask_secret() {
  local prompt="$1" default="${2:-}" answer
  if [[ -n "$default" ]]; then
    read -r -s -p "$prompt [$default]: " answer || true
  else
    read -r -s -p "$prompt: " answer || true
  fi
  echo >&2
  answer="$(trim "$answer")"
  if [[ -z "$answer" ]]; then
    printf '%s' "$default"
  else
    printf '%s' "$answer"
  fi
}

ask_yes_no(){
  local p="$1" d="${2:-Y}" a shown
  [[ "$d" == "Y" ]] && shown='[Y/n]' || shown='[y/N]'
  read -r -p "$p $shown: " a || true
  a="$(trim "$a")"
  a="${a:-$d}"
  case "${a,,}" in
    y|yes) return 0 ;;
    n|no) return 1 ;;
    *) [[ "$d" == "Y" ]] ;;
  esac
}

random_hex(){ openssl rand -hex 32; }
random_password(){ openssl rand -hex 16; }

ensure_requirements(){
  [[ -f "$COMPOSE_TEMPLATE" ]] || err "Не найден $COMPOSE_TEMPLATE"
  if ! command -v python3 >/dev/null 2>&1; then
    apt-get update
    apt-get install -y python3 >/dev/null 2>&1
  fi
  if ! command -v openssl >/dev/null 2>&1; then
    apt-get update
    apt-get install -y openssl >/dev/null 2>&1
  fi
}

ensure_docker(){
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    ok "Docker уже установлен"
    return
  fi
  log "Установка Docker..."
  apt-get update
  apt-get install -y ca-certificates curl gnupg >/dev/null 2>&1
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
  ok "Docker установлен"
}

generate_jwt(){
  local secret="$1" role="$2"
  python3 - "$secret" "$role" <<'PY'
import base64, json, hmac, hashlib, sys, time
secret = sys.argv[1].encode()
role = sys.argv[2]
header = {"alg":"HS256","typ":"JWT"}
payload = {"role": role, "iss": "supabase", "iat": int(time.time()), "exp": 2524608000}
def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=')
segments = [b64url(json.dumps(header,separators=(',',':')).encode()), b64url(json.dumps(payload,separators=(',',':')).encode())]
signing_input = b'.'.join(segments)
signature = b64url(hmac.new(secret, signing_input, hashlib.sha256).digest())
print((signing_input + b'.' + signature).decode())
PY
}

write_env(){
cat > "$PROJECT_ENV" <<EOF_ENV
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
ENABLE_EMAIL_SIGNUP=$ENABLE_EMAIL_SIGNUP
ENABLE_ANONYMOUS_USERS=$ENABLE_ANONYMOUS_USERS
ENABLE_EMAIL_AUTOCONFIRM=$ENABLE_EMAIL_AUTOCONFIRM
ENABLE_PHONE_SIGNUP=$ENABLE_PHONE_SIGNUP
ENABLE_PHONE_AUTOCONFIRM=$ENABLE_PHONE_AUTOCONFIRM
SMTP_ADMIN_EMAIL=$SMTP_ADMIN_EMAIL
SMTP_HOST=$SMTP_HOST
SMTP_PORT=$SMTP_PORT
SMTP_USER=$SMTP_USER
SMTP_PASS=$SMTP_PASS
SMTP_SENDER_NAME=$SMTP_SENDER_NAME
MAILER_URLPATHS_INVITE=/auth/v1/verify
MAILER_URLPATHS_CONFIRMATION=/auth/v1/verify
MAILER_URLPATHS_RECOVERY=/auth/v1/verify
MAILER_URLPATHS_EMAIL_CHANGE=/auth/v1/verify
STUDIO_DEFAULT_ORGANIZATION=$STUDIO_DEFAULT_ORGANIZATION
STUDIO_DEFAULT_PROJECT=$STUDIO_DEFAULT_PROJECT
OPENAI_API_KEY=$OPENAI_API_KEY
PGRST_DB_SCHEMAS=public,storage,graphql_public
EOF_ENV
chmod 600 "$PROJECT_ENV"
}

validate_env(){
  local bad
  bad="$(grep -nEv '^[A-Z0-9_]+=.*$|^#|^$' "$PROJECT_ENV" || true)"
  [[ -z "$bad" ]] || { echo "$bad"; err ".env поврежден"; }
}

prepare_dirs(){
  mkdir -p "$INSTALL_DIR/volumes/db/data" "$INSTALL_DIR/volumes/db/custom" "$INSTALL_DIR/volumes/api" "$INSTALL_DIR/$BACKUP_DIR_NAME"
  chown -R 999:999 "$INSTALL_DIR/volumes/db/data"
  chmod -R 755 "$INSTALL_DIR/volumes/db/data" "$INSTALL_DIR/volumes/db/custom" "$INSTALL_DIR/volumes/api"
}

copy_project_files(){
  cp "$COMPOSE_TEMPLATE" "$INSTALL_DIR/docker-compose.yml"
  cp "$PROJECT_ENV" "$INSTALL_DIR/.env"
  chmod 600 "$INSTALL_DIR/.env"
  for f in realtime.sql _supabase.sql pooler.sql webhooks.sql roles.sql jwt.sql logs.sql; do
    [[ -f "$SCRIPT_DIR/volumes/db/$f" ]] || err "Не найден $SCRIPT_DIR/volumes/db/$f"
    cp "$SCRIPT_DIR/volumes/db/$f" "$INSTALL_DIR/volumes/db/$f"
  done
  [[ -f "$SCRIPT_DIR/volumes/api/kong.yml" ]] || err "Не найден $SCRIPT_DIR/volumes/api/kong.yml"
  cp "$SCRIPT_DIR/volumes/api/kong.yml" "$INSTALL_DIR/volumes/api/kong.yml"
}

verify_required_templates(){
  local placeholders=0
  for f in "$SCRIPT_DIR"/volumes/db/*.sql "$SCRIPT_DIR"/volumes/api/kong.yml; do
    if grep -q 'PLACEHOLDER_REPLACE_ME' "$f"; then
      warn "Заглушка не заменена: $f"
      placeholders=1
    fi
  done
  [[ "$placeholders" -eq 0 ]] || err "Замени заглушки на свои проверенные SQL/Kong файлы и запусти снова"
}

start_stack(){
  cd "$INSTALL_DIR"
  docker compose pull
  docker compose up -d
}

show_final(){
  echo
  ok "Установка завершена"
  echo "  API/Kong:   $SERVICE_URL_SUPABASEKONG"
  echo "  Studio:     http://$EXTERNAL_HOST:$STUDIO_PORT"
  echo "  Postgres:   $EXTERNAL_HOST:$DB_PUBLIC_PORT"
  echo
}

main(){
  require_root
  ensure_requirements
  clear || true
  cat <<'BANNER'
╔══════════════════════════════════════════════════╗
║   Supabase lightweight интерактивная установка  ║
╚══════════════════════════════════════════════════╝
BANNER
  echo
  echo "1) Внешний доступ:"
  echo "   1 - домен + reverse proxy + HTTPS"
  echo "   2 - прямой доступ по IP:порт"
  ACCESS_MODE="$(ask "Выберите режим" "2")"
  case "$ACCESS_MODE" in
    1)
      EXTERNAL_MODE="domain"
      EXTERNAL_HOST="$(ask "Домен" "supabase.example.com")"
      SCHEME="https"
      ;;
    2)
      EXTERNAL_MODE="ip"
      EXTERNAL_HOST="$(ask_required "IP или hostname сервера")"
      SCHEME="http"
      ;;
    *) err "Неверный режим" ;;
  esac

  INSTALL_DIR="$(ask "Папка установки" "/opt/supabase")"
  POSTGRES_DB="$(ask "PostgreSQL database" "postgres")"
  DB_PUBLIC_PORT="$(ask "Внешний порт PostgreSQL" "6543")"
  KONG_HTTP_PORT="$(ask "Внешний порт API/Kong" "8000")"
  STUDIO_PORT="$(ask "Внешний порт Studio" "3000")"
  JWT_EXPIRY="$(ask "JWT expiry (sec)" "3600")"
  SERVICE_PASSWORD_POSTGRES="$(ask_secret "PostgreSQL password" "$(random_password)")"
  SERVICE_PASSWORD_JWT="$(ask_secret "JWT secret" "$(random_hex)")"
  SERVICE_USER_ADMIN="$(ask "Dashboard admin user" "admin")"
  SERVICE_PASSWORD_ADMIN="$(ask_secret "Dashboard admin password" "$(random_password)")"
  if ask_yes_no "Разрешить регистрацию новых пользователей?" "Y"; then
    DISABLE_SIGNUP="false"
  else
    DISABLE_SIGNUP="true"
  fi
  ENABLE_EMAIL_SIGNUP="true"
  ENABLE_ANONYMOUS_USERS="false"
  ENABLE_EMAIL_AUTOCONFIRM="false"
  ENABLE_PHONE_SIGNUP="true"
  ENABLE_PHONE_AUTOCONFIRM="true"
  SMTP_ADMIN_EMAIL="$(ask "SMTP admin email" "")"
  SMTP_HOST="$(ask "SMTP host" "")"
  SMTP_PORT="$(ask "SMTP port" "587")"
  SMTP_USER="$(ask "SMTP user" "")"
  SMTP_PASS="$(ask_secret "SMTP pass" "")"
  SMTP_SENDER_NAME="$(ask "SMTP sender name" "")"
  STUDIO_DEFAULT_ORGANIZATION="$(ask "Studio organization" "Default Organization")"
  STUDIO_DEFAULT_PROJECT="$(ask "Studio project" "Default Project")"
  OPENAI_API_KEY="$(ask_secret "OpenAI API key" "")"

  SERVICE_URL_SUPABASEKONG="$SCHEME://$EXTERNAL_HOST:$KONG_HTTP_PORT"
  SERVICE_URL_SUPABASEKONG_8000="$SERVICE_URL_SUPABASEKONG"
  API_EXTERNAL_URL="$SERVICE_URL_SUPABASEKONG"
  ADDITIONAL_REDIRECT_URLS=""
  SERVICE_SUPABASEANON_KEY="$(generate_jwt "$SERVICE_PASSWORD_JWT" anon)"
  SERVICE_SUPABASESERVICE_KEY="$(generate_jwt "$SERVICE_PASSWORD_JWT" service_role)"

  echo
  log "Итоговые параметры:"
  echo "  install dir:      $INSTALL_DIR"
  echo "  external mode:    $EXTERNAL_MODE"
  echo "  external host:    $EXTERNAL_HOST"
  echo "  postgres db:      $POSTGRES_DB"
  echo "  postgres public:  $DB_PUBLIC_PORT"
  echo "  api/kong public:  $KONG_HTTP_PORT"
  echo "  studio public:    $STUDIO_PORT"
  echo "  service url:      $SERVICE_URL_SUPABASEKONG"
  echo "  signup disabled:  $DISABLE_SIGNUP"
  echo

  ask_yes_no "Сохранить эти настройки в .env и продолжить?" "Y" || err "Отменено"
  write_env
  validate_env
  ok ".env сохранён: $PROJECT_ENV"
  verify_required_templates
  ensure_docker
  prepare_dirs
  copy_project_files
  start_stack
  show_final
}

main "$@"
