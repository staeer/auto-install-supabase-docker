#!/usr/bin/env bash
set -euo pipefail

INSTALLER_VERSION="0.1.5"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ENV="$SCRIPT_DIR/.env"
COMPOSE_TEMPLATE="$SCRIPT_DIR/docker-compose.yml.example"
BACKUP_DIR_NAME="backups"

log(){ echo "[i] $*"; }
ok(){ echo "[✔] $*"; }
warn(){ echo "[!] $*"; }
err(){ echo "[x] $*" >&2; exit 1; }

tty_print() { printf '%s' "$1" > /dev/tty; }
tty_println() { printf '%s\n' "$1" > /dev/tty; }

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

require_root() { [[ "$EUID" -eq 0 ]] || err "Запусти так: sudo bash install.sh"; }

ask_into() {
  local __var_name="$1" prompt="$2" default="${3:-}" answer=""
  if [[ -n "$default" ]]; then
    tty_print "$prompt [$default]: "
  else
    tty_print "$prompt: "
  fi
  IFS= read -r answer < /dev/tty || true
  answer="$(trim "$answer")"
  if [[ -z "$answer" ]]; then
    printf -v "$__var_name" '%s' "$default"
  else
    printf -v "$__var_name" '%s' "$answer"
  fi
}

ask_secret_into() {
  local __var_name="$1" prompt="$2" default="${3:-}" answer=""
  if [[ -n "$default" ]]; then
    tty_print "$prompt [$default]: "
  else
    tty_print "$prompt: "
  fi
  IFS= read -r -s answer < /dev/tty || true
  tty_println ""
  answer="$(trim "$answer")"
  if [[ -z "$answer" ]]; then
    printf -v "$__var_name" '%s' "$default"
  else
    printf -v "$__var_name" '%s' "$answer"
  fi
}

ask_yes_no() {
  local prompt="$1" default="${2:-Y}" answer shown
  if [[ "$default" == "Y" ]]; then
    shown='[Y/n]'
  else
    shown='[y/N]'
  fi
  tty_print "$prompt $shown: "
  IFS= read -r answer < /dev/tty || true
  answer="$(trim "$answer")"
  answer="${answer:-$default}"
  case "${answer,,}" in
    y|yes) return 0 ;;
    n|no) return 1 ;;
    *) [[ "$default" == "Y" ]] && return 0 || return 1 ;;
  esac
}

random_hex(){ openssl rand -hex 32 | tr -d '\r\n'; }
random_password(){ openssl rand -hex 16 | tr -d '\r\n'; }

ensure_requirements(){
  [[ -f "$COMPOSE_TEMPLATE" ]] || err "Не найден $COMPOSE_TEMPLATE"
  if ! command -v python3 >/dev/null 2>&1 || ! command -v openssl >/dev/null 2>&1; then
    apt-get update >/dev/null 2>&1
    apt-get install -y python3 openssl >/dev/null 2>&1
  fi
}

ensure_docker(){
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

generate_jwt(){
  local secret="$1" role="$2"
  python3 - "$secret" "$role" <<'PY'
import base64, json, hmac, hashlib, sys, time
secret = sys.argv[1].encode()
role = sys.argv[2]
header = {"alg": "HS256", "typ": "JWT"}
payload = {"role": role, "iss": "supabase", "iat": int(time.time()), "exp": 2524608000}
def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=')
segments = [
    b64url(json.dumps(header, separators=(',', ':')).encode()),
    b64url(json.dumps(payload, separators=(',', ':')).encode())
]
signing_input = b'.'.join(segments)
signature = b64url(hmac.new(secret, signing_input, hashlib.sha256).digest())
print((signing_input + b'.' + signature).decode())
PY
}

validate_env(){
  local bad
  bad="$(grep -nEv '^[A-Z0-9_]+=.*$|^#|^$' "$PROJECT_ENV" || true)"
  if [[ -n "$bad" ]]; then
    echo "$bad"
    err ".env поврежден"
  fi
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
SERVICE_URL_SUPABASEKONG_8000=$SERVICE_URL_SUPABASEKONG
API_EXTERNAL_URL=$SERVICE_URL_SUPABASEKONG
ADDITIONAL_REDIRECT_URLS=
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
EOF_ENV
  chmod 600 "$PROJECT_ENV"
}

prepare_dirs(){
  mkdir -p "$INSTALL_DIR/volumes/db/data" "$INSTALL_DIR/volumes/db/custom" "$INSTALL_DIR/volumes/api" "$INSTALL_DIR/$BACKUP_DIR_NAME"
  chown -R 999:999 "$INSTALL_DIR/volumes/db/data"
  chmod -R 755 "$INSTALL_DIR/volumes/db/data" "$INSTALL_DIR/volumes/db/custom" "$INSTALL_DIR/volumes/api"
}

copy_project_files(){
  cp "$COMPOSE_TEMPLATE" "$INSTALL_DIR/docker-compose.yml"
  cp "$PROJECT_ENV" "$INSTALL_DIR/.env"
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

start_stack(){ cd "$INSTALL_DIR"; docker compose pull; docker compose up -d; }

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
╔══════════════════════════════════════════════╗
║   Supabase lightweight интерактивная установка   ║
╚══════════════════════════════════════════════╝
BANNER
  echo
  echo "1) Внешний доступ:"
  echo "   1 - домен + reverse proxy + HTTPS"
  echo "   2 - прямой доступ по IP:порт"

  ask_into ACCESS_MODE "Выберите режим" "2"
  case "$ACCESS_MODE" in
    1)
      EXTERNAL_MODE="domain"
      ask_into EXTERNAL_HOST "Домен" "supabase.example.com"
      SCHEME="https"
      ;;
    2)
      EXTERNAL_MODE="ip"
      ask_into EXTERNAL_HOST "IP или hostname сервера" ""
      [[ -n "$EXTERNAL_HOST" ]] || err "IP или hostname сервера не указан"
      SCHEME="http"
      ;;
    *) err "Неверный режим" ;;
  esac

  ask_into INSTALL_DIR "Папка установки" "/opt/supabase"
  ask_into POSTGRES_DB "PostgreSQL database" "postgres"
  ask_into DB_PUBLIC_PORT "Внешний порт PostgreSQL" "6543"
  ask_into KONG_HTTP_PORT "Внешний порт API/Kong" "8000"
  ask_into STUDIO_PORT "Внешний порт Studio" "3000"
  ask_into JWT_EXPIRY "JWT expiry (sec)" "3600"
  ask_secret_into SERVICE_PASSWORD_POSTGRES "PostgreSQL password" "$(random_password)"
  ask_secret_into SERVICE_PASSWORD_JWT "JWT secret" "$(random_hex)"
  ask_into SERVICE_USER_ADMIN "Dashboard admin user" "admin"
  ask_secret_into SERVICE_PASSWORD_ADMIN "Dashboard admin password" "$(random_password)"
  if ask_yes_no "Разрешить регистрацию новых пользователей?" "Y"; then
    DISABLE_SIGNUP="false"
  else
    DISABLE_SIGNUP="true"
  fi

  SERVICE_URL_SUPABASEKONG="$SCHEME://$EXTERNAL_HOST:$KONG_HTTP_PORT"
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

  ask_yes_no "Начать установку?" "Y" || err "Отменено"
  verify_required_templates
  ensure_docker
  prepare_dirs
  copy_project_files
  cd "$INSTALL_DIR"
  validate_env
  start_stack
  show_final
}

main "$@"
