# auto-install-supabase-docker

Интерактивный установщик облегчённого self-hosted Supabase на Docker Compose.

## Что внутри

- PostgreSQL
- PostgREST
- GoTrue (Auth)
- Postgres Meta
- Kong
- Studio

## Важно

В репо лежат **заглушки** для:

- `volumes/db/*.sql`
- `volumes/api/kong.yml`

Перед установкой замени их своими **проверенными** файлами. Иначе `install.sh` остановится с ошибкой.

## Установка

```bash
git clone https://github.com/staeer/auto-install-supabase-docker.git
cd auto-install-supabase-docker
sudo bash install.sh
```

## Удаление

```bash
sudo bash uninstall.sh
```

или

```bash
sudo bash uninstall.sh /opt/supabase
```
