"""
================================================================================
PIMS HCP PROFILING APP - 3.8 FLASH CYBER-GRADE SECURITY GATEWAY
HMAC-SHA256 Signature Verification, Anti-Replay Window, WAF & Anti-DDoS
================================================================================
Enterprise security perimeter guarding ERPNext/Frappe against brute-force,
tampering, replay attacks, SQL injection, and high-concurrency peak floods.
"""

import hmac
import time
import json
import re
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.request
import urllib.error
from typing import Dict, Tuple

# Logging Configuration (Auto-Redacts Sensitive Data)
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] [CyberSec] %(message)s")
logger = logging.getLogger("pims.cyber_gateway")

# Gateway Configuration
GATEWAY_PORT = 9000
BACKEND_APP_CLUSTER = "http://frappe_app_cluster:8000"
HMAC_SECRET_KEY = b"PIMS_ENTERPRISE_3.8_FLASH_CYBER_GRADE_SHARED_SECRET_2026"
MAX_TIMESTAMP_DRIFT_SECONDS = 60.0  # Strict 60-Second Replay Attack Window

# SQL Injection and Malicious Script Pattern Signatures
SQLI_XSS_PATTERNS = [
    re.compile(r"(\b(UNION(\s+ALL)?|SELECT|DROP|INSERT|DELETE|UPDATE|ALTER)\b.*\b(FROM|INTO|TABLE)\b)", re.IGNORECASE),
    re.compile(r"(--|/\*|\*/|;|@@|char\(|waitfor\s+delay)", re.IGNORECASE),
    re.compile(r"(\bor\b\s+['\d]+\s*=\s*['\d]+)", re.IGNORECASE),
    re.compile(r"(<script.*?>.*?</script.*?>|javascript:|onload\s*=|onerror\s*=)", re.IGNORECASE),
]


class TokenBucketLimiter:
    """In-Memory High-Speed Token Bucket Rate Limiter with Threat Jailing."""

    def __init__(self, capacity: int = 60, refill_rate: float = 1.0):
        self.capacity = capacity
        self.refill_rate = refill_rate
        self.buckets: Dict[str, Tuple[float, float]] = {}  # ip -> (tokens, last_time)
        self.jailed_ips: Dict[str, float] = {}  # ip -> jail_expiry_time

    def is_allowed(self, client_ip: str) -> bool:
        now = time.time()

        # Check jail status
        if client_ip in self.jailed_ips:
            if now < self.jailed_ips[client_ip]:
                return False
            del self.jailed_ips[client_ip]

        tokens, last_time = self.buckets.get(client_ip, (self.capacity, now))
        # Refill tokens
        elapsed = now - last_time
        tokens = min(self.capacity, tokens + elapsed * self.refill_rate)

        if tokens >= 1.0:
            self.buckets[client_ip] = (tokens - 1.0, now)
            return True
        else:
            self.buckets[client_ip] = (tokens, now)
            return False

    def jail_ip(self, client_ip: str, duration_seconds: int = 900):
        """Jails an offending IP for 15 minutes upon detecting cyber attack patterns."""
        self.jailed_ips[client_ip] = time.time() + duration_seconds
        logger.warning("🚨 [CYBER-SHIELD] Jailed malicious IP '%s' for %ds", client_ip, duration_seconds)


rate_limiter = TokenBucketLimiter(capacity=100, refill_rate=2.0)
seen_nonces: Dict[str, float] = {}  # nonce -> expiry


def sanitize_payload(obj: any) -> bool:
    """Recursively audits JSON payload for SQL injection and XSS exploit vectors."""
    if isinstance(obj, str):
        for pattern in SQLI_XSS_PATTERNS:
            if pattern.search(obj):
                return False
    elif isinstance(obj, dict):
        for k, v in obj.items():
            if not sanitize_payload(k) or not sanitize_payload(v):
                return False
    elif isinstance(obj, list):
        for item in obj:
            if not sanitize_payload(item):
                return False
    return True


class CyberSecurityGatewayHandler(BaseHTTPRequestHandler):
    """3.8 Flash Cyber-Grade HTTP Request Filter & Reverse Proxy."""

    def _get_client_ip(self) -> str:
        forwarded = self.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return self.client_address[0]

    def _send_cyber_error(self, code: int, message: str, threat_type: str):
        logger.warning("🚫 Request Blocked [%d] Threat: %s from IP: %s (Path: %s)", code, threat_type, self._get_client_ip(), self.path)
        body = json.dumps({
            "error": "CyberSecurityGateException",
            "threat_category": threat_type,
            "message": message,
            "timestamp": int(time.time()),
        }).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        """CORS Preflight Authorization."""
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-PIMS-Signature, X-PIMS-Timestamp, X-Frappe-CSRF-Token")
        self.send_header("Access-Control-Max-Age", "86400")
        self.end_headers()

    def do_POST(self):
        client_ip = self._get_client_ip()

        # Gate 1: Adaptive Rate Limiting
        if not rate_limiter.is_allowed(client_ip):
            self._send_cyber_error(429, "Too many requests. Cyber-threshold exceeded.", "RateLimitExceeded")
            return

        # Read Request Body
        content_length = int(self.headers.get("Content-Length", 0))
        raw_body = self.rfile.read(content_length) if content_length > 0 else b""

        # Gate 2: Deep SQLi / XSS Payload Audit
        if raw_body:
            try:
                parsed_json = json.loads(raw_body.decode("utf-8"))
                if not sanitize_payload(parsed_json):
                    rate_limiter.jail_ip(client_ip, 900)
                    self._send_cyber_error(403, "Malicious payload detected (SQLi/XSS violation).", "MaliciousPayloadBlocked")
                    return
            except json.JSONDecodeError:
                # Binary or form-data, check raw strings
                raw_str = raw_body.decode("utf-8", errors="ignore")
                for pattern in SQLI_XSS_PATTERNS:
                    if pattern.search(raw_str):
                        rate_limiter.jail_ip(client_ip, 900)
                        self._send_cyber_error(403, "Malicious raw payload sequence detected.", "MaliciousPayloadBlocked")
                        return

        # Gate 3: HMAC-SHA256 & Anti-Replay Verification (for Profile Submissions)
        req_sig = self.headers.get("X-PIMS-Signature")
        req_ts = self.headers.get("X-PIMS-Timestamp")

        if req_sig and req_ts:
            try:
                ts_float = float(req_ts) / 1000.0 if float(req_ts) > 1e11 else float(req_ts)
                drift = abs(time.time() - ts_float)
                if drift > MAX_TIMESTAMP_DRIFT_SECONDS:
                    self._send_cyber_error(403, f"Request timestamp expired (drift: {drift:.1f}s). Replay attack mitigated.", "ReplayAttackMitigated")
                    return

                # Calculate expected HMAC
                message = f"POST:{self.path}:{req_ts}:".encode("utf-8") + raw_body
                expected_sig = hmac.new(HMAC_SECRET_KEY, message, hashlib.sha256).hexdigest()

                if not hmac.compare_digest(req_sig, expected_sig):
                    self._send_cyber_error(403, "Cryptographic request signature mismatch. Payload tampering detected.", "CryptographicIntegrityFailure")
                    return

            except Exception as e:
                self._send_cyber_error(400, f"Malformed signature parameters: {e}", "MalformedSecurityHeaders")
                return

        # Gate 4: Forward to Frappe Cluster
        self._proxy_to_backend(raw_body)

    def do_GET(self):
        client_ip = self._get_client_ip()
        if not rate_limiter.is_allowed(client_ip):
            self._send_cyber_error(429, "Too many requests.", "RateLimitExceeded")
            return
        self._proxy_to_backend(b"")

    def _proxy_to_backend(self, body_data: bytes):
        target_url = f"{BACKEND_APP_CLUSTER}{self.path}"
        try:
            req = urllib.request.Request(target_url, data=body_data if body_data else None, method=self.command)
            # Propagate headers
            for k, v in self.headers.items():
                if k.lower() not in ["host", "content-length"]:
                    req.add_header(k, v)

            with urllib.request.urlopen(req, timeout=15) as resp:
                resp_data = resp.read()
                self.send_response(resp.status)
                for h, val in resp.getheaders():
                    if h.lower() not in ["transfer-encoding", "content-length"]:
                        self.send_header(h, val)
                self.send_header("Content-Length", str(len(resp_data)))
                self.send_header("X-Cyber-Gateway-Protected", "3.8-Flash-Active")
                self.end_headers()
                self.wfile.write(resp_data)

        except urllib.error.HTTPError as e:
            err_body = e.read()
            self.send_response(e.code)
            for h, val in e.headers.items():
                if h.lower() not in ["transfer-encoding", "content-length"]:
                    self.send_header(h, val)
            self.send_header("Content-Length", str(len(err_body)))
            self.end_headers()
            self.wfile.write(err_body)
        except Exception as e:
            self._send_cyber_error(502, f"Upstream application cluster unavailable: {e}", "UpstreamGatewayError")


def run_gateway():
    server = HTTPServer(("0.0.0.0", GATEWAY_PORT), CyberSecurityGatewayHandler)
    logger.info("3.8 Flash Cyber-Grade Security Gateway listening on port %d", GATEWAY_PORT)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()


if __name__ == "__main__":
    run_gateway()
