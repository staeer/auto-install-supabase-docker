#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[i] $*"; }
ok(){ echo "[✔] $*"; }
err(){ echo "[x] $*" >&2; exit 1; }
warn(){ echo "[!] $*"; }

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

ask_yes_no() {
  local prompt="$1" default="${2:-N}" answer shown
  if [[ "$default" == "Y" ]]; then shown='[Y/n]'; else shown='[y/N]'; fi
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

get_env_value() {
  local key="$1" file="$2"
  [[ -f "$file" ]] || return 0
  grep -E "^${key}=" "$file" | head -n1 | cut -d= -f2-
}

[[ "$EUID" -eq 0 ]] || err "Запусти так: sudo bash uninstall.sh"
INSTALL_DIR="${1:-/opt/supabase}"
[[ -n "$INSTALL_DIR" && "$INSTALL_DIR" != "/" ]] || err "Неверный INSTALL_DIR"

ENV_FILE="$INSTALL_DIR/.env"
SUPABASE_DB_IMAGE="$(get_env_value SUPABASE_DB_IMAGE "$ENV_FILE")"
SUPABASE_REST_IMAGE="$(get_env_value SUPABASE_REST_IMAGE "$ENV_FILE")"
SUPABASE_AUTH_IMAGE="$(get_env_value SUPABASE_AUTH_IMAGE "$ENV_FILE")"
SUPABASE_META_IMAGE="$(get_env_value SUPABASE_META_IMAGE "$ENV_FILE")"
SUPABASE_KONG_IMAGE="$(get_env_value SUPABASE_KONG_IMAGE "$ENV_FILE")"
SUPABASE_STUDIO_IMAGE="$(get_env_value SUPABASE_STUDIO_IMAGE "$ENV_FILE")"

echo "ВНИМАНИЕ"
echo "Будет остановлен и удалён стек Supabase."
echo "Директория установки: $INSTALL_DIR"

if ! docker compose version >/dev/null 2>&1; then
  err "docker compose не найден"
fi

ask_yes_no "Продолжить удаление контейнеров и volumes?" "N" || exit 0
if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
  cd "$INSTALL_DIR"
  docker compose down -v --remove-orphans || true
fi

if ask_yes_no "Удалить Docker-образы этого стека?" "N"; then
  docker rmi \
    ${SUPABASE_DB_IMAGE:+"$SUPABASE_DB_IMAGE"} \
    ${SUPABASE_REST_IMAGE:+"$SUPABASE_REST_IMAGE"} \
    ${SUPABASE_AUTH_IMAGE:+"$SUPABASE_AUTH_IMAGE"} \
    ${SUPABASE_META_IMAGE:+"$SUPABASE_META_IMAGE"} \
    ${SUPABASE_KONG_IMAGE:+"$SUPABASE_KONG_IMAGE"} \
    ${SUPABASE_STUDIO_IMAGE:+"$SUPABASE_STUDIO_IMAGE"} \
    >/dev/null 2>&1 || true
  ok "Образы удалены"
fi

if ask_yes_no "Удалить директорию с данными ($INSTALL_DIR)?" "N"; then
  rm -rf "$INSTALL_DIR"
  ok "Директория удалена"
fi

ok "Удаление завершено"
