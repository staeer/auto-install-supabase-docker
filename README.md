# auto-install-supabase-docker для Ubuntu

Интерактивный установщик упрощённого self-hosted Supabase через Docker Compose для Ubuntu. 

## Релиз v0.2.5

Что входит в стек:

- PostgreSQL
- PostgREST
- GoTrue (Auth)
- Postgres Meta
- Kong
- Studio

Что изменено в релизе:

- added `restart: unless-stopped` for all services
- kept fixes for `install.sh`, `uninstall.sh` and `docker-compose.yml.example`
- Kong starts through `volumes/api/kong-entrypoint.sh`
- Studio stays local-only on server
- updated README.md

## Установка

```bash
rm -rf ~/auto-install-supabase-docker
git clone https://github.com/staeer/auto-install-supabase-docker.git
cd auto-install-supabase-docker
sudo bash install.sh
```

## Что спросит установщик

Установщик спросит:

- режим доступа:
  - `1` — домен + reverse proxy + HTTPS
  - `2` — прямой доступ по IP:порт
- домен Supabase или IP/hostname сервера
- директорию установки
- имя базы PostgreSQL
- внешний порт PostgreSQL
- внешний порт API / Kong
- JWT expiry
- пароль PostgreSQL
- JWT secret
- логин dashboard admin
- пароль dashboard admin
- разрешить ли регистрацию новых пользователей

## Значения по умолчанию

По умолчанию используются:

- директория установки: `/opt/supabase`
- база PostgreSQL: `postgres`
- внешний порт PostgreSQL: `6543`
- внешний порт API / Kong: `8000`
- Studio локально на сервере: `127.0.0.1:3000`
- JWT expiry: `3600`
- dashboard admin user: `admin`

## После установки

Основная директория установки:

```bash
/opt/supabase
```

Главный файл с параметрами:

```bash
/opt/supabase/.env
```

Посмотреть параметры:

```bash
cd /opt/supabase
cat .env
```

Или коротко:

```bash
grep -E 'STACK_VERSION|INSTALL_DIR|POSTGRES|KONG|STUDIO|SERVICE_|JWT|API_EXTERNAL_URL|DISABLE_SIGNUP' /opt/supabase/.env
```

## Доступы после установки

### PostgreSQL

Смотри в `.env`:

- `DB_PUBLIC_PORT`
- `POSTGRES_DB`
- `SERVICE_PASSWORD_POSTGRES`

Подключение снаружи:

- host: IP сервера
- port: `DB_PUBLIC_PORT`
- database: `POSTGRES_DB`
- user: `postgres`
- password: `SERVICE_PASSWORD_POSTGRES`

Внутри docker-сети БД доступна как `db`.

### API / Kong

Смотри в `.env`:

- `KONG_HTTP_PORT`
- `SERVICE_URL_SUPABASEKONG`
- `API_EXTERNAL_URL`

Если выбран режим `ip`, публичный URL будет таким:

```bash
http://IP_СЕРВЕРА:8000
```

Если выбран режим `domain`, публичный URL будет таким:

```bash
https://ВАШ_ДОМЕН
```

### Studio

Studio открывается только локально на сервере:

```bash
http://127.0.0.1:3000
```

### Dashboard admin

Смотри в `.env`:

- `SERVICE_USER_ADMIN`
- `SERVICE_PASSWORD_ADMIN`

### JWT / ключи

Смотри в `.env`:

- `SERVICE_PASSWORD_JWT`
- `SERVICE_SUPABASEANON_KEY`
- `SERVICE_SUPABASESERVICE_KEY`
- `JWT_EXPIRY`

## Что копируется в директорию установки

`install.sh` копирует в директорию установки только это:

- `.env`
- `docker-compose.yml`
- `volumes/db/*.sql`
- `volumes/api/kong.yml`
- `volumes/api/kong-entrypoint.sh`

Итоговая структура после установки:

```text
/opt/supabase/
├── .env
├── docker-compose.yml
└── volumes/
    ├── api/
    │   ├── kong-entrypoint.sh
    │   └── kong.yml
    └── db/
        ├── _supabase.sql
        ├── jwt.sql
        ├── logs.sql
        ├── pooler.sql
        ├── realtime.sql
        ├── roles.sql
        └── webhooks.sql
```

## Где лежат данные

Важно:

- `volumes/db/*.sql` — это init-скрипты
- реальные данные PostgreSQL лежат в Docker volumes

Имена volumes:

- `supabase-db-data`
- `supabase-db-config`

Посмотреть volumes:

```bash
docker volume ls | grep supabase
```

Посмотреть путь volume на хосте:

```bash
docker volume inspect supabase-db-data
```

## Проверка

Проверить контейнеры:

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

Логи Auth:

```bash
cd /opt/supabase
sudo docker compose logs -f supabase-auth
```

## Удаление

Запускать нужно по пути к самому скрипту:

```bash
sudo bash ~/auto-install-supabase-docker/uninstall.sh
```

Или с указанием своей директории установки:

```bash
sudo bash ~/auto-install-supabase-docker/uninstall.sh /opt/supabase
```

Что делает удаление:

- спрашивает, удалять ли Docker-образы этого стека
- останавливает и удаляет контейнеры
- удаляет volumes
- удаляет orphan-контейнеры
- по подтверждению удаляет директорию установки

## Важно

- наружу публикуются только PostgreSQL и Kong/API
- Studio публикуется только на `127.0.0.1:${STUDIO_PORT}`
- реальные доступы после установки всегда смотри в `/opt/supabase/.env`
- source of truth после установки — сгенерированный `.env`, а не `.env.example`

## Файлы, которые реально используются установщиком

Обязательные файлы:

```text
install.sh
uninstall.sh
docker-compose.yml.example
.env.example
VERSION
CHANGELOG.md
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

Дополнительные файлы в репозитории есть, но текущий `install.sh` их в директорию установки не копирует.
