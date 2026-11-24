# Mac 2 (edge) configuration

| File | Source on Mac 2 |
|---|---|
| `nginx-teamX-primary.conf` | `/opt/homebrew/etc/nginx/servers/teamX.conf` (Phase 2) |
| `nginx-phase1-teamX.conf` | Phase 1 `teamX.conf`, extracted from the pre-Phase-2 `nginx -T` dump |
| `dnsmasq-primary.conf` | `/opt/homebrew/etc/dnsmasq.conf` (comments stripped) |
| `etc-resolver.txt` | `/etc/resolver/` per-domain resolver file for the project domain |
| `client-resolver.txt` | `scutil --dns` nameserver lines (default resolver + per-domain resolver) |

Private keys (`teamX-ca.key`, `app.teamX.test.key`) are intentionally not included.
