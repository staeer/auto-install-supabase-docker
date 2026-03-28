## 0.2.3

### Fixed
- Исправлен `volumes/api/kong-entrypoint.sh`: запуск Kong теперь идёт через `/docker-entrypoint.sh`, из-за чего контейнер больше не падает с `Exited (127)`.
- Обновлён `docker-compose.yml.example` под рабочий `kong-entrypoint.sh`.
- Сохранены правки интерактивного установщика и безопасного `uninstall.sh`.

## 0.2.2

### Fixed
- Removed blocking healthcheck from supabase-meta.
- Changed dependencies on supabase-meta from service_healthy to service_started.

## 0.2.1

- Исправлен healthcheck у supabase-meta: валидный синтаксис compose и проверка корня на 8080.
- uninstall.sh больше не падает на значениях с пробелами в .env и корректно работает без source.
- README уточнён: внешний доступ только через Kong (:8000), Studio публикуется только локально.

## 0.2.0

### Fixed
- Полностью переписан `README.md`.
- Починен `uninstall.sh`: больше не делает `source .env`, поэтому не падает на значениях с пробелами.
- Починен `install.sh`: улучшен интерактивный ввод, копирование всех обязательных файлов и финальные подсказки.
- Убран внешний доступ к `Studio`: теперь порт публикуется только на `127.0.0.1`.
- `Kong` теперь стартует через `volumes/api/kong-entrypoint.sh`, а не через битый `eval` в compose.
- Добавлены обязательные проверки на наличие `kong-entrypoint.sh` и SQL-файлов.
- Исправлена связка имён сервисов с `kong.yml` через network aliases.
- Добавлен корректный healthcheck для `supabase-meta`.
