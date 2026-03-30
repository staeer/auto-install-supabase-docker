# auto-install-supabase-docker

Интерактивный установщик облегчённой self-hosted Supabase-сборки через Docker Compose.

Важно:
это не полный официальный стек Supabase.
В репозитории оставлены только сервисы, необходимые для базового self-hosted запуска.

Что входит:
- PostgreSQL
- PostgREST
- GoTrue (Auth)
- Postgres Meta
- Kong
- Studio

Что не входит:
- сервисы, отсутствующие в этом репозитории и docker-compose
- полный официальный стек Supabase
- всё, что не перечислено выше как установленное

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

Посмотреть все параметры:

```bash
cd /opt/supabase
cat .env
```

## Доступы после установки

## Важно

Для корректной работы копирования ключей в Studio рекомендуется открывать интерфейс через домен. Если копирование не срабатывает, ключи можно взять вручную из файла `.env` в директории установки.

### Быстро показать основные доступы

```bash
sudo grep -E 'DB_PUBLIC_PORT|POSTGRES_DB|SERVICE_PASSWORD_POSTGRES|SERVICE_USER_ADMIN|SERVICE_PASSWORD_ADMIN|SERVICE_URL_SUPABASEKONG|API_EXTERNAL_URL|SERVICE_SUPABASEANON_KEY|SERVICE_SUPABASESERVICE_KEY' /opt/supabase/.env
```

### PostgreSQL

#### Подключение снаружи сервера

Для подключения из pgAdmin, DBeaver, n8n или другого внешнего клиента использовать:

- Host: IP сервера
- Port: `DB_PUBLIC_PORT`
- Database: `POSTGRES_DB`
- User: `postgres`
- Password: `SERVICE_PASSWORD_POSTGRES`

Пример:

```text
Host: 192.168.0.18
Port: 6543
Database: postgres
User: postgres
Password: <значение SERVICE_PASSWORD_POSTGRES из .env>
```

Показать только данные для подключения к PostgreSQL:

```bash
sudo grep -E 'DB_PUBLIC_PORT|POSTGRES_DB|SERVICE_PASSWORD_POSTGRES' /opt/supabase/.env
```

Важно:

- пользователь PostgreSQL всегда `postgres`
- `SERVICE_USER_ADMIN` — это не пользователь базы
- для внешнего подключения использовать IP сервера и внешний порт
- `POSTGRES_HOST=db` используется только внутри docker-сети

#### Подключение внутри Docker Compose сети

Для сервисов внутри compose-сети использовать:

- Host: `db`
- Port: `5432`
- Database: `POSTGRES_DB`
- User: `postgres`
- Password: `SERVICE_PASSWORD_POSTGRES`

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

Показать только адреса API:

```bash
sudo grep -E 'KONG_HTTP_PORT|SERVICE_URL_SUPABASEKONG|API_EXTERNAL_URL' /opt/supabase/.env
```

### Studio

Studio открывается:

- через домен, если он привязан
- локально на сервере:

```bash
http://127.0.0.1:3000
```

### Dashboard admin

Для входа в Studio / dashboard использовать:

- User: `SERVICE_USER_ADMIN`
- Password: `SERVICE_PASSWORD_ADMIN`

Показать только данные dashboard admin:

```bash
sudo grep -E 'SERVICE_USER_ADMIN|SERVICE_PASSWORD_ADMIN' /opt/supabase/.env
```

### JWT / ключи

Смотри в `.env`:

- `SERVICE_PASSWORD_JWT`
- `SERVICE_SUPABASEANON_KEY`
- `SERVICE_SUPABASESERVICE_KEY`
- `JWT_EXPIRY`

Показать только ключи:

```bash
sudo grep -E 'SERVICE_PASSWORD_JWT|SERVICE_SUPABASEANON_KEY|SERVICE_SUPABASESERVICE_KEY|JWT_EXPIRY' /opt/supabase/.env
```

### Что есть что

- `postgres` — пользователь базы PostgreSQL
- `SERVICE_PASSWORD_POSTGRES` — пароль пользователя PostgreSQL
- `SERVICE_USER_ADMIN` — логин Studio / dashboard
- `SERVICE_PASSWORD_ADMIN` — пароль Studio / dashboard
- `SERVICE_SUPABASEANON_KEY` — anon API key
- `SERVICE_SUPABASESERVICE_KEY` — service API key

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
