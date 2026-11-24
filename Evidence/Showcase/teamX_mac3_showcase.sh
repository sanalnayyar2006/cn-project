#!/bin/bash

# TEAM X PHASE 2 - MAC 3 SHOWCASE
# Mac 3: Backup DNS + Backend A + Backend B

MAC2="10.7.25.77"
MAC3="10.7.2.16"
CA="$HOME/cn-phase2/tls/teamX-ca.crt"

PASS=0
FAIL=0
WARN=0

LOG="$HOME/Desktop/TeamX_Mac3_Showcase_$(date +%Y%m%d_%H%M%S).txt"

exec > >(tee "$LOG") 2>&1

pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }
warn() { echo "[PENDING / INFO] $1"; WARN=$((WARN+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "=================================================="
echo "       TEAM X - PHASE 2 MAC 3 SHOWCASE"
echo "=================================================="
echo "Date: $(date)"
echo "Mac 3: $MAC3"
echo "Mac 2: $MAC2"
echo "Log: $LOG"
echo

# --------------------------------------------------
echo "1. MAC 3 NETWORK CONNECTIVITY"
echo "--------------------------------------------------"

if ping -c 2 -W 2000 "$MAC2" >/dev/null 2>&1; then
    pass "Mac 3 can reach Mac 2"
else
    fail "Mac 2 connectivity"
fi

if ping -c 2 -W 2000 "$MAC3" >/dev/null 2>&1; then
    pass "Mac 3 local network interface reachable"
else
    warn "Ping to own LAN IP did not respond"
fi

# --------------------------------------------------
echo
echo "2. BACKUP DNS SERVER"
echo "--------------------------------------------------"

for HOST in app.teamX.test api.teamX.test; do
    RESULT=$(dig +time=2 +tries=1 +short @"$MAC3" "$HOST" 2>/dev/null | tail -n 1)

    if [ "$RESULT" = "$MAC2" ]; then
        pass "Mac 3 DNS resolves $HOST to $MAC2"
    else
        fail "$HOST DNS result: $RESULT"
    fi
done

RESULT=$(dig +time=2 +tries=1 +short @"$MAC3" google.com 2>/dev/null | head -n 1)

if [ -n "$RESULT" ]; then
    pass "Mac 3 DNS forwards external queries"
else
    fail "External DNS forwarding"
fi

# Check primary DNS directly
RESULT=$(dig +time=2 +tries=1 +short @"$MAC2" app.teamX.test 2>/dev/null | tail -n 1)

if [ "$RESULT" = "$MAC2" ]; then
    pass "Mac 2 primary DNS responds"
else
    fail "Mac 2 primary DNS"
fi

# --------------------------------------------------
echo
echo "3. MAC 3 DNS SERVICE"
echo "--------------------------------------------------"

if dig +time=2 +tries=1 +short @127.0.0.1 app.teamX.test 2>/dev/null | grep -q "$MAC2"; then
    pass "Local dnsmasq answers on Mac 3"
else
    fail "Local dnsmasq response"
fi

if lsof -nP -iUDP:53 -iTCP:53 2>/dev/null | grep -q dnsmasq; then
    pass "dnsmasq process is listening on port 53"
else
    fail "dnsmasq port 53 listener"
fi

# --------------------------------------------------
echo
echo "4. BACKEND A AND B"
echo "--------------------------------------------------"

for item in "5001:A" "5002:B"; do
    PORT="${item%%:*}"
    EXPECTED="${item##*:}"

    CODE=$(curl -sS --connect-timeout 3 --max-time 6 \
        -D "$TMP/backend.h" -o "$TMP/backend.b" \
        -w "%{http_code}" \
        "http://$MAC3:$PORT/api/status" 2>/dev/null)

    ACTUAL=$(grep -i '^X-Backend:' "$TMP/backend.h" 2>/dev/null |
        tail -n 1 | tr -d '\r' | awk -F': ' '{print $2}')

    if [ "$CODE" = "200" ] && [ "$ACTUAL" = "$EXPECTED" ]; then
        pass "Backend $EXPECTED operational on port $PORT"
        cat "$TMP/backend.b"
    else
        fail "Backend $EXPECTED (HTTP $CODE, identity $ACTUAL)"
    fi
done

# --------------------------------------------------
echo
echo "5. MAC 2 HTTPS EDGE"
echo "--------------------------------------------------"

if [ -f "$CA" ]; then
    CODE=$(curl -sS --connect-timeout 3 --max-time 8 \
        --resolve "app.teamX.test:443:$MAC2" \
        --cacert "$CA" \
        -D "$TMP/https.h" -o "$TMP/https.b" \
        -w "%{http_code}" \
        https://app.teamX.test/api/status 2>/dev/null)

    EDGE=$(grep -i '^X-Edge:' "$TMP/https.h" 2>/dev/null |
        tail -n 1 | tr -d '\r')
    BACKEND=$(grep -i '^X-Backend:' "$TMP/https.h" 2>/dev/null |
        tail -n 1 | tr -d '\r')

    if [ "$CODE" = "200" ]; then
        pass "Mac 3 reaches Mac 2 HTTPS application"
        echo "$EDGE"
        echo "$BACKEND"
        cat "$TMP/https.b"
    else
        fail "Mac 2 HTTPS application (HTTP $CODE)"
    fi
else
    fail "TeamX CA certificate missing at $CA"
fi

# --------------------------------------------------
echo
echo "6. LOAD BALANCING THROUGH MAC 2"
echo "--------------------------------------------------"

A=0
B=0
ERRORS=0

for i in 1 2 3 4 5 6; do
    CODE=$(curl -sS --connect-timeout 3 --max-time 8 \
        --resolve "app.teamX.test:443:$MAC2" \
        --cacert "$CA" \
        -D "$TMP/lb.h" -o "$TMP/lb.b" \
        -w "%{http_code}" \
        https://app.teamX.test/api/status 2>/dev/null)

    BACKEND=$(grep -i '^X-Backend:' "$TMP/lb.h" 2>/dev/null |
        tail -n 1 | tr -d '\r' | awk -F': ' '{print $2}')

    UPSTREAM=$(grep -i '^X-Upstream:' "$TMP/lb.h" 2>/dev/null |
        tail -n 1 | tr -d '\r')

    echo "Request $i: HTTP $CODE | Backend $BACKEND | $UPSTREAM"

    if [ "$CODE" = "200" ]; then
        case "$BACKEND" in
            A) A=$((A+1)) ;;
            B) B=$((B+1)) ;;
            *) ERRORS=$((ERRORS+1)) ;;
        esac
    else
        ERRORS=$((ERRORS+1))
    fi
done

echo "Backend A requests: $A"
echo "Backend B requests: $B"

if [ "$ERRORS" -eq 0 ] && [ "$A" -gt 0 ] && [ "$B" -gt 0 ]; then
    pass "Both backends reached through nginx"
else
    fail "Both-backend load balancing test"
fi

# --------------------------------------------------
echo
echo "7. SERVICE AND ARCHITECTURE INFORMATION"
echo "--------------------------------------------------"

echo "Mac 3 IP configuration:"
ifconfig en0 | grep -E 'inet |netmask'

echo
echo "Backend listeners:"
lsof -nP -iTCP:5001 -iTCP:5002 -sTCP:LISTEN 2>/dev/null

echo
echo "DNS listener:"
lsof -nP -iUDP:53 -iTCP:53 2>/dev/null

# --------------------------------------------------
echo
echo "8. OTHER DEMONSTRATIONS"
echo "--------------------------------------------------"

warn "Backend A outage and Backend B recovery: perform separately"
warn "DNS TTL and cache expiry: perform separately"
warn "Wireshark DNS, TCP and TLS packet capture: pending"
warn "Firewall-based service isolation: pending"
warn "Standby nginx edge migration: pending"
warn "Injected fault troubleshooting: pending"

# --------------------------------------------------
echo
echo "=================================================="
echo "             MAC 3 FINAL SUMMARY"
echo "=================================================="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Pending / informational: $WARN"
echo
echo "Report saved at:"
echo "$LOG"
echo "=================================================="
