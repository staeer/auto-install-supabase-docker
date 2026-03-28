#!/usr/bin/env bash
set -euo pipefail
log(){ echo "[i] $*"; }
ok(){ echo "[✔] $*"; }
err(){ echo "[x] $*" >&2; exit 1; }
trim(){ local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }
ask_yes_no(){ local p="$1" d="${2:-N}" a shown; [[ "$d" == "Y" ]] && shown='[Y/n]' || shown='[y/N]'; read -r -p "$p $shown: " a || true; a="$(trim "$a")"; a="${a:-$d}"; case "${a,,}" in y|yes) return 0;; *) return 1;; esac; }
[[ "$EUID" -eq 0 ]] || err "Запусти так: sudo bash uninstall.sh"
INSTALL_DIR="${1:-/opt/supabase}"
[[ -f "$INSTALL_DIR/.env" ]] && set -a && source "$INSTALL_DIR/.env" && set +a || true
[[ "$INSTALL_DIR" != "/" ]] || err "Нельзя удалять /"
echo "ВНИМАНИЕ"
echo "Будет удалён стек Supabase: $INSTALL_DIR"
ask_yes_no "Продолжить удаление контейнеров и volumes?" "N" || exit 0
cd "$INSTALL_DIR" 2>/dev/null || err "Не найдена директория $INSTALL_DIR"
docker compose down -v --remove-orphans || true
if ask_yes_no "Удалить директорию с данными ($INSTALL_DIR)?" "N"; then rm -rf "$INSTALL_DIR"; ok "Директория удалена"; fi
ok "Удаление завершено"
