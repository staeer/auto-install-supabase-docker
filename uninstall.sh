#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${1:-/opt/supabase}"

[[ "$EUID" -eq 0 ]] || { echo "Запусти через sudo"; exit 1; }
[[ -d "$INSTALL_DIR" ]] || { echo "Нет директории: $INSTALL_DIR"; exit 1; }
[[ -f "$INSTALL_DIR/docker-compose.yml" ]] || { echo "Нет docker-compose.yml в $INSTALL_DIR"; exit 1; }

cd "$INSTALL_DIR"

read -rp "Удалить Docker-образы этого стека? [y/N]: " REMOVE_IMAGES

if [[ "$REMOVE_IMAGES" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  docker compose down -v --remove-orphans --rmi all
else
  docker compose down -v --remove-orphans
fi

read -rp "Удалить директорию $INSTALL_DIR ? [y/N]: " REMOVE_DIR
if [[ "$REMOVE_DIR" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  cd /
  rm -rf "$INSTALL_DIR"
fi

echo "Готово"