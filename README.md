# github-backup

с кайфом + быстро + просто (на это упор) регулярный бекап всех реп из Github на любой vps.

нужен github.com/gabrie30/ghorg.

## установка

```cp accounts.env.example accounts.env```

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
bashsystemctl daemon-reload
systemctl enable --now github-backup.timer
journalctl -u github-backup.service -f
```

## удалённые репозитории (trash)

при удалении на github репо переносятся в `/data/_trash/...` с таймстампом:

- user: `/data/<account>/repos/<repo>`  → `/data/_trash/<account>/repos/<repo>__<UTC>`
- org:  `/data/<account>/orgs/<org>/<repo>` → `/data/_trash/<account>/orgs/<org>/<repo>__<UTC>`

проверка по GitHub API (источник истины), а не по ghorg `--prune`.

если запрос к API упал или вернул пустой список, перенос пропускается (защита от ложного сноса при сбое токена/сети) — см. строки `trash skipped` в логах.

---

[banochkin.com DAO](https://banochkin.com/) 🏴‍☠️