#!/usr/bin/env bash
set -euo pipefail

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

[[ "$EUID" -eq 0 ]] || err "Запусти так: sudo bash uninstall.sh"
INSTALL_DIR="${1:-/opt/supabase}"
[[ "$INSTALL_DIR" != "/" ]] || err "Нельзя удалять /"

if [[ -f "$INSTALL_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$INSTALL_DIR/.env"
  set +a
fi

echo "ВНИМАНИЕ"
echo "Будет остановлен и удалён стек Supabase."
echo "Директория установки: $INSTALL_DIR"

docker compose version >/dev/null 2>&1 || err "docker compose не найден"

ask_yes_no "Продолжить удаление контейнеров и volumes?" "N" || exit 0
if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
  cd "$INSTALL_DIR"
  docker compose down -v --remove-orphans || true
fi

if ask_yes_no "Удалить директорию с данными ($INSTALL_DIR)?" "N"; then
  rm -rf "$INSTALL_DIR"
  ok "Директория удалена"
fi

ok "Удаление завершено"
