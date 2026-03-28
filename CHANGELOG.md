## 0.1.5

### Fixed
- Полностью переписан интерактивный ввод в `install.sh`.
- Убран `command substitution` для обычных и секретных prompt-ов.
- Значения теперь записываются через `printf -v` в переменные по имени, без попадания переводов строки в `.env`.
- Исправлен баг, из-за которого `SERVICE_PASSWORD_POSTGRES`, `SERVICE_PASSWORD_JWT` и `SERVICE_PASSWORD_ADMIN` записывались на следующую строку.
