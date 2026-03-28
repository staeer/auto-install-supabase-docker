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

## Важно

Файлы `volumes/db/*.sql` и `volumes/api/kong.yml` в этом архиве содержат заглушки.
Замени их на свои проверенные рабочие файлы перед установкой.
