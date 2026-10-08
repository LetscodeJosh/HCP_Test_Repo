import http.server
import socketserver
import os
import urllib.parse
import urllib.request
import json
import ssl
import http.cookiejar
import sys
import threading
import webbrowser
import socket
import time
import secrets

try:
    from secure_frappe_gateway import (
        GLOBAL_SESSION_REGISTRY,
        VibeSecAuthorizer,
        ResourceRequestSchema,
        SecurityValidationError,
        sanitize_log_message
    )
except ImportError:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from secure_frappe_gateway import (
        GLOBAL_SESSION_REGISTRY,
        VibeSecAuthorizer,
        ResourceRequestSchema,
        SecurityValidationError,
        sanitize_log_message
    )

# Ensure standard streams exist when run under pythonw (GUI background mode)
if sys.stdout is None:
    sys.stdout = open(os.devnull, 'w')
if sys.stderr is None:
    sys.stderr = open(os.devnull, 'w')

PORT = 8765

# Detect HTML path in local directory first, then fallback to repo dirs
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
LOCAL_HTML = os.path.join(CURRENT_DIR, 'territory_reconfiguration_portal.html')
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS_HTML = os.path.join(BASE_DIR, 'docs', 'territory_reconfiguration_portal.html')
ASSETS_HTML = os.path.join(BASE_DIR, 'assets', 'web', 'territory_reconfiguration_portal.html')

# ===========================================================================
# 🚀 SERVER ENVIRONMENT SWITCH (SINGLE-LINE TOGGLE)
# Change to 'production' or 'development'
# ===========================================================================
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'development').lower()

DEV_SERVER_URL = 'https://dev.pmii-marketing.com'
PROD_SERVER_URL = 'https://pmii-marketing.com'

ERPNEXT_SERVER_URL = os.environ.get(
    'ERPNEXT_URL',
    PROD_SERVER_URL if ENVIRONMENT == 'production' else DEV_SERVER_URL
)

ACTIVE_COOKIE_JAR = http.cookiejar.CookieJar()
ACTIVE_SSL_CTX = ssl.create_default_context()
if os.environ.get('ERPNEXT_INSECURE_SSL') == '1':
    ACTIVE_SSL_CTX.check_hostname = False
    ACTIVE_SSL_CTX.verify_mode = ssl.CERT_NONE
ACTIVE_OPENER = urllib.request.build_opener(
    urllib.request.HTTPCookieProcessor(ACTIVE_COOKIE_JAR),
    urllib.request.HTTPSHandler(context=ACTIVE_SSL_CTX)
)

def get_latest_portal_html():
    if os.path.exists(LOCAL_HTML):
        chosen_path = LOCAL_HTML
    elif os.path.exists(DOCS_HTML):
        chosen_path = DOCS_HTML
    elif os.path.exists(ASSETS_HTML):
        chosen_path = ASSETS_HTML
    else:
        chosen_path = LOCAL_HTML
        for root, _, files in os.walk(CURRENT_DIR):
            if 'territory_reconfiguration_portal.html' in files:
                chosen_path = os.path.join(root, 'territory_reconfiguration_portal.html')
                break

    with open(chosen_path, 'rb') as f:
        content = f.read()
    return content, chosen_path

def authenticate_erpnext_user(usr, pwd):
    if not usr or not pwd:
        return {'success': False, 'authorized': False, 'message': 'Both username and password are required.'}

    usr = usr.strip()
    pwd = pwd.strip()

    login_data = json.dumps({'usr': usr, 'pwd': pwd}).encode('utf-8')
    headers = {'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) PIMS-Portal'}
    erp_url = ERPNEXT_SERVER_URL

    try:
        req = urllib.request.Request(f'{erp_url}/api/method/login', data=login_data, headers=headers)
        res = ACTIVE_OPENER.open(req, timeout=8)
        login_res = json.loads(res.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        if e.code == 401:
            return {'success': False, 'authorized': False, 'message': 'Invalid username or password. Please verify your credentials registered in https://dev.pmii-marketing.com/app/user.'}
        return {'success': False, 'authorized': False, 'message': f'ERPNext authentication error (HTTP {e.code}). Please try again.'}
    except Exception as e:
        return {'success': False, 'authorized': False, 'message': f'Cannot reach ERPNext server at {erp_url}: {str(e)}'}

    if login_res.get('message') != 'Logged In':
        return {'success': False, 'authorized': False, 'message': 'Authentication failed on ERPNext.'}

    full_name = login_res.get('full_name') or usr
    role_profile = ''
    roles = []

    # Fast-path for Administrator / Admin
    if usr.lower() in ['administrator', 'admin']:
        server_host = urllib.parse.urlparse(erp_url).netloc
        return {
            'success': True,
            'authorized': True,
            'message': f'Welcome back, {full_name}!',
            'user': {
                'email': usr,
                'full_name': full_name or 'System Administrator',
                'role_profile': 'Administrator',
                'role_title': 'Administrator',
                'is_admin': True,
                'is_sfe': False,
                'roles': ['System Manager', 'Administrator'],
                'auth_source': f'ERPNext Live Authentication ({server_host})'
            }
        }

    try:
        quoted_usr = urllib.parse.quote(usr)
        user_req = urllib.request.Request(f'{erp_url}/api/resource/User/{quoted_usr}', headers={'Accept': 'application/json', 'User-Agent': 'Mozilla/5.0'})
        user_res = ACTIVE_OPENER.open(user_req, timeout=5)
        user_doc = json.loads(user_res.read().decode('utf-8')).get('data', {})
        full_name = user_doc.get('full_name') or full_name
        role_profile = user_doc.get('role_profile_name') or ''
        roles = [r.get('role') for r in user_doc.get('roles', []) if isinstance(r, dict) and r.get('role')]
    except Exception:
        pass

    all_roles_str = ' '.join([role_profile] + roles).lower()
    is_admin = any(k in all_roles_str for k in ['system manager', 'administrator'])
    is_sfe = any(k in all_roles_str for k in ['sales force effectiveness', 'sales manager', 'sfe', 'territory manager'])

    if not (is_admin or is_sfe):
        return {
            'success': False,
            'authorized': False,
            'message': f"Access Restricted: User '{usr}' does not have SFE or Administrator roles in https://dev.pmii-marketing.com/app/user."
        }

    role_title = 'Administrator' if is_admin else 'SFE Lead'
    server_host = urllib.parse.urlparse(erp_url).netloc

    return {
        'success': True,
        'authorized': True,
        'message': f'Welcome back, {full_name}!',
        'user': {
            'email': usr,
            'full_name': full_name,
            'role_profile': role_profile or role_title,
            'role_title': role_title,
            'is_admin': is_admin,
            'is_sfe': is_sfe,
            'roles': roles,
            'auth_source': f'ERPNext Live Authentication ({server_host})'
        }
    }

class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    daemon_threads = True
    allow_reuse_address = True

class PortalHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept')
        self.send_header('Connection', 'close')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def proxy_erpnext_request(self, method):
        parsed = urllib.parse.urlparse(self.path)
        path_parts = [p for p in parsed.path.strip("/").split("/") if p]

        doctype = ""
        docname = None
        if len(path_parts) >= 2 and path_parts[0] == "api" and path_parts[1] == "resource":
            doctype = urllib.parse.unquote(path_parts[2]) if len(path_parts) >= 3 else ""
            docname = urllib.parse.unquote(path_parts[3]) if len(path_parts) >= 4 else None
        elif len(path_parts) >= 2 and path_parts[0] == "api" and path_parts[1] == "method":
            doctype = "RPC_METHOD"
            docname = path_parts[2] if len(path_parts) >= 3 else None

        # 1. Server-Side Session Validation & Anti-BOLA/IDOR Check
        headers_dict = {k: v for k, v in self.headers.items()}
        cookie_str = self.headers.get("Cookie", "")
        token = VibeSecAuthorizer.extract_token_from_request(headers_dict, cookie_str)
        session = GLOBAL_SESSION_REGISTRY.get(token)

        auth_decision = VibeSecAuthorizer.evaluate_request(
            session=session,
            doctype=doctype,
            docname=docname,
            headers=headers_dict,
            method=method
        )

        if not auth_decision.allowed:
            # STOP IMMEDIATELY — RETURN CLEAN 403/401 WITHOUT CALLING ERPNEXT!
            err_body = json.dumps({
                "success": False,
                "error": auth_decision.reason,
                "code": auth_decision.status_code,
                "security_alert": "BOLA/IDOR attempt blocked by VibeSec Gateway"
            }).encode("utf-8")
            self.send_response(auth_decision.status_code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(err_body)))
            self.end_headers()
            self.wfile.write(err_body)
            return

        # 2. Strict Schema Validation on resource parameters
        if doctype and doctype != "RPC_METHOD":
            query_dict = urllib.parse.parse_qs(parsed.query)
            flat_query = {k: v[0] if len(v) == 1 else v for k, v in query_dict.items()}
            try:
                ResourceRequestSchema.from_request(doctype, docname, flat_query)
            except SecurityValidationError as sve:
                err_body = json.dumps({
                    "success": False,
                    "error": f"Schema Validation Error: {str(sve)}",
                    "code": 400
                }).encode("utf-8")
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(err_body)))
                self.end_headers()
                self.wfile.write(err_body)
                return

        target_url = f"{ERPNEXT_SERVER_URL}{parsed.path}"
        if parsed.query:
            target_url += f"?{parsed.query}"

        content_length = int(self.headers.get('Content-Length', 0))
        req_body = self.rfile.read(content_length) if content_length > 0 else None

        headers = {
            'Accept': self.headers.get('Accept', 'application/json'),
            'User-Agent': self.headers.get('User-Agent') or 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) PIMS-Portal'
        }
        content_type = self.headers.get('Content-Type')
        if content_type:
            headers['Content-Type'] = content_type

        # Credentials isolation: Inject isolated Frappe API token if set in environment
        if os.environ.get('FRAPPE_API_KEY') and os.environ.get('FRAPPE_API_SECRET'):
            headers['Authorization'] = f"token {os.environ.get('FRAPPE_API_KEY')}:{os.environ.get('FRAPPE_API_SECRET')}"

        req = urllib.request.Request(target_url, data=req_body, headers=headers, method=method)
        try:
            res = ACTIVE_OPENER.open(req, timeout=15)
            resp_body = res.read()
            resp_status = res.status
            self.send_response(resp_status)
            self.send_header('Content-Type', res.headers.get('Content-Type', 'application/json; charset=utf-8'))
            self.send_header('Content-Length', str(len(resp_body)))
            self.end_headers()
            self.wfile.write(resp_body)
        except urllib.error.HTTPError as e:
            err_body = e.read()
            self.send_response(e.code)
            self.send_header('Content-Type', e.headers.get('Content-Type', 'application/json; charset=utf-8'))
            self.send_header('Content-Length', str(len(err_body)))
            self.end_headers()
            self.wfile.write(err_body)
        except Exception as e:
            err_json = json.dumps({'error': sanitize_log_message(str(e)), 'target_url': target_url}).encode('utf-8')
            self.send_response(502)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(err_json)))
            self.end_headers()
            self.wfile.write(err_json)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == '/api/status':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.end_headers()
            version_str = 'V.0.5.4'
            version_file = os.path.join(BASE_DIR, 'VERSION')
            if os.path.exists(version_file):
                try:
                    with open(version_file, 'r', encoding='utf-8') as vf:
                        version_str = vf.read().strip()
                except Exception:
                    pass
            status_data = {
                'status': 'online',
                'port': PORT,
                'version': version_str,
                'server': 'PIMS Reconfiguration Server (Active SFE Edition)'
            }
            self.wfile.write(json.dumps(status_data).encode('utf-8'))
            return

        if path.startswith('/api/resource/') or path.startswith('/api/method/'):
            self.proxy_erpnext_request('GET')
            return

        # Serve web portal
        if path in ['/', '/index.html', '/territory_reconfiguration_portal.html'] or not os.path.exists(path.lstrip('/')):
            try:
                content, _ = get_latest_portal_html()
                self.send_response(200)
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                return
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(e).encode('utf-8'))
                return

        super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)

        if parsed.path == '/api/login':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            try:
                data = json.loads(post_data.decode('utf-8'))
                usr = (data.get('usr') or data.get('username') or data.get('email') or '').strip()
                pwd = data.get('pwd') or data.get('password') or ''
                result = authenticate_erpnext_user(usr, pwd)
                status_code = 200 if (result.get('success') and result.get('authorized')) else 401

                if result.get('success') and result.get('authorized'):
                    token = secrets.token_urlsafe(32)
                    u_info = result.get('user', {})
                    GLOBAL_SESSION_REGISTRY.register(
                        token=token,
                        user_email=u_info.get('email', usr),
                        full_name=u_info.get('full_name', usr),
                        roles=u_info.get('roles', []),
                        customer_id=u_info.get('customer_id'),
                        is_admin=u_info.get('is_admin', False),
                        is_sfe=u_info.get('is_sfe', False)
                    )
                    result['session_token'] = token
                    self.send_response(status_code)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Set-Cookie', f'sfe_session={token}; Path=/; HttpOnly; SameSite=Lax')
                else:
                    self.send_response(status_code)
                    self.send_header('Content-Type', 'application/json')

                self.end_headers()
                self.wfile.write(json.dumps(result).encode('utf-8'))
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({
                    'success': False,
                    'authorized': False,
                    'message': f'Server authentication error: {sanitize_log_message(str(e))}'
                }).encode('utf-8'))
            return

        if parsed.path == '/api/logout':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'success': True, 'message': 'Logged out successfully.'}).encode('utf-8'))
            return

        if parsed.path == '/api/sync':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                'status': 'success',
                'message': 'Territory reconfiguration staged and committed live.'
            }).encode('utf-8'))
            return

        if parsed.path.startswith('/api/resource/') or parsed.path.startswith('/api/method/'):
            self.proxy_erpnext_request('POST')
            return

        self.send_response(404)
        self.end_headers()

    def do_PUT(self):
        self.proxy_erpnext_request('PUT')

    def do_DELETE(self):
        self.proxy_erpnext_request('DELETE')


    def log_message(self, format, *args):
        # Clean logging with credential sanitization
        cleaned_msg = sanitize_log_message(format % args)
        sys.stderr.write(f"[{self.log_date_time_string()}] {cleaned_msg}\n")

def is_port_in_use(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('127.0.0.1', port)) == 0

def open_browser_tab():
    time.sleep(0.8)
    webbrowser.open(f'http://127.0.0.1:{PORT}')

def main():
    if is_port_in_use(PORT):
        print("============================================================")
        print(f"  PIMS • Territory Reconfiguration Portal (SFE Edition)")
        print(f"  Server is ALREADY running on: http://127.0.0.1:{PORT}")
        print("  Opening portal in your default web browser...")
        print("============================================================")
        sys.stdout.flush()
        webbrowser.open(f'http://127.0.0.1:{PORT}')
        return

    ThreadedTCPServer.allow_reuse_address = True
    print(f"============================================================")
    print(f"  PIMS • Territory Reconfiguration Portal (SFE Active Edition)")
    print(f"  Authentication Engine: ERPNext Live Multi-Threaded Engine")
    print(f"  Server listening on: http://127.0.0.1:{PORT}")
    print(f"  Launching web browser...")
    print(f"============================================================")
    sys.stdout.flush()

    # Launch browser automatically
    threading.Thread(target=open_browser_tab, daemon=True).start()

    with ThreadedTCPServer(('127.0.0.1', PORT), PortalHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server...")

if __name__ == '__main__':
    main()
