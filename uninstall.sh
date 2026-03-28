#!/usr/bin/env bash
set -euo pipefail

log()  { echo "[i] $*"; }
ok()   { echo "[✔] $*"; }
err()  { echo "[x] $*" >&2; exit 1; }
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}
ask_yes_no() {
  local prompt="$1" default="${2:-N}" answer shown
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
[[ "$EUID" -eq 0 ]] || err "Запусти так: sudo bash uninstall.sh"
INSTALL_DIR="${1:-/opt/supabase}"
[[ -n "$INSTALL_DIR" && "$INSTALL_DIR" != "/" ]] || err "Опасный INSTALL_DIR"
echo "ВНИМАНИЕ"
echo "Будет остановлен и удалён стек Supabase."
echo "Директория установки: $INSTALL_DIR"
ask_yes_no "Продолжить удаление контейнеров и volumes?" "N" || exit 0
if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then cd "$INSTALL_DIR" && docker compose down -v --remove-orphans || true; fi
if ask_yes_no "Удалить директорию с данными ($INSTALL_DIR)?" "N"; then rm -rf "$INSTALL_DIR"; ok "Директория удалена"; fi
ok "Удаление завершено"
