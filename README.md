# auto-install-supabase-docker

Интерактивный установщик облегчённого self-hosted Supabase через Docker Compose.

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

## Что входит

- PostgreSQL
- PostgREST
- GoTrue
- Postgres Meta
- Kong
- Supabase Studio

## Важно

Установщик ожидает, что в репозитории уже лежат реальные файлы:

- `volumes/db/*.sql`
- `volumes/api/kong.yml`

Если любого из этих файлов нет, установка остановится с ошибкой.
