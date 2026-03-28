# auto-install-supabase-docker

Интерактивный установщик облегчённого Supabase.

Установка:
```bash
git clone <repo>
cd auto-install-supabase-docker
sudo bash install.sh
```

Публикуется наружу:
- Kong/API: `8000`
- PostgreSQL: `6543`

Studio наружу не публикуется. Через Kong открывай `http://HOST:8000`, локально на сервере Studio доступна на `http://127.0.0.1:3000`.
