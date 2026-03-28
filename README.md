# auto-install-supabase-docker

Интерактивный установщик облегчённого Supabase через Docker Compose.

## Установка

```bash
git clone https://github.com/staeer/auto-install-supabase-docker.git
cd auto-install-supabase-docker
sudo bash install.sh
```

Установщик:
- спрашивает режим доступа: домен/HTTPS или IP:порт
- генерирует пароли и JWT ключ
- пишет `.env`
- проверяет `.env`
- копирует compose и SQL/Kong файлы
- запускает стек

## Важно

Файлы в `volumes/db/*.sql` и `volumes/api/kong.yml` должны быть твоими рабочими файлами.
Если там остались заглушки `PLACEHOLDER_REPLACE_ME`, установщик остановится.

## Удаление

```bash
sudo bash uninstall.sh
```
