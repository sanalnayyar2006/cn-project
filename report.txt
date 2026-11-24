# PHASE 2 FINAL REPORT

## Private Network Service Platform

### IEEE-Style Phase 2 Review

**Course:** Computer Networks  
**Review:** Phase 2 Review  
**Date:** 25 November 2026  
**Team:** Team X  
**University:** [Insert University Name]  
**Faculty:** [Insert Faculty Name]

**Team Members**

| S. No. | Name | Roll Number |
|---|---|---|
| 1 | [Member 1] | [Roll Number] |
| 2 | [Member 2] | [Roll Number] |
| 3 | [Member 3] | [Roll Number] |

---

# Abstract

This report presents the Phase 2 extensions to the Private Network Service Platform developed during Phase 1. The project implements a private network-based application environment using two macOS systems connected through a local area network. The primary objective of Phase 2 was to improve the resilience, availability, and security of the existing application infrastructure.

The Phase 2 extensions include a backup DNS resolver, TTL-based DNS behavior, firewall-based backend isolation, backend failure recovery, and a standby Nginx reverse-proxy edge server. Controlled experiments were performed to evaluate application availability during backend failure and primary-edge downtime. The implementation was also examined using command-line networking utilities, TLS diagnostics, and Wireshark packet analysis.

The results demonstrate successful DNS responses from both configured DNS servers, successful backend failure handling and recovery, firewall rule enforcement under controlled tests, and manual migration of application traffic to a standby edge server. The final primary-edge verification returned successful HTTP/2 responses through both backend services. The experiments also identified limitations, including the absence of automated DNS or edge failover, inconclusive system-level DNS fallback verification, and incomplete independent-device firewall testing.

**Keywords:** Computer Networks, DNS, DNS Redundancy, Nginx, Reverse Proxy, Load Balancing, TLS, Firewall, PF, High Availability, Failover, Wireshark, Network Troubleshooting.

---

# 1. INTRODUCTION

## 1.1 Project Overview

The Private Network Service Platform is a two-phase, team-based networking project designed to demonstrate how application requests travel between clients and servers over a private network.

The central idea of the project is that the application itself remains relatively simple, while the underlying network architecture is the primary focus. The project uses two computers to provide DNS resolution, backend application services, reverse proxy functionality, HTTPS communication, caching behavior, firewall-based access restrictions, and service recovery mechanisms.

Phase 1 focused on establishing the basic working application infrastructure. Phase 2 extended the system to improve service continuity, introduce redundancy, restrict backend access, and test how the system behaves when individual network components become unavailable.

## 1.2 Objectives of Phase 2

The main objectives were:

1. Introduce a backup DNS resolver to reduce dependence on a single DNS server.
2. Examine DNS TTL behavior and the effect of caching during record changes.
3. Restrict direct backend access using firewall rules.
4. Demonstrate backend failure detection, traffic recovery, and service restoration.
5. Configure a standby Nginx edge server on a second computer.
6. Demonstrate application availability during primary-edge downtime through manual migration.
7. Analyze DNS, TCP, TLS, and application traffic using Wireshark.
8. Develop a systematic troubleshooting approach based on the networking layers.
9. Maintain evidence of the configuration, testing, and observed results.

## 1.3 Scope

The implementation was carried out using two macOS computers connected to the same local network. Native macOS services and Homebrew-installed software were used instead of container-based deployment.

The project scope includes private DNS, backend services, reverse proxying, HTTPS, caching headers, firewall rules, packet analysis, and controlled resilience testing.

Automated DNS-based failover, automated edge health monitoring, and fully automated edge migration were not implemented.

---

# 2. WHAT CHANGED FROM PHASE 1

## 2.1 Phase 1 Baseline

Phase 1 established the basic private application environment. The main components included:

- A private LAN connecting the two computers.
- DNS resolution for application hostnames.
- Two backend application services.
- An Nginx reverse proxy and load balancer.
- HTTPS using a locally generated certificate authority and server certificate.
- HTTP cache headers and ETag-based validation.
- Network packet inspection using Wireshark.
- Basic connectivity and failure-related testing.

The main purpose of Phase 1 was to demonstrate normal application connectivity and understand the journey of a network request from the client to the backend and back.

## 2.2 Phase 2 Extensions

Phase 2 extended the original architecture in five major areas.

| Feature | Phase 1 | Phase 2 extension |
|---|---|---|
| DNS | Primary private DNS | Primary and backup DNS services |
| DNS caching | Basic DNS resolution | TTL observations and controlled record changes |
| Backend security | Backend connectivity | PF firewall restrictions and backend isolation |
| Backend availability | Two backend services | Controlled backend failure and recovery |
| Edge availability | Primary Nginx edge | Standby Nginx edge on the second computer |
| Troubleshooting | Basic connectivity checks | Layer-by-layer diagnostics |
| Packet analysis | Basic packet inspection | Detailed DNS, TCP, and TLS frame examination |

The most important change was the shift from demonstrating a functioning application to examining its behavior under failure conditions.

---

# 3. NETWORK ARCHITECTURE

## 3.1 Physical Network Setup

The project uses two macOS computers connected to the same local area network.

The computers operate within the same subnet using the subnet mask 255.255.224.0 and gateway 10.7.0.1.

The two systems have different responsibilities:

**Mac 2 — Primary Edge System**

- Primary Nginx reverse proxy.
- Primary DNS resolver.
- TLS certificate authority and server certificate storage.
- Main entry point for HTTPS application requests.

**Mac 3 — Backend and Standby System**

- Backend A application service.
- Backend B application service.
- Backup DNS resolver.
- Standby Nginx reverse proxy.
- PF firewall rules restricting backend access.

## 3.2 IP Addressing and Device Inventory

| Component | System | IP Address | Role |
|---|---|---|---|
| Primary edge | Mac 2 | 10.7.25.77 | Primary HTTPS entry point |
| Backend system | Mac 3 | 10.7.2.16 | Hosts both backend services |
| Backup DNS | Mac 3 | 10.7.2.16 | Secondary DNS service |
| Primary DNS | Mac 2 | 10.7.25.77 | Primary DNS service |
| Default gateway | LAN router | 10.7.0.1 | Network gateway |
| Subnet mask | Both systems | 255.255.224.0 | LAN subnet configuration |

**Note:** Both computers are on the same LAN and use the same subnet mask. Their IP addresses are different and are used to identify the corresponding services.

## 3.3 Logical Network Architecture

The following logical representation describes the normal application request flow.

```text
                  CLIENT / MAC 2
                 10.7.25.77
                       |
                       |
              DNS RESOLUTION
                       |
             app.teamX.test
             api.teamX.test
                       |
                       |
              HTTPS REQUEST
                  TCP 443
                       |
                       v
             +------------------+
             |   MAC 2          |
             | Primary Nginx    |
             | Reverse Proxy    |
             | Load Balancer    |
             +------------------+
                       |
              Private LAN Traffic
                       |
                       v
             +------------------+
             |   MAC 3          |
             | 10.7.2.16        |
             +------------------+
                 /          \
                /            \
               v              v
       +-------------+  +-------------+
       | Backend A   |  | Backend B   |
       | Port 5001   |  | Port 5002   |
       +-------------+  +-------------+

       Additional services on Mac 3:
       - Backup DNS resolver
       - Standby Nginx edge
       - PF firewall
```

The standby Nginx service on Mac 3 provides an alternate application entry point when the primary edge is unavailable. It routes requests to the locally hosted backend services.

## 3.4 Application Request Flow

Under normal operation, the request follows these steps:

1. The client requests `app.teamX.test`.
2. The DNS resolver returns the configured primary edge IP address.
3. The client establishes a TCP connection to port 443.
4. TLS negotiation takes place.
5. The client sends an HTTPS request to the Nginx reverse proxy.
6. Nginx forwards the request to one of the backend services.
7. The backend processes the request.
8. The response returns through Nginx to the client.

This arrangement separates the application entry point from the backend services and allows the reverse proxy to distribute requests across the backend instances.

---

# 4. SOFTWARE AND SERVICE CONFIGURATION

## 4.1 Operating Environment

Both systems use macOS and Apple Silicon hardware.

Homebrew was used to install and manage the networking software.

| Software / Tool | Purpose |
|---|---|
| macOS | Host operating system |
| Homebrew | Package and service management |
| Nginx | Reverse proxy and load balancing |
| Node.js | Backend application runtime |
| Express.js | Backend HTTP services |
| dnsmasq | Private DNS services |
| PF | Packet filtering and firewall rules |
| OpenSSL | TLS certificate inspection and verification |
| curl | HTTP and HTTPS testing |
| dig | DNS query testing |
| nc | TCP connectivity testing |
| tcpdump | Packet capture |
| Wireshark / TShark | Packet analysis |

Docker was not used in the final implementation. The services were run natively on macOS.

## 4.2 DNS Configuration

The project uses dnsmasq to provide private DNS resolution.

The two application hostnames are:

- `app.teamX.test`
- `api.teamX.test`

Both hostnames are configured to resolve to the primary edge address during normal operation.

The configured DNS records are:

```conf
address=/app.teamX.test/10.7.25.77
address=/api.teamX.test/10.7.25.77
local-ttl=60
```

The same application records were configured on both DNS servers.

The primary DNS server runs on Mac 2, while the backup DNS server runs on Mac 3.

The client-side resolver configuration on Mac 2 contains:

```conf
nameserver 10.7.25.77
nameserver 10.7.2.16
timeout 2
attempts 1
```

This configuration lists both DNS server addresses.

## 4.3 DNS Verification

DNS responses were verified using `dig`.

Representative commands used during testing included:

```bash
dig @10.7.25.77 app.teamX.test +noall +answer
dig @10.7.2.16 app.teamX.test +noall +answer

dig @10.7.25.77 api.teamX.test +noall +answer
dig @10.7.2.16 api.teamX.test +noall +answer
```

Both DNS servers returned the configured application IP address.

The primary DNS service was also stopped during a controlled test. Direct queries to the backup DNS server continued to return the expected DNS response.

However, the test did not conclusively establish that the macOS system resolver automatically selected the backup DNS server in every case. Therefore, the result is reported as successful backup DNS service availability, rather than proven automatic client-side DNS failover.

---

# 5. DNS TTL AND CACHE BEHAVIOR

## 5.1 TTL Configuration

DNS records were configured with a TTL of 60 seconds.

TTL stands for Time To Live. It specifies how long a DNS response may be cached before it should be refreshed.

The TTL mechanism helps reduce repeated DNS queries while allowing DNS record changes to propagate after cached records expire.

## 5.2 TTL Testing

The DNS response TTL was inspected using repeated DNS queries.

The observations showed decreasing TTL values across successive queries. A controlled waiting period was also used to observe the behavior of cached DNS records.

DNS caches were flushed during configuration changes using macOS DNS cache-management commands.

The tests demonstrated TTL-based DNS caching behavior and the importance of cache management during DNS migration.

Exact expiration of every cached record was not independently established.

## 5.3 Importance of TTL During Migration

During a DNS migration, a client may continue using a previously cached DNS record until its TTL expires.

A shorter TTL can reduce the waiting period associated with DNS record changes, but it does not guarantee immediate migration for every client.

This behavior was relevant during the manual migration of the application from Mac 2 to Mac 3.

---

# 6. BACKEND APPLICATION SERVICES

## 6.1 Backend Architecture

Two independent Express.js backend services were configured on Mac 3.

| Backend | Port | Address |
|---|---:|---|
| Backend A | 5001 | 10.7.2.16:5001 |
| Backend B | 5002 | 10.7.2.16:5002 |

The backend services run as separate Node.js processes.

The backend source directories are:

```text
~/Desktop/cn_backends/backend1
~/Desktop/cn_backends/backend2
```

The services can be started using:

```bash
cd ~/Desktop/cn_backends/backend1
node index.js
```

```bash
cd ~/Desktop/cn_backends/backend2
node index.js
```

## 6.2 Backend Response Verification

Both services were tested directly using HTTP requests.

The `/api/status` endpoint returns status information and includes a dynamic response.

The backend status endpoint was configured with:

```http
Cache-Control: no-store
```

This prevents the status response from being stored by ordinary HTTP caches.

Backend availability was verified independently before testing the reverse proxy.

## 6.3 Reverse Proxy and Load Balancing

The primary Nginx server runs on Mac 2.

Its upstream configuration includes the two backend services:

```nginx
upstream teamx_backend {
    server 10.7.2.16:5001 max_fails=1 fail_timeout=10s;
    server 10.7.2.16:5002 max_fails=1 fail_timeout=10s;
}
```

Nginx distributes application requests across the two backend services.

The reverse proxy also forwards request information such as:

- Host
- X-Real-IP
- X-Forwarded-For
- X-Forwarded-Proto

The response headers include information identifying the edge and selected upstream.

The primary edge identifies itself using:

```http
X-Edge: mac2-primary
```

The upstream address is exposed through:

```http
X-Upstream
```

These headers were useful for confirming which edge and backend processed an application request.

## 6.4 Passive Failure Handling

The Nginx upstream configuration uses passive failure handling through `max_fails` and `fail_timeout`.

When a backend request fails, Nginx can attempt another available upstream according to its configuration.

This is not the same as an active health-check system that continuously probes backend services independently of user requests.

---

# 7. HTTPS AND TLS CONFIGURATION

## 7.1 TLS Architecture

HTTPS was configured to secure communication between the client and the reverse proxy.

A local certificate authority was created for the project.

The primary certificate files are stored in:

```text
~/cn-phase2/tls/
```

The relevant files include:

```text
teamX-ca.crt
teamX-ca.key
app.teamX.test.crt
app.teamX.test.key
```

The private CA key was retained locally and was not required to be distributed to clients.

## 7.2 Certificate Details

The certificate authority subject was:

```text
CN=TeamX Local CA
```

The server certificate subject was:

```text
CN=app.teamX.test
```

The server certificate includes the Subject Alternative Names:

```text
app.teamX.test
api.teamX.test
```

The certificate was valid from 24 November 2026 to 26 December 2027.

The CA certificate was trusted in the Mac 2 System Keychain.

## 7.3 TLS Verification

TLS was tested using OpenSSL and HTTPS requests.

The healthy diagnostic output showed:

- TLS version: TLS 1.3
- Cipher suite: TLS_AES_256_GCM_SHA384
- Certificate verification: OK
- Verify return code: 0

These results demonstrated successful certificate verification and an established encrypted connection.

The project used certificate verification rather than relying on the insecure `curl -k` option for its normal trusted HTTPS tests.

## 7.4 HTTPS Request Flow

The normal application request uses port 443.

The primary Nginx edge terminates the client TLS connection and forwards the application request to the backend over the private LAN.

This separates encrypted client-facing communication from the internal backend HTTP connection used in the implementation.

---

# 8. HTTP CACHING AND ETAG VALIDATION

## 8.1 Caching Policy

HTTP caching behavior was tested using response headers.

The backend root response was configured with:

```http
Cache-Control: max-age=60
```

This indicates that the response may be considered fresh for 60 seconds under normal HTTP caching rules.

The `/api/status` endpoint was configured with:

```http
Cache-Control: no-store
```

This is appropriate for dynamic status information that should not be stored by ordinary HTTP caches.

## 8.2 ETag Validation

ETag is an HTTP mechanism used to identify a particular version of a resource.

The client can send an `If-None-Match` request header containing a previously received ETag.

If the resource has not changed, the server can respond with:

```http
HTTP/1.1 304 Not Modified
```

During testing, the conditional request returned HTTP 304 Not Modified with the same ETag.

This demonstrated successful conditional HTTP cache validation.

## 8.3 Caching Limitation

The implementation demonstrates HTTP response caching policies and ETag-based revalidation.

Nginx `proxy_cache` directives were not configured. Therefore, the implementation should not be described as Nginx reverse-proxy caching.

---

# 9. FIREWALL AND BACKEND ISOLATION

## 9.1 Objective

The firewall extension was introduced to prevent unrestricted direct access to the backend services.

The intended security model allows the authorized primary edge server to access Backend A and Backend B, while other inbound connections to the backend ports are restricted.

## 9.2 PF Firewall Configuration

PF, the macOS packet-filtering firewall, was configured on Mac 3.

The relevant firewall rules were:

```conf
pass in quick on en0 inet proto tcp from 10.7.25.77 to 10.7.2.16 port { 5001, 5002 } keep state

block in quick on en0 inet proto tcp from any to 10.7.2.16 port { 5001, 5002 }

block in quick on en0 inet6 proto tcp from any to any port { 5001, 5002 }
```

The rules provide the following behavior:

1. Permit authorized IPv4 TCP traffic from Mac 2 to the backend ports.
2. Block other inbound IPv4 TCP connections to those backend ports.
3. Block inbound IPv6 TCP connections to the specified backend ports.

The PF anchor was configured under:

```text
/etc/pf.anchors/teamx
```

The rules were loaded and inspected using PF commands.

## 9.3 Firewall Verification

Connectivity from the authorized Mac 2 edge to the backend services was verified.

A controlled blocking test was also performed. During the temporary block condition, the connection attempt timed out. The original rules were subsequently restored and normal backend connectivity was verified again.

The macOS Application Firewall was also enabled, and Node.js was explicitly allowed.

## 9.4 Firewall Testing Limitations

An independent third device was not available for a separate unauthorized-source test.

The IPv6 firewall rules were loaded, but active testing from an independent routable IPv6 source was not performed.

Therefore, the report establishes the configured firewall policy and the controlled tests performed, rather than claiming complete validation against every possible unauthorized source.

---

# 10. BACKEND FAILURE AND RECOVERY TESTING

## 10.1 Objective

The purpose of this test was to verify that the application remained accessible when one backend service became unavailable.

The primary Nginx reverse proxy was expected to retry another available backend when a request to the failed backend could not be completed.

## 10.2 Initial Healthy State

Before the failure test, both backend services were checked independently.

Both Backend A and Backend B returned successful responses.

The application was then accessed through the primary Nginx edge, and requests were observed reaching both backend services.

## 10.3 Backend A Failure

Backend A, running on port 5001, was deliberately stopped on Mac 3.

A direct request to Backend A then failed with a connection-refused error.

Backend B, running on port 5002, remained operational and continued returning successful responses.

The primary Nginx edge was then tested using repeated HTTPS requests.

All six requests returned successful HTTP/2 responses from Backend B.

In one observed request, the upstream response header contained both backend addresses:

```text
10.7.2.16:5001, 10.7.2.16:5002
```

This indicated that Nginx attempted the unavailable Backend A and subsequently retried Backend B.

## 10.4 Backend Recovery

Backend A was restarted on Mac 3.

A direct request to Backend A then returned HTTP 200.

Six additional HTTPS requests were sent through the primary Nginx edge.

All six requests succeeded, and the observed responses included both Backend A and Backend B.

## 10.5 Results

| Test condition | Expected behavior | Observed result |
|---|---|---|
| Both backends running | Both services respond | Successful |
| Backend A stopped | Backend B remains available | Successful |
| Six requests during failure | Requests served by available backend | 6/6 successful |
| Backend A restarted | Backend A becomes reachable again | HTTP 200 |
| Six requests after recovery | Both backends available | 6/6 successful |

## 10.6 Conclusion

The test demonstrated that the application remained available during the failure of Backend A because Backend B continued serving requests through the reverse proxy.

After Backend A was restarted, both services became available again.

This validates the configured passive upstream failure handling and recovery behavior. It does not establish continuous active health monitoring.

---

# 11. STANDBY EDGE SERVER AND MANUAL EDGE MIGRATION

## 11.1 Objective

A standby Nginx edge server was configured on Mac 3 to provide an alternate application entry point when the primary edge server on Mac 2 became unavailable.

This extension aimed to demonstrate that the application could continue responding through a second edge system during a primary-edge outage.

## 11.2 Standby Nginx Configuration

The standby Nginx server runs on Mac 3 and listens for HTTPS traffic.

It forwards requests to the backend services hosted locally on the same machine:

```text
Backend A: 127.0.0.1:5001
Backend B: 127.0.0.1:5002
```

The standby edge identifies itself through the response header:

```http
X-Edge: mac3-standby
```

The upstream address is also included in the response for verification.

## 11.3 Standby Edge Verification

The standby edge was tested directly using HTTPS requests and the project's trusted CA certificate.

It successfully returned HTTP 200 responses.

The standby edge was also tested with the application hostname using a forced destination override. This allowed the standby service to be tested without changing the normal DNS records.

## 11.4 Manual DNS Migration

During the migration experiment, DNS records on both DNS servers were temporarily changed to point to the Mac 3 address:

```text
10.7.2.16
```

The client DNS cache was flushed during the controlled migration.

The standby Nginx edge successfully served the application after the DNS change.

The primary Nginx service on Mac 2 was then stopped.

While the primary edge was unavailable, six normal HTTPS requests were tested through the standby edge. All requests returned successful responses.

## 11.5 Restoration of Primary Edge

After the outage test:

1. The primary Nginx service on Mac 2 was restarted.
2. Its listening port was verified.
3. The Nginx configuration test was performed.
4. DNS records on both DNS servers were restored to `10.7.25.77`.
5. HTTPS requests were sent through the restored primary edge.

The final verification showed successful HTTP/2 responses with:

```http
X-Edge: mac2-primary
```

The responses reached both Backend A and Backend B.

## 11.6 Results

| Test | Observed result |
|---|---|
| Standby edge direct request | HTTP 200 |
| Standby edge identity | mac3-standby |
| Manual DNS cutover | Successful |
| Primary Nginx stopped | Confirmed unavailable |
| Requests during primary outage | Six successful responses |
| Primary Nginx restored | Successful |
| DNS restored to primary edge | Successful |
| Final primary-edge requests | HTTP/2 200 |

## 11.7 Conclusion and Limitation

The experiment demonstrated successful manual edge migration and application service continuity during a primary-edge outage.

However, the migration required manual DNS record changes. No automated DNS health-check mechanism or automatic edge failover system was implemented.

The standby edge therefore provides a tested alternate service path, but the project does not claim fully automatic high availability.

---

# 12. NETWORK PACKET ANALYSIS USING WIRESHARK

## 12.1 Objective

Wireshark was used to inspect network communication between Mac 2 and Mac 3.

The goal was to identify the network-level behavior associated with DNS resolution, TCP connection establishment, and TLS negotiation.

## 12.2 Capture Method

Wireshark was installed on Mac 2.

The graphical capture interface encountered BPF permission issues. Therefore, packet capture was performed using `tcpdump` with administrative privileges.

The capture interface was `en0`.

The resulting capture was opened and analyzed using TShark and Wireshark.

## 12.3 Capture Statistics

The capture contained:

| Metric | Observed value |
|---|---:|
| Total frames | 3,859 |
| Total bytes | 965,906 |
| Capture duration | Approximately 44.7 seconds |
| Dropped packets | 0 |
| TShark version | 4.6.10 |

The capture also included unrelated background network traffic.

## 12.4 DNS Packet Analysis

A DNS transaction was identified in the capture.

| Frame | Description |
|---|---|
| 2209 | DNS query from Mac 3 to Mac 2 |
| 2210 | DNS response containing the application IP |

The query originated from `10.7.2.16` and was directed to `10.7.25.77`.

The DNS response returned the configured application address:

```text
10.7.25.77
```

This demonstrated the DNS request-and-response exchange between the two systems.

## 12.5 TCP Packet Analysis

The TCP connection establishment process was identified in the capture.

| Frame | Description |
|---|---|
| 2211 | TCP SYN from Mac 3 to Mac 2 port 443 |
| 2212 | TCP SYN-ACK response from Mac 2 |

These packets demonstrate the beginning of the TCP three-way handshake.

The subsequent ACK completes the normal handshake sequence.

## 12.6 TLS Packet Analysis

TLS handshake traffic was identified in the capture.

| Frame | Description |
|---|---|
| 2222 | TLS ClientHello from Mac 3 |
| 2224 | TLS ServerHello from Mac 2 |

These messages demonstrate the beginning of the TLS negotiation process between the client and the HTTPS edge.

The TLS connection was independently verified through OpenSSL diagnostics.

## 12.7 Backend Traffic

The packet analysis also identified private TCP communication involving the backend services.

For example, traffic to:

```text
10.7.2.16:5002
```

was observed from the primary edge system.

This supports the architecture in which the reverse proxy forwards requests to backend services over the private network.

## 12.8 Capture Limitations

The capture included unrelated background network packets.

Although relevant DNS, TCP, and TLS frames were identified, the capture did not isolate every application HTTP request and response into a dedicated filtered trace.

Therefore, the report uses the identified frames to demonstrate DNS, TCP, and TLS behavior rather than claiming that the entire capture contains only project traffic.

---

# 13. TROUBLESHOOTING FINDINGS

## 13.1 Troubleshooting Methodology

A layer-by-layer troubleshooting methodology was used.

The diagnostic sequence was:

1. DNS resolution.
2. TCP connectivity.
3. TLS verification.
4. HTTP application response.
5. Reverse proxy and backend behavior.

This approach helped identify which component was responsible for a failure instead of treating every application error as a DNS or network issue.

## 13.2 DNS Diagnostics

Both DNS servers were queried directly.

The expected application IP address was returned by both servers:

```text
10.7.25.77
```

The DNS TTL was also checked to observe caching behavior.

## 13.3 TCP Diagnostics

The following services were checked for TCP reachability:

| Destination | Port | Purpose |
|---|---:|---|
| 10.7.25.77 | 443 | Primary HTTPS edge |
| 10.7.2.16 | 5001 | Backend A |
| 10.7.2.16 | 5002 | Backend B |

All three expected service ports were reachable in the healthy-state diagnostic test.

An incorrect port test was also performed:

- Port 443: connection succeeded.
- Port 444: connection refused.

This demonstrated the difference between an active service port and an incorrect destination port.

## 13.4 TLS Diagnostics

TLS verification was performed using OpenSSL.

The healthy diagnostic test showed TLS 1.3, a valid certificate verification result, and the expected cipher suite.

This helped distinguish TLS certificate or negotiation problems from lower-level TCP connectivity problems.

## 13.5 Application Diagnostics

The application was tested using HTTPS requests.

The normal primary edge returned:

```http
HTTP/2 200
X-Edge: mac2-primary
```

The upstream response header was used to identify the backend that processed the request.

The standby edge returned successful responses with:

```http
X-Edge: mac3-standby
```

These response headers provided useful evidence for identifying the active edge and backend.

## 13.6 Forced Destination Override

A forced destination override was performed using `curl --resolve`.

This allowed the application hostname to be directed to the standby edge without modifying the regular DNS records.

The standby edge returned a successful HTTP response.

This demonstrated that the standby server could independently serve the application.

This test was a client-side destination override, not an actual incorrect DNS-record modification.

## 13.7 Temporary HTTP 502 Observation

During one restoration sequence, a temporary HTTP 502 response was observed.

The Nginx error log reported a route-related upstream connection error.

Direct backend connectivity was subsequently verified, and further HTTPS requests succeeded without an identified configuration change.

The exact cause of this temporary failure was not conclusively established.

The incident demonstrated the importance of checking:

- DNS responses.
- TCP connectivity.
- Backend service status.
- Nginx upstream configuration.
- Nginx error logs.
- HTTP response headers.

A single HTTP 502 response does not by itself identify the root cause.

## 13.8 Troubleshooting Summary

The experiments reinforced the importance of following a structured diagnostic process.

| Layer / Component | Diagnostic tool | Purpose |
|---|---|---|
| DNS | `dig` | Verify hostname resolution |
| TCP | `nc` | Check destination port connectivity |
| TLS | `openssl s_client` | Verify certificate and TLS negotiation |
| HTTP | `curl` | Inspect application responses |
| Reverse proxy | Nginx logs and headers | Identify upstream behavior |
| Packet level | Wireshark / TShark | Inspect DNS, TCP, and TLS exchanges |

---

# 14. RESILIENCE TEST SUMMARY

The following table consolidates the major Phase 2 tests.

| S. No. | Test | Expected behavior | Observed result | Status |
|---|---|---|---|---|
| 1 | Primary DNS query | Resolve application hostname | Correct IP returned | Verified |
| 2 | Backup DNS query | Resolve application hostname | Correct IP returned | Verified |
| 3 | Primary DNS outage | Backup DNS remains responsive | Direct backup query succeeded | Verified |
| 4 | TTL observation | TTL decreases in responses | Decreasing values observed | Verified |
| 5 | Firewall authorized access | Edge can access backends | Successful | Verified |
| 6 | Firewall blocking test | Blocked connection fails | Connection timeout observed | Verified |
| 7 | Backend A failure | Backend B continues serving | 6/6 requests successful | Verified |
| 8 | Backend A recovery | Backend A becomes available | Direct HTTP 200 | Verified |
| 9 | Backend recovery requests | Both backends serve traffic | 6/6 requests successful | Verified |
| 10 | Standby edge | Standby serves application | HTTP 200 | Verified |
| 11 | Primary edge outage | Standby serves requests | 6/6 requests successful | Verified |
| 12 | Primary edge restoration | Primary resumes service | HTTP/2 200 | Verified |
| 13 | Wrong destination port | Incorrect port unavailable | Port 444 refused | Verified |
| 14 | TLS verification | Certificate is trusted | Verify return code 0 | Verified |
| 15 | Wireshark packet analysis | Identify network exchanges | DNS, TCP and TLS frames identified | Verified |

**Interpretation:** The table records the tests that were actually performed. It does not imply that all possible failure conditions or automatic failover mechanisms were tested.

---

# 15. LEARNING SUMMARY

## 15.1 Backup DNS and TTL

Implementing a secondary DNS server demonstrated how redundant name-resolution infrastructure can improve service availability. Direct queries to the backup resolver succeeded during primary DNS downtime. TTL observations clarified how DNS caching affects record changes and why cache flushing is useful during controlled migration. The experiment also highlighted the difference between configuring multiple DNS servers and proving automatic resolver selection by the operating system.

## 15.2 Firewall and Service Isolation

Configuring PF rules provided practical experience with restricting backend access to an authorized edge server. The tests demonstrated the difference between application availability and network-level access control. The project also highlighted the importance of rule ordering, stateful firewall behavior, interface selection, and testing both allowed and blocked traffic. The remaining independent-device and routable IPv6 tests were identified as areas for further validation.

## 15.3 Backend Failure and Recovery

Stopping Backend A demonstrated how a reverse proxy can retry another upstream when a backend becomes unavailable. The successful responses from Backend B showed that the application could continue operating despite the failure of one backend. Restarting Backend A and observing successful responses from both services showed the importance of recovery verification, not just failure detection. The experiment also provided practical understanding of passive failure handling in Nginx.

## 15.4 Standby Edge and Migration

Configuring a second Nginx edge server demonstrated how an application can remain accessible when its primary edge is unavailable. Manual DNS migration provided practical experience with high availability, DNS changes, and service restoration. The test also showed that manual migration is different from automated failover and that DNS caching must be considered during an edge transition.

## 15.5 HTTPS and TLS

Configuring a local certificate authority and trusted server certificate provided practical understanding of HTTPS and certificate validation. The successful TLS 1.3 connection demonstrated how an encrypted client-to-edge connection can be established using a trusted certificate. Certificate subject names, Subject Alternative Names, certificate validity, and trust configuration were important parts of the process.

## 15.6 Caching and HTTP Validation

Testing Cache-Control and ETag headers demonstrated how HTTP caching can reduce unnecessary data transfer and allow clients to validate whether a resource has changed. The HTTP 304 response showed that a client can reuse a previously obtained representation when the server indicates that it remains unchanged. The distinction between application-level HTTP caching and Nginx proxy caching was also clarified.

## 15.7 Packet Analysis and Troubleshooting

Wireshark and command-line diagnostics connected theoretical networking concepts to real packet exchanges. Examining DNS queries, TCP handshakes, and TLS negotiation helped establish a systematic troubleshooting method. The project demonstrated that successful application communication depends on multiple layers working together and that diagnosing a failure requires checking each relevant layer.

---

# 16. LIMITATIONS AND FUTURE IMPROVEMENTS

## 16.1 Current Limitations

The project successfully demonstrated several resilience mechanisms, but some capabilities remain outside the implemented scope.

1. **Automatic DNS Failover:** Both DNS servers were configured and tested directly, but automatic system-level selection of the backup resolver was not conclusively established.

2. **Automated Edge Failover:** Migration to the standby edge required manual DNS changes. No automated DNS health monitoring or automatic cutover was implemented.

3. **Active Backend Health Checks:** Nginx used passive failure handling through its upstream configuration. Continuous active health monitoring was not implemented.

4. **Independent Unauthorized-Source Testing:** An independent third device was not available to validate backend access restrictions from a separate unauthorized host.

5. **Routable IPv6 Firewall Testing:** IPv6 blocking rules were loaded, but active testing from an independent routable IPv6 source was not performed.

6. **Exact DNS Cache Expiration:** TTL countdown behavior was observed, but exact expiration of every cached record was not independently established.

7. **Dedicated HTTP Packet Trace:** The packet capture contained background traffic. A fully isolated capture showing only the project application request and response was not produced.

8. **Nginx Proxy Caching:** HTTP cache headers and ETag validation were implemented, but Nginx `proxy_cache` was not configured.

## 16.2 Future Improvements

The following improvements could be implemented in a future version:

- Introduce automated DNS health monitoring.
- Configure automated edge selection or failover.
- Implement active backend health checks.
- Add monitoring and logging for backend response times.
- Perform firewall tests using an independent third device.
- Validate IPv6 firewall behavior using a routable IPv6 test environment.
- Capture isolated DNS, TCP, TLS, and HTTP application traffic.
- Introduce automated service restart and recovery mechanisms.
- Add centralized monitoring for both edge systems and backend services.
- Develop a documented rollback procedure for DNS and edge migration.

These improvements would make the platform more suitable for demonstrating automated high availability and operational resilience.

---

# 17. CONCLUSION

Phase 2 extended the Private Network Service Platform from a normally functioning private application into a system with tested resilience, service isolation, and recovery mechanisms.

The project introduced a backup DNS resolver, TTL-based DNS testing, PF firewall rules, backend failure recovery, and a standby Nginx edge server. Controlled experiments demonstrated successful backend failover through the configured reverse proxy, successful recovery after restarting the failed backend, and continued application availability through a standby edge during primary-edge downtime.

TLS verification confirmed a valid HTTPS connection, while HTTP cache validation demonstrated ETag-based conditional requests. Wireshark analysis identified DNS transactions, TCP connection establishment, and TLS handshake messages between the two systems.

The final verification confirmed that the restored primary edge returned successful HTTP/2 responses and distributed requests across both backend services.

Although automatic edge migration and some additional security and DNS validation tests remain future improvements, the implemented system successfully demonstrates important networking concepts involving redundancy, availability, security, reverse proxying, packet analysis, and systematic troubleshooting.

Overall, Phase 2 provided practical experience in designing, configuring, testing, and diagnosing a multi-component private network service environment.

---

# 18. EVIDENCE AND PROJECT ARTIFACTS

All collected evidence is maintained in the following directory:

```text
CNPhase_2/
└── Evidence/
    ├── DNS/
    ├── Wireshark/
    ├── Caching/
    ├── Failover/
    ├── Firewall/
    └── Showcase/
```

## 18.1 Evidence Inventory

| Category | Evidence file | Purpose |
|---|---|---|
| DNS | `DNS/TeamX_DNS_TTL_Evidence.txt` | DNS TTL and response observations |
| Wireshark | `Wireshark/TeamX_CN_Capture.pcap` | Original packet capture |
| Wireshark | `Wireshark/TeamX_Wireshark_Evidence.txt` | Packet analysis and frame information |
| Caching | `Caching/TeamX_Caching_Evidence.txt` | Cache-Control and ETag test |
| Firewall | `Firewall/TeamX_Firewall_Evidence.txt` | PF firewall configuration and tests |
| Failover | `Failover/TeamX_Healthy_Layer_Diagnostics.txt` | Healthy DNS, TCP, TLS and HTTP diagnostics |
| Failover | `Failover/TeamX_Backend_Failure_Recovery_Evidence.txt` | Backend A failure and recovery |
| Failover | `Failover/TeamX_Edge_Migration_Evidence_20261125_030935.txt` | Primary and standby edge migration |
| Showcase | `Showcase/teamX_mac2_showcase.sh` | Mac 2 demonstration script |
| Showcase | `Showcase/TeamX_Showcase_20261125_012644.txt` | Mac 2 showcase output |
| Showcase | `Showcase/teamX_mac3_showcase.sh` | Mac 3 demonstration script |
| Showcase | `Showcase/TeamX_Mac3_Showcase_20261125_012741.txt` | Mac 3 showcase output |

The evidence directory contained 12 files with an approximate total size of 1 MB at the time of inventory.

## 18.2 Configuration and Source Code Locations

The main project configuration and source locations include:

**Mac 2:**

```text
~/cn-phase2/tls/
~/CNPhase_2/Evidence/
```

Primary Nginx configuration:

```text
/opt/homebrew/etc/nginx/servers/teamX.conf
```

**Mac 3:**

```text
~/Desktop/cn_backends/backend1/
~/Desktop/cn_backends/backend2/
~/cn-phase2/tls/
```

Standby Nginx configuration:

```text
/opt/homebrew/etc/nginx/servers/teamX-standby.conf
```

PF anchor:

```text
/etc/pf.anchors/teamx
```

The project submission should include the required configuration files and backend source code alongside the evidence directory. Private TLS keys should not be distributed unnecessarily.

---

# APPENDIX A — IMPORTANT NETWORK ADDRESSES AND PORTS

| Service | Host | Port |
|---|---|---:|
| Primary DNS | Mac 2 | 53 |
| Backup DNS | Mac 3 | 53 |
| Primary Nginx HTTPS | Mac 2 | 443 |
| Primary Nginx HTTP redirect | Mac 2 | 80 |
| Backend A | Mac 3 | 5001 |
| Backend B | Mac 3 | 5002 |
| Standby Nginx HTTPS | Mac 3 | 443 |

# APPENDIX B — IMPORTANT VERIFICATION COMMANDS

The following commands were used or represent the relevant diagnostic checks performed during the project.

**DNS verification:**

```bash
dig @10.7.25.77 app.teamX.test +noall +answer
dig @10.7.2.16 app.teamX.test +noall +answer
```

**TCP connectivity:**

```bash
nc -vz 10.7.25.77 443
nc -vz 10.7.2.16 5001
nc -vz 10.7.2.16 5002
```

**TLS verification:**

```bash
openssl s_client -connect app.teamX.test:443 -servername app.teamX.test
```

**HTTP application verification:**

```bash
curl -i https://app.teamX.test/
```

**Nginx configuration verification:**

```bash
sudo nginx -t
```

**PF rule inspection:**

```bash
sudo pfctl -a com.apple/teamx -sr
```

**Packet capture:**

```bash
sudo tcpdump -i en0 -nn -s 0 -w ~/Desktop/TeamX_CN_Capture.pcap
```

These commands represent the major verification methods used in the implementation. They are included as a reference for understanding and reproducing the relevant tests.

# APPENDIX C — FINAL PROJECT STATUS

| Component | Status |
|---|---|
| Private LAN connectivity | Implemented |
| Primary DNS | Implemented and tested |
| Backup DNS | Implemented and directly tested |
| TTL configuration | Implemented and observed |
| Backend A and B | Implemented and tested |
| Primary reverse proxy | Implemented and tested |
| HTTPS and TLS | Implemented and verified |
| HTTP caching and ETag | Implemented and tested |
| Firewall restrictions | Configured and controlled tests performed |
| Backend failure and recovery | Tested successfully |
| Standby edge | Implemented and tested |
| Manual edge migration | Tested successfully |
| Wireshark analysis | Completed |
| Automated edge failover | Not implemented |
| Active backend health checks | Not implemented |
| Faculty-injected troubleshooting challenge | Pending |

**End of Report**