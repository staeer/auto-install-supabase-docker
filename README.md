# auto-install-supabase-docker

Интерактивный установщик облегчённого self-hosted Supabase через Docker Compose.

Что ставится:
- PostgreSQL (`supabase/postgres`)
- PostgREST
- GoTrue (Auth)
- Postgres Meta
- Kong
- Studio

Что важно:
- наружу публикуются только `Postgres` и `Kong/API`
- `Studio` публикуется только на `127.0.0.1`, а не наружу
- для `Kong` используются реальные `volumes/api/kong.yml` и `volumes/api/kong-entrypoint.sh`

## Установка

```bash
rm -rf ~/auto-install-supabase-docker
git clone https://github.com/staeer/auto-install-supabase-docker.git
cd auto-install-supabase-docker
sudo bash install.sh
```

Установщик по шагам спросит:
- режим доступа: домен или IP
- путь установки
- имя базы
- внешний порт Postgres
- внешний порт Kong/API
- локальный порт Studio
- JWT expiry
- пароль Postgres
- JWT secret
- логин и пароль Dashboard Basic Auth
- разрешить ли регистрацию новых пользователей

После установки открывай:
- публично: `http://IP_ИЛИ_ДОМЕН:8000`
- локально на сервере: `http://127.0.0.1:3000`

## Удаление

```bash

sudo bash uninstall.sh
```

Или для другого пути:

```bash

sudo bash uninstall.sh /opt/supabase
```

## Файлы, которые должны быть в репозитории

```text
volumes/api/kong.yml
volumes/api/kong-entrypoint.sh
volumes/db/_supabase.sql
volumes/db/jwt.sql
volumes/db/logs.sql
volumes/db/pooler.sql
volumes/db/realtime.sql
volumes/db/roles.sql
volumes/db/webhooks.sql
```

Если какого-то из этих файлов нет, установщик остановится с ошибкой.

## Полезные команды

Проверка контейнеров:

```bash
cd /opt/supabase
sudo docker compose ps
```

Логи Kong:

```bash
cd /opt/supabase
sudo docker compose logs -f supabase-kong
```

Логи Meta:

```bash
cd /opt/supabase
sudo docker compose logs -f supabase-meta
```


## Важно

- Внешний доступ идёт через Kong на порту `8000`.
- Studio публикуется только локально на `127.0.0.1:3000`.
