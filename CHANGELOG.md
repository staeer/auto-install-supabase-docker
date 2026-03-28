## 0.2.5

- Добавлен `restart: unless-stopped` для всех сервисов, чтобы стек поднимался после перезагрузки сервера.
- Сохранены предыдущие фиксы Kong (`/docker-entrypoint.sh`), `install.sh` и `uninstall.sh`.

## 0.2.4

- Исправлен install.sh
- Исправлен uninstall.sh
- Исправлен docker-compose.yml.example
- Kong запускается через /docker-entrypoint.sh
- Studio не публикуется наружу
- Убран source .env из uninstall.sh
