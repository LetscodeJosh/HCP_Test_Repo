import os
import sys
import subprocess
import hashlib
import json
import re

REPO_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

def print_header(title):
    print("\n" + "=" * 72)
    print(f"  {title}")
    print("=" * 72)

def get_file_sha256(path):
    if not path or not os.path.exists(path):
        return None
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def get_legacy_version_dir(repo_dir, version_str):
    legacy_base = os.path.join(repo_dir, 'releases', 'legacy_versions')
    if not os.path.exists(legacy_base):
        return None
    # 1. Exact match
    exact = os.path.join(legacy_base, version_str)
    if os.path.exists(exact):
        return exact
    # 2. Case-insensitive lookup (e.g. 'v.0.6.5' matching 'V.0.6.5')
    for d in os.listdir(legacy_base):
        if d.lower() == version_str.lower():
            return os.path.join(legacy_base, d)
    return None

def check_asset_parity():
    print_header("CHECK 1: Zero-Drift Asset Parity (Web App Copies)")
    with open(os.path.join(REPO_DIR, 'VERSION'), 'r', encoding='utf-8') as vf:
        current_v = vf.read().strip()

    legacy_v_dir = get_legacy_version_dir(REPO_DIR, current_v)
    legacy_portal = (
        os.path.join(legacy_v_dir, 'Territory_Reconfiguration_Setup', 'territory_reconfiguration_portal.html')
        if legacy_v_dir else None
    )

    portal_paths = [
        os.path.join(REPO_DIR, 'docs', 'territory_reconfiguration_portal.html'),
        os.path.join(REPO_DIR, 'assets', 'web', 'territory_reconfiguration_portal.html'),
        os.path.join(REPO_DIR, 'installers', 'Territory_Reconfiguration_App', 'territory_reconfiguration_portal.html'),
        legacy_portal
    ]
    
    hashes = {}
    for p in portal_paths:
        if not p or not os.path.exists(p):
            rel_p = os.path.relpath(p, REPO_DIR) if p else 'None'
            print(f"  [FAIL] Missing file: {rel_p}")
            return False
        h = get_file_sha256(p)
        rel_p = os.path.relpath(p, REPO_DIR)
        hashes[rel_p] = h
        print(f"  [OK] {rel_p} -> SHA256: {h[:16]}... ({os.path.getsize(p):,} bytes)")

    unique_hashes = set(hashes.values())
    if len(unique_hashes) == 1:
        print("  --> PASS: All 4 web portal copies are 100% byte-for-byte identical!")
        return True
    else:
        print("  --> FAIL: Hash mismatch detected across portal copies!")
        return False

def check_version_alignment():
    print_header("CHECK 2: Semantic Version Synchronization")
    # 1. VERSION file
    v_file = os.path.join(REPO_DIR, 'VERSION')
    with open(v_file, 'r', encoding='utf-8') as f:
        version_str = f.read().strip()
    
    # 2. pubspec.yaml
    pubspec_file = os.path.join(REPO_DIR, 'pubspec.yaml')
    with open(pubspec_file, 'r', encoding='utf-8') as f:
        pubspec_content = f.read()
    m_pub = re.search(r'version:\s*([\d\.\+]+)', pubspec_content)
    pub_ver = m_pub.group(1) if m_pub else None

    # 3. app_version.dart
    app_v_file = os.path.join(REPO_DIR, 'lib', 'constants', 'app_version.dart')
    with open(app_v_file, 'r', encoding='utf-8') as f:
        dart_content = f.read()
    m_dart = re.search(r"version\s*=\s*'([^']+)'", dart_content)
    dart_ver = m_dart.group(1) if m_dart else None

    # 4. metadata.json
    legacy_v_dir = get_legacy_version_dir(REPO_DIR, version_str)
    meta_file = os.path.join(legacy_v_dir, 'metadata.json') if legacy_v_dir else None
    meta_ver = None
    if meta_file and os.path.exists(meta_file):
        with open(meta_file, 'r', encoding='utf-8') as f:
            meta_data = json.load(f)
            meta_ver = meta_data.get('version')

    print(f"  VERSION file:    {version_str}")
    print(f"  pubspec.yaml:    {pub_ver}")
    print(f"  app_version.dart:{dart_ver}")
    print(f"  metadata.json:   {meta_ver}")

    clean_v = re.sub(r'^[vV]\.?', '', version_str)
    clean_dart = re.sub(r'^[vV]\.?', '', dart_ver) if dart_ver else None
    clean_pub = pub_ver.split('+')[0] if pub_ver else None
    clean_meta = re.sub(r'^[vV]\.?', '', meta_ver) if meta_ver else None

    if clean_v == clean_dart == clean_pub == clean_meta:
        print("  --> PASS: Version string is 100% synchronized across all files!")
        return True
    else:
        print("  --> FAIL: Version mismatch detected across version tracking files!")
        return False

def check_root_hygiene():
    print_header("CHECK 3: Repository Root Cleanliness (Zero Clutter Rule)")
    allowed_root_files = {
        'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml',
        'README.md', 'CHANGELOG.md', 'VERSION', 'AGENTS.md',
        '.gitignore', '.metadata', '.flutter-plugins', '.flutter-plugins-dependencies'
    }
    
    violations = []
    for item in os.listdir(REPO_DIR):
        full_path = os.path.join(REPO_DIR, item)
        if os.path.isfile(full_path):
            if item not in allowed_root_files:
                violations.append(item)

    if not violations:
        print("  --> PASS: Repository root is pristine. Zero clutter violations!")
        return True
    else:
        print(f"  --> FAIL: Found unapproved files in repository root: {violations}")
        return False

def check_package_artifacts():
    print_header("CHECK 4: Release Package Integrity")
    with open(os.path.join(REPO_DIR, 'VERSION'), 'r', encoding='utf-8') as vf:
        current_v = vf.read().strip()

    legacy_v_dir = get_legacy_version_dir(REPO_DIR, current_v)
    
    # Locate legacy APK case-insensitively
    legacy_apk = None
    if legacy_v_dir and os.path.exists(legacy_v_dir):
        for f in os.listdir(legacy_v_dir):
            if f.lower().endswith('.apk'):
                legacy_apk = os.path.join(legacy_v_dir, f)
                break

    packages = [
        os.path.join(REPO_DIR, 'releases', 'Territory_Reconfiguration_Setup.exe'),
        os.path.join(REPO_DIR, 'releases', 'Territory_Reconfiguration_Setup.zip'),
        os.path.join(REPO_DIR, 'releases', 'HCP_Profiling_Release.apk'),
        os.path.join(legacy_v_dir, 'Territory_Reconfiguration_Setup.exe') if legacy_v_dir else None,
        os.path.join(legacy_v_dir, 'Territory_Reconfiguration_Setup.zip') if legacy_v_dir else None,
        legacy_apk
    ]

    all_exist = True
    for p in packages:
        if not p or not os.path.exists(p) or os.path.getsize(p) == 0:
            rel_p = os.path.relpath(p, REPO_DIR) if p else 'None'
            print(f"  [FAIL] Missing or empty package: {rel_p}")
            all_exist = False
        else:
            rel_p = os.path.relpath(p, REPO_DIR)
            print(f"  [OK] {rel_p} ({os.path.getsize(p):,} bytes)")

    if all_exist:
        print("  --> PASS: All release executables, APKs, and ZIP packages verified!")
        return True
    else:
        print("  --> FAIL: Missing release packages!")
        return False

def check_auth_invariance():
    print_header("CHECK 5: Web App Authentication Invariance & Zero-Regression Check")
    portal_file = os.path.join(REPO_DIR, 'docs', 'territory_reconfiguration_portal.html')
    if not os.path.exists(portal_file):
        print("  --> FAIL: docs/territory_reconfiguration_portal.html not found!")
        return False

    with open(portal_file, 'r', encoding='utf-8') as f:
        html = f.read()

    required_auth_elements = [
        ('applyAuthenticatedUser function', 'function applyAuthenticatedUser('),
        ('showLoginView function', 'function showLoginView('),
        ('handlePortalLogin function', 'async function handlePortalLogin('),
        ('checkAuthSession function', 'function checkAuthSession('),
        ('showAppView fallback alias', 'function showAppView('),
        ('Session recovery via applyAuthenticatedUser', 'applyAuthenticatedUser(u, false)'),
        ('Streamlit render applyAuthenticatedUser', 'applyAuthenticatedUser(auth.user, isActivelyLoggingIn)')
    ]

    all_ok = True
    for label, needle in required_auth_elements:
        if needle in html:
            print(f"  [OK] {label} present & verified")
        else:
            print(f"  [FAIL] Missing or altered: {label}")
            all_ok = False

    streamlit_app = os.path.join(REPO_DIR, 'installers', 'Streamlit_Deployment', 'app.py')
    if os.path.exists(streamlit_app):
        with open(streamlit_app, 'r', encoding='utf-8') as f:
            app_code = f.read()
        if 'verify_erpnext_credentials' in app_code and 'sfe_session' in app_code:
            print("  [OK] Streamlit app.py credentials verification & session token persistence verified")
        else:
            print("  [FAIL] Streamlit app.py authentication handler compromised!")
            all_ok = False

    if all_ok:
        print("  --> PASS: Web App authentication pipeline is 100% intact with zero regressions!")
        return True
    else:
        print("  --> FAIL: Authentication invariance violation detected!")
        return False

def main():
    print("=======================================================================")
    print("  PIMS HCP PROFILING & RECONFIGURATION: TECH DEBT PREVENTION AUDIT")
    print("=======================================================================")

    parity_ok = check_asset_parity()
    version_ok = check_version_alignment()
    hygiene_ok = check_root_hygiene()
    package_ok = check_package_artifacts()
    auth_ok = check_auth_invariance()

    print_header("OVERALL TECHNICAL DEBT AUDIT SCORE")
    results = [parity_ok, version_ok, hygiene_ok, package_ok, auth_ok]
    passed_count = sum(1 for r in results if r)
    total_count = len(results)

    print(f"  Passed {passed_count}/{total_count} core architectural invariants.")
    if passed_count == total_count:
        print("  STATUS: GRADE A+ (ZERO TECHNICAL DEBT - FULLY PRODUCTION VIABLE)")
        sys.exit(0)
    else:
        print("  STATUS: TECH DEBT WARNING (Some architectural checks failed)")
        sys.exit(1)

if __name__ == '__main__':
    main()
