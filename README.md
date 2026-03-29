# auto-install-supabase-docker

Интерактивный установщик упрощённого self-hosted Supabase через Docker Compose.

## Что ставится

Устанавливаются сервисы:

- PostgreSQL
- PostgREST
- GoTrue (Auth)
- Postgres Meta
- Kong
- Studio



## Что важно

- наружу публикуются только:
  - `Postgres` на настраиваемом внешнем порту
  - `Kong/API` на настраиваемом внешнем порту
- `Studio` публикуется только локально на `127.0.0.1:3000`
- `Kong` использует файлы:
  - `volumes/api/kong.yml`
  - `volumes/api/kong-entrypoint.sh`
- SQL-файлы из `volumes/db/*.sql` копируются в директорию установки и используются при инициализации БД
- после установки выполняются:
  - `docker compose config`
  - `docker compose pull`
  - `docker compose up -d`

## Установка

```bash
rm -rf ~/auto-install-supabase-docker
git clone https://github.com/staeer/auto-install-supabase-docker.git
cd auto-install-supabase-docker
sudo bash install.sh
```

## Что спросит установщик

Установщик по шагам спросит:

- режим доступа:
  - `1` — домен + reverse proxy + HTTPS
  - `2` — прямой доступ по IP:порт
- домен Supabase или IP/hostname сервера
- папку установки
- имя базы PostgreSQL
- внешний порт Postgres
- внешний порт API/Kong
- JWT expiry
- пароль Postgres
- JWT secret
- логин Dashboard Basic Auth
- пароль Dashboard Basic Auth
- разрешить ли регистрацию новых пользователей

## Значения по умолчанию

По умолчанию используются:

- папка установки: `/opt/supabase`
- база PostgreSQL: `postgres`
- внешний порт Postgres: `6543`
- внешний порт API/Kong: `8000`
- локальный порт Studio: `3000`
- JWT expiry: `3600`

## После установки

Открывай:

- публичный API:
  - `http://IP_ИЛИ_ДОМЕН:8000`
  - или домен через твой reverse proxy, если выбран режим `domain`
- Studio локально на сервере:
  - `http://127.0.0.1:3000`

## Где брать данные после установки

После установки основная рабочая директория — это папка установки:

```bash
/opt/supabase
```

Если при установке указывался другой путь — используй его.

### Что лежит в директории установки

В директории установки находятся:

- `.env` — все основные параметры доступа и настройки
- `docker-compose.yml` — итоговый compose-файл
- `volumes/api/` — файлы конфигурации Kong
- `volumes/db/` — SQL-файлы инициализации
- Docker volumes с данными контейнеров создаются отдельно Docker'ом

### Главный файл с доступами

Все основные данные после установки бери из:

```bash
/opt/supabase/.env
```

Посмотреть:

```bash
cd /opt/supabase
cat .env
```

Или так:

```bash
grep -E 'POSTGRES|KONG|STUDIO|SERVICE_|JWT|API_EXTERNAL_URL' /opt/supabase/.env
```

## Какие данные где смотреть

### Доступ к PostgreSQL

Смотри в `.env`:

- `DB_PUBLIC_PORT` — внешний порт PostgreSQL
- `POSTGRES_DB` — имя базы
- `SERVICE_PASSWORD_POSTGRES` — пароль PostgreSQL

Подключение с хоста/сети:

- host: IP сервера
- port: `DB_PUBLIC_PORT`
- database: `POSTGRES_DB`
- user: `postgres`
- password: `SERVICE_PASSWORD_POSTGRES`

Важно:
внутри docker-сети сервис БД доступен как `db`, а снаружи — по IP сервера и внешнему порту `DB_PUBLIC_PORT`.

### Доступ к API / Kong

Смотри в `.env`:

- `KONG_HTTP_PORT` — внешний порт API
- `SERVICE_URL_SUPABASEKONG` — основной URL
- `API_EXTERNAL_URL` — внешний API URL

Обычно это:

```bash
http://IP_СЕРВЕРА:8000
```

или домен, если ставилось в режиме domain.

### Доступ к Studio

Studio публикуется только локально на сервере:

```bash
http://127.0.0.1:3000
```

Порт берётся из `STUDIO_PORT`, но в текущем установщике он по факту фиксируется как `3000`.

### Логин в Dashboard / Studio Basic Auth

Смотри в `.env`:

- `SERVICE_USER_ADMIN`
- `SERVICE_PASSWORD_ADMIN`

Это логин и пароль для dashboard basic auth через Kong.

### JWT / ключи Supabase

Смотри в `.env`:

- `SERVICE_PASSWORD_JWT` — JWT secret
- `SERVICE_SUPABASEANON_KEY` — anon key
- `SERVICE_SUPABASESERVICE_KEY` — service_role key
- `JWT_EXPIRY` — срок жизни JWT

Именно эти значения нужны для клиентов, интеграций и API.

## Где лежат реальные данные PostgreSQL

Файлы самой базы лежат не в `.env` и не в `volumes/db/`.

`volumes/db/` в проекте — это только SQL-файлы инициализации.

Реальные данные PostgreSQL хранятся в Docker volume:

- `supabase-db-data`
- `supabase-db-config`

Это задано в `docker-compose.yml`.

Посмотреть volume'ы:

```bash
docker volume ls | grep supabase
```

Посмотреть путь volume на хосте:

```bash
docker volume inspect supabase-db-data
```

## Что важно понимать

- `.env` — это копия всех введённых параметров установки
- `volumes/db/*.sql` — это не живая база, а init-скрипты
- живая база хранится в Docker volume `supabase-db-data`
- для подключения к базе, Studio и API после установки почти всё берётся из `.env`

## Быстрые команды

Показать доступы:

```bash
cd /opt/supabase
grep -E 'POSTGRES_DB|DB_PUBLIC_PORT|KONG_HTTP_PORT|STUDIO_PORT|SERVICE_USER_ADMIN|SERVICE_PASSWORD_ADMIN|SERVICE_PASSWORD_POSTGRES|SERVICE_SUPABASEANON_KEY|SERVICE_SUPABASESERVICE_KEY|SERVICE_URL_SUPABASEKONG' .env
```

Проверить контейнеры:

```bash
cd /opt/supabase
sudo docker compose ps
```

Посмотреть volume базы:

```bash
docker volume inspect supabase-db-data
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
sudo docker compose logs -f auth
```

## Сетевые порты

- `${DB_PUBLIC_PORT}` → Postgres `5432`
- `${KONG_HTTP_PORT}` → Kong `8000`
- `127.0.0.1:${STUDIO_PORT}` → Studio `3000`

## Удаление

```bash
cd ~/auto-install-supabase-docker
sudo bash uninstall.sh
```

Для другого пути установки:

```bash
cd ~/auto-install-supabase-docker
sudo bash uninstall.sh /opt/supabase
```

Удаление делает:

- `docker compose down -v --remove-orphans`
- по подтверждению удаляет директорию установки целиком

## Обязательные файлы в репозитории

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
docker-compose.yml.example
install.sh
uninstall.sh
```

Если одного из обязательных файлов нет, установщик остановится с ошибкой.

## Примечание по версиям

В репозитории сейчас есть рассинхрон версий между файлами:

- `install.sh` — `0.2.4`
- `CHANGELOG.md` — содержит `0.2.5`
- `.env.example` — `0.1.6`

Этот README описывает текущее фактическое поведение установщика и compose-файлов, а не красивую легенду о том, что всё синхронно. Красивые легенды — это к маркетингу, не к установщику.
