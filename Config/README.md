# Configuration bundle

- `mac2/`: primary edge (nginx), primary DNS (dnsmasq), client resolver
- `mac3/`: standby edge (nginx), backup DNS (dnsmasq), PF anchor and the `pf.conf` load line
- `tls/`: public certificates only (`teamX-ca.crt`, `app.teamX.test.crt`)

Backends: `backend1/` (port 5001) and `backend2/` (port 5002); run `npm install && node index.js` in each.
