cp accounts.env.example accounts.env   # заполнить реальными токенами

chmod 600 /root/github-backup/accounts.env
chmod 700 /root/github-backup/github-backup.sh

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

bashsystemctl daemon-reload
systemctl enable --now github-backup.timer
journalctl -u github-backup.service -f   # логи прогонов
```

## Удалённые репозитории (trash)

Репозитории, удалённые на GitHub в аккаунте или организации, не стираются
локально, а переносятся в `/data/_trash/...` с таймстампом:

- user: `/data/<account>/repos/<repo>`  → `/data/_trash/<account>/repos/<repo>__<UTC>`
- org:  `/data/<account>/orgs/<org>/<repo>` → `/data/_trash/<account>/orgs/<org>/<repo>__<UTC>`

Сверка идёт по GitHub API (источник истины), а не по ghorg `--prune`. Если
запрос к API упал или вернул пустой список, перенос пропускается (защита от
ложного сноса при сбое токена/сети) — см. строки `trash skipped` в логах.

Требуется bash 4+ (`declare -A`, `mapfile`) — на Debian/LXC выполняется.
