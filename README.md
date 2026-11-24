# Team X: Private Network Service Platform (Computer Networks Project)

| Folder | Contents |
|---|---|
| `Report/` | **Final Phase 2 report**: `TeamX_Phase2_IEEE_Report.pdf` (IEEE format), its HTML source, and the earlier markdown draft |
| `Evidence/` | Test logs and packet capture: `DNS/`, `Caching/`, `Firewall/`, `Failover/`, `Wireshark/` (`.pcap`), `Showcase/`, `LAN/` |
| `Config/` | Configuration bundle: `mac2/` (primary nginx + dnsmasq + resolver, Phase 1 nginx), `mac3/` (standby nginx, backup dnsmasq, PF anchor), `tls/` (public certificates only) |
| `backend1/`, `backend2/` | Backend A (port 5001) and Backend B (port 5002), Express.js |

## Hosts

| Host | IP | Role |
|---|---|---|
| Mac 2 (Aarsh) | 10.7.25.77 | Primary nginx edge (TLS 1.3, HTTP/2), primary DNS (Mac 1 role) |
| Mac 3 (Sanal) | 10.7.2.16 | Backend A/B, backup DNS, standby nginx edge, PF isolation |

## Run the backends (Mac 3)

```bash
cd backend1 && npm install && node index.js   # Backend A on :5001
cd backend2 && npm install && node index.js   # Backend B on :5002
```

Endpoints: `GET /` (`Cache-Control: max-age=60`, ETag) and `GET /api/status` (`no-store`). Every response carries an `X-Backend: A|B` header.

## Re-export the report PDF

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --no-pdf-header-footer \
  --print-to-pdf=Report/TeamX_Phase2_IEEE_Report.pdf "file://$PWD/Report/TeamX_Phase2_IEEE_Report.html"
```
