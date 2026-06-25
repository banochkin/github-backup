# github-backup

С кайфом + быстро + просто (на это упор) регулярный бекап всех реп из Github на любой vps.

Нужен [github.com/gabrie30/ghorg](github.com/gabrie30/ghorg).

## Установка

```
cp accounts.env.example accounts.env
```

```
chmod 600 /root/github-backup/accounts.env
chmod 700 /root/github-backup/github-backup.sh
```

/etc/systemd/system/github-backup.service:
```
[Unit]
Description=Mirror GitHub accounts and their organizations
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/root/github-backup/github-backup.sh
```

/etc/systemd/system/github-backup.timer:
```
[Unit]
Description=Run github-backup daily

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
```

```
systemctl daemon-reload
systemctl enable --now github-backup.timer
journalctl -u github-backup.service -f
```

## Удалённые репозитории (trash)

При удалении на github репо переносятся в `/data/_trash/...` с таймстампом:

- user: `/data/<account>/repos/<repo>`  → `/data/_trash/<account>/repos/<repo>__<UTC>`
- org:  `/data/<account>/orgs/<org>/<repo>` → `/data/_trash/<account>/orgs/<org>/<repo>__<UTC>`

Проверка по GitHub API (источник истины), а не по ghorg `--prune`.

Если запрос к API упал или вернул пустой список, перенос пропускается (защита от ложного сноса при сбое токена/сети) — см. строки `trash skipped` в логах.

## Проверка бекапов

**Содержимое** — что и когда последний раз забекапилось (сортировка по свежести):

```bash
./backup-status.sh            # или: ./backup-status.sh /data
```

Колонки: `LAST FETCH` (когда зеркало последний раз синхронизировалось),
`LAST COMMIT` (дата свежайшего коммита в зеркале), `REPO`. Верхние строки —
самое недавнее. Внизу — счётчик зеркал в trash и общий размер.

**Прогоны** — отработал ли таймер и с каким результатом (systemd):

```bash
systemctl list-timers github-backup.timer --no-pager   # когда следующий / последний запуск
systemctl status github-backup.service --no-pager      # результат последнего прогона
journalctl -u github-backup.service -n 100 --no-pager  # полный лог последнего прогона
journalctl -u github-backup.service -f                 # смотреть вживую
```

---

[banochkin.com DAO](https://banochkin.com/) 🏴‍☠️