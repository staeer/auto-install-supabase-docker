#!/usr/bin/env bash
set -euo pipefail

INSTALLER_VERSION="0.2.3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ENV="$SCRIPT_DIR/.env"
COMPOSE_TEMPLATE="$SCRIPT_DIR/docker-compose.yml.example"
INSTALL_DIR_DEFAULT="/opt/supabase"

log(){ echo "[i] $*"; }
ok(){ echo "[✔] $*"; }
warn(){ echo "[!] $*"; }
err(){ echo "[x] $*" >&2; exit 1; }

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

require_root() {
  [[ "$EUID" -eq 0 ]] || err "Запусти так: sudo bash install.sh"
}

ask_into() {
  local __var_name="$1" prompt="$2" default="${3-}" answer
  if [[ -n "$default" ]]; then
    printf '%s [%s]: ' "$prompt" "$default" > /dev/tty
  else
    printf '%s: ' "$prompt" > /dev/tty
  fi
  IFS= read -r answer < /dev/tty || true
  answer="$(trim "$answer")"
  if [[ -z "$answer" ]]; then
    printf -v "$__var_name" '%s' "$default"
  else
    printf -v "$__var_name" '%s' "$answer"
  fi
}

ask_required_into() {
  local __var_name="$1" prompt="$2" answer
  while true; do
    printf '%s: ' "$prompt" > /dev/tty
    IFS= read -r answer < /dev/tty || true
    answer="$(trim "$answer")"
    if [[ -n "$answer" ]]; then
      printf -v "$__var_name" '%s' "$answer"
      return 0
    fi
    warn "Поле не должно быть пустым"
  done
}

ask_secret_into() {
  local __var_name="$1" prompt="$2" default="${3-}" answer
  if [[ -n "$default" ]]; then
    printf '%s [%s]: ' "$prompt" "$default" > /dev/tty
  else
    printf '%s: ' "$prompt" > /dev/tty
  fi
  IFS= read -r -s answer < /dev/tty || true
  printf '\n' > /dev/tty
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
  printf '%s %s: ' "$prompt" "$shown" > /dev/tty
  IFS= read -r answer < /dev/tty || true
  answer="$(trim "$answer")"
  answer="${answer:-$default}"
  case "${answer,,}" in
    y|yes) return 0 ;;
    n|no) return 1 ;;
    *) [[ "$default" == "Y" ]] ;;
  esac
}

random_hex16() { openssl rand -hex 16 | tr -d '\r\n'; }
random_hex32() { openssl rand -hex 32 | tr -d '\r\n'; }

ensure_requirements() {
  [[ -f "$COMPOSE_TEMPLATE" ]] || err "Не найден $COMPOSE_TEMPLATE"
  command -v openssl >/dev/null 2>&1 || { apt-get update >/dev/null 2>&1; apt-get install -y openssl >/dev/null 2>&1; }
  command -v python3 >/dev/null 2>&1 || { apt-get update >/dev/null 2>&1; apt-get install -y python3 >/dev/null 2>&1; }
}

ensure_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    ok "Docker уже установлен"
    return 0
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

segments = [
    b64url(json.dumps(header, separators=(',', ':')).encode()),
    b64url(json.dumps(payload, separators=(',', ':')).encode()),
]
signing_input = b'.'.join(segments)
signature = b64url(hmac.new(secret, signing_input, hashlib.sha256).digest())
print((signing_input + b'.' + signature).decode())
PY
}

validate_env() {
  local bad
  bad="$(grep -nEv '^[A-Z0-9_]+=.*$|^#|^$' "$PROJECT_ENV" || true)"
  if [[ -n "$bad" ]]; then
    echo "$bad"
    err ".env поврежден"
  fi
}

write_env() {
  cat > "$PROJECT_ENV" <<EOFENV
STACK_VERSION=$INSTALLER_VERSION
INSTALL_DIR=$INSTALL_DIR
SUPABASE_DB_IMAGE=supabase/postgres:15.8.1.048
SUPABASE_REST_IMAGE=postgrest/postgrest:v12.2.12
SUPABASE_AUTH_IMAGE=supabase/gotrue:v2.174.0
SUPABASE_META_IMAGE=supabase/postgres-meta:v0.89.3
SUPABASE_KONG_IMAGE=kong:2.8.1
SUPABASE_STUDIO_IMAGE=supabase/studio:2026.01.07-sha-037e5f9
STUDIO_CLI_VERSION=2.67.1
POSTGRES_HOSTNAME=db
POSTGRES_HOST=db
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
STUDIO_DEFAULT_ORGANIZATION="Default Organization"
STUDIO_DEFAULT_PROJECT="Default Project"
OPENAI_API_KEY=
PGRST_DB_SCHEMAS=public,storage,graphql_public
EOFENV
  chmod 600 "$PROJECT_ENV"
}

check_required_assets() {
  local missing=0
  local files=(
    "$SCRIPT_DIR/volumes/db/realtime.sql"
    "$SCRIPT_DIR/volumes/db/_supabase.sql"
    "$SCRIPT_DIR/volumes/db/pooler.sql"
    "$SCRIPT_DIR/volumes/db/webhooks.sql"
    "$SCRIPT_DIR/volumes/db/roles.sql"
    "$SCRIPT_DIR/volumes/db/jwt.sql"
    "$SCRIPT_DIR/volumes/db/logs.sql"
    "$SCRIPT_DIR/volumes/api/kong.yml"
    "$SCRIPT_DIR/volumes/api/kong-entrypoint.sh"
  )
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || { warn "Не найден файл: $f"; missing=1; }
  done
  [[ $missing -eq 0 ]] || err "Не хватает обязательных файлов в volumes/"
}

install_files() {
  mkdir -p "$INSTALL_DIR/volumes/db" "$INSTALL_DIR/volumes/api" "$INSTALL_DIR/volumes/logs" "$INSTALL_DIR/volumes/pooler" "$INSTALL_DIR/volumes/snippets"
  cp "$PROJECT_ENV" "$INSTALL_DIR/.env"
  cp "$COMPOSE_TEMPLATE" "$INSTALL_DIR/docker-compose.yml"
  cp "$SCRIPT_DIR/volumes/db/"*.sql "$INSTALL_DIR/volumes/db/"
  cp "$SCRIPT_DIR/volumes/api/kong.yml" "$INSTALL_DIR/volumes/api/kong.yml"
  cp "$SCRIPT_DIR/volumes/api/kong-entrypoint.sh" "$INSTALL_DIR/volumes/api/kong-entrypoint.sh"
  [[ -f "$SCRIPT_DIR/volumes/logs/vector.yml" ]] && cp "$SCRIPT_DIR/volumes/logs/vector.yml" "$INSTALL_DIR/volumes/logs/vector.yml"
  [[ -f "$SCRIPT_DIR/volumes/pooler/pooler.exs" ]] && cp "$SCRIPT_DIR/volumes/pooler/pooler.exs" "$INSTALL_DIR/volumes/pooler/pooler.exs"
  chmod 600 "$INSTALL_DIR/.env"
  chmod +x "$INSTALL_DIR/volumes/api/kong-entrypoint.sh"
}

show_summary() {
  echo
  log "Итоговые параметры:"
  echo "  режим:                $EXTERNAL_MODE"
  echo "  host:                 $EXTERNAL_HOST"
  echo "  install dir:          $INSTALL_DIR"
  echo "  postgres db:          $POSTGRES_DB"
  echo "  postgres port:        $DB_PUBLIC_PORT"
  echo "  api/kong port:        $KONG_HTTP_PORT"
  echo "  studio local port:    127.0.0.1:$STUDIO_PORT"
  echo "  signup allowed:       $([[ "$DISABLE_SIGNUP" == "true" ]] && echo no || echo yes)"
  echo "  public url:           $SERVICE_URL_SUPABASEKONG"
  echo
}

start_stack() {
  cd "$INSTALL_DIR"
  docker compose pull
  docker compose up -d
}

main() {
  require_root
  ensure_requirements

  clear || true
  cat <<'EOFBANNER'
╔══════════════════════════════════════════════╗
║   Supabase lightweight интерактивная установка   ║
╚══════════════════════════════════════════════╝
EOFBANNER
  echo
  echo "1) Внешний доступ:"
  echo "   1 - домен + reverse proxy + HTTPS"
  echo "   2 - прямой доступ по IP:порт"

  ask_into MODE "Выберите режим" "2"
  case "$MODE" in
    1)
      EXTERNAL_MODE="domain"
      ask_required_into EXTERNAL_HOST "Домен Supabase"
      ;;
    2)
      EXTERNAL_MODE="ip"
      ask_required_into EXTERNAL_HOST "IP или hostname сервера"
      ;;
    *) err "Неверный режим. Выбери 1 или 2." ;;
  esac

  ask_into INSTALL_DIR "Папка установки" "$INSTALL_DIR_DEFAULT"
  ask_into POSTGRES_DB "PostgreSQL database" "postgres"
  ask_into DB_PUBLIC_PORT "Внешний порт Postgres" "6543"
  ask_into KONG_HTTP_PORT "Внешний порт API/Kong" "8000"
  ask_into STUDIO_PORT "Локальный порт Studio (только localhost)" "3000"
  ask_into JWT_EXPIRY "JWT expiry (sec)" "3600"
  ask_secret_into SERVICE_PASSWORD_POSTGRES "PostgreSQL password" "$(random_hex16)"
  ask_secret_into SERVICE_PASSWORD_JWT "JWT secret" "$(random_hex32)"
  ask_into SERVICE_USER_ADMIN "Dashboard admin user" "admin"
  ask_secret_into SERVICE_PASSWORD_ADMIN "Dashboard admin password" "$(random_hex16)"

  if ask_yes_no "Разрешить регистрацию новых пользователей?" "Y"; then
    DISABLE_SIGNUP="false"
  else
    DISABLE_SIGNUP="true"
  fi

  if [[ "$EXTERNAL_MODE" == "domain" ]]; then
    SERVICE_URL_SUPABASEKONG="https://$EXTERNAL_HOST"
  else
    SERVICE_URL_SUPABASEKONG="http://$EXTERNAL_HOST:$KONG_HTTP_PORT"
  fi

  SERVICE_SUPABASEANON_KEY="$(generate_jwt "$SERVICE_PASSWORD_JWT" anon | tr -d '\r\n')"
  SERVICE_SUPABASESERVICE_KEY="$(generate_jwt "$SERVICE_PASSWORD_JWT" service_role | tr -d '\r\n')"

  show_summary
  ask_yes_no "Сохранить эти настройки в .env и продолжить?" "Y" || err "Отменено"

  write_env
  validate_env
  ok ".env сохранён: $PROJECT_ENV"

  ask_yes_no "Начать установку?" "Y" || err "Отменено"
  check_required_assets
  ensure_docker
  install_files
  start_stack

  ok "Установка завершена"
  echo "Публичный URL: $SERVICE_URL_SUPABASEKONG"
  echo "Studio локально на сервере: http://127.0.0.1:$STUDIO_PORT"
  echo "Проверка контейнеров: cd $INSTALL_DIR && sudo docker compose ps"
}

main "$@"
