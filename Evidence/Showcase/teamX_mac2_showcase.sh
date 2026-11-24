#!/bin/bash

# TeamX Phase 2 - One-terminal showcase
# Safe checks only: does not stop services or change configurations.

MAC2="10.7.25.77"
MAC3="10.7.2.16"
CA="$HOME/cn-phase2/tls/teamX-ca.crt"
CERT="$HOME/cn-phase2/tls/app.teamX.test.crt"

PASS=0
FAIL=0
WARN=0

LOG="$HOME/Desktop/TeamX_Showcase_$(date +%Y%m%d_%H%M%S).txt"

exec > >(tee "$LOG") 2>&1

echo "=================================================="
echo "          TEAM X - PHASE 2 SHOWCASE"
echo "=================================================="
echo "Date: $(date)"
echo "Mac 2: $MAC2"
echo "Mac 3: $MAC3"
echo "Log: $LOG"
echo

pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }
warn() { echo "[PENDING / INFO] $1"; WARN=$((WARN+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --------------------------------------------------
echo "1. DNS SERVER TESTS"
echo "--------------------------------------------------"

for server in "$MAC2" "$MAC3"; do
    result=$(dig +time=2 +tries=1 +short @"$server" app.teamX.test 2>/dev/null | tail -n 1)
    if [ "$result" = "$MAC2" ]; then
        pass "DNS $server resolves app.teamX.test to $MAC2"
    else
        fail "DNS $server - app.teamX.test (received: $result)"
    fi

    result=$(dig +time=2 +tries=1 +short @"$server" google.com 2>/dev/null | head -n 1)
    if [ -n "$result" ]; then
        pass "DNS $server resolves an external domain"
    else
        fail "DNS $server external resolution"
    fi
done

result=$(dscacheutil -q host -a name app.teamX.test 2>/dev/null)
if echo "$result" | grep -q "$MAC2"; then
    pass "macOS system resolver resolves app.teamX.test"
else
    fail "macOS system resolver"
fi

result=$(dscacheutil -q host -a name api.teamX.test 2>/dev/null)
if echo "$result" | grep -q "$MAC2"; then
    pass "macOS system resolver resolves api.teamX.test"
else
    fail "macOS system resolver for api.teamX.test"
fi

# --------------------------------------------------
echo
echo "2. TLS CERTIFICATE VALIDATION"
echo "--------------------------------------------------"

if [ -f "$CA" ] && [ -f "$CERT" ]; then
    if openssl verify -CAfile "$CA" "$CERT"; then
        pass "Application certificate verifies against TeamX CA"
    else
        fail "Certificate verification"
    fi
else
    fail "CA or certificate file missing"
fi

# --------------------------------------------------
echo
echo "3. DIRECT BACKEND TESTS"
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
        pass "Backend $EXPECTED responds on port $PORT"
        cat "$TMP/backend.b"
    else
        fail "Backend $EXPECTED on port $PORT (HTTP $CODE, identity $ACTUAL)"
    fi
done

# --------------------------------------------------
echo
echo "4. HTTPS APPLICATION TESTS"
echo "--------------------------------------------------"

for HOST in app.teamX.test api.teamX.test; do
    CODE=$(curl -sS --connect-timeout 3 --max-time 8 \
        --cacert "$CA" \
        -D "$TMP/https.h" -o "$TMP/https.b" \
        -w "%{http_code}" \
        "https://$HOST/api/status" 2>/dev/null)

    EDGE=$(grep -i '^X-Edge:' "$TMP/https.h" 2>/dev/null |
        tail -n 1 | tr -d '\r')
    BACKEND=$(grep -i '^X-Backend:' "$TMP/https.h" 2>/dev/null |
        tail -n 1 | tr -d '\r')

    if [ "$CODE" = "200" ]; then
        pass "HTTPS $HOST returns HTTP 200"
        echo "$EDGE"
        echo "$BACKEND"
        cat "$TMP/https.b"
    else
        fail "HTTPS $HOST (HTTP $CODE)"
    fi
done

# --------------------------------------------------
echo
echo "5. LOAD BALANCING TEST - SIX REQUESTS"
echo "--------------------------------------------------"

A_COUNT=0
B_COUNT=0
LB_ERRORS=0

for i in 1 2 3 4 5 6; do
    CODE=$(curl -sS --connect-timeout 3 --max-time 8 \
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
            A) A_COUNT=$((A_COUNT+1)) ;;
            B) B_COUNT=$((B_COUNT+1)) ;;
            *) LB_ERRORS=$((LB_ERRORS+1)) ;;
        esac
    else
        LB_ERRORS=$((LB_ERRORS+1))
    fi
done

echo "Backend A requests: $A_COUNT"
echo "Backend B requests: $B_COUNT"

if [ "$LB_ERRORS" -eq 0 ] && [ "$A_COUNT" -gt 0 ] && [ "$B_COUNT" -gt 0 ]; then
    pass "Load balancing reached both backends"
else
    fail "Load balancing did not successfully reach both backends"
fi

# --------------------------------------------------
echo
echo "6. HTTP CACHE HEADER INSPECTION"
echo "--------------------------------------------------"

CACHE=$(grep -i '^Cache-Control:' "$TMP/https.h" 2>/dev/null |
    tail -n 1 | tr -d '\r')

echo "Observed: $CACHE"

if echo "$CACHE" | grep -qi 'no-store'; then
    warn "Application currently sends no-store; HTTP caching is not demonstrated"
else
    warn "Inspect cache behavior separately; a cache header alone does not prove cache reuse"
fi

# --------------------------------------------------
echo
echo "7. HISTORICAL FAILURE TEST EVIDENCE"
echo "--------------------------------------------------"

warn "Backend B outage: previously tested; six successful responses through A"
warn "Primary DNS outage: previously tested; application remained accessible"
warn "These are previous test results, not re-executed by this script"

# --------------------------------------------------
echo
echo "8. REMAINING MANUAL DEMONSTRATIONS"
echo "--------------------------------------------------"

warn "Wireshark: DNS, TCP handshake and TLS handshake capture"
warn "DNS TTL: record change, cache observation and expiry"
warn "Service isolation: firewall restriction of direct backend access"
warn "Backend A outage: verify Backend B serves requests"
warn "Edge migration: standby nginx and DNS cutover"
warn "Injected fault: demonstrate troubleshooting"

# --------------------------------------------------
echo
echo "=================================================="
echo "             FINAL SHOWCASE SUMMARY"
echo "=================================================="
echo "Passed live checks: $PASS"
echo "Failed live checks: $FAIL"
echo "Pending / informational: $WARN"
echo
echo "Previous failover evidence:"
echo "- Backend B stopped -> Backend A served requests"
echo "- Primary DNS stopped -> application remained accessible"
echo
echo "Full output saved at:"
echo "$LOG"
echo "=================================================="
