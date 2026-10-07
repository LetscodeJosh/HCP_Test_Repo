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
    if not os.path.exists(path):
        return None
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def check_asset_parity():
    print_header("CHECK 1: Zero-Drift Asset Parity (Web App Copies)")
    with open(os.path.join(REPO_DIR, 'VERSION'), 'r', encoding='utf-8') as vf:
        current_v = vf.read().strip()

    portal_paths = [
        os.path.join(REPO_DIR, 'docs', 'territory_reconfiguration_portal.html'),
        os.path.join(REPO_DIR, 'assets', 'web', 'territory_reconfiguration_portal.html'),
        os.path.join(REPO_DIR, 'installers', 'Territory_Reconfiguration_App', 'territory_reconfiguration_portal.html'),
        os.path.join(REPO_DIR, 'releases', 'legacy_versions', current_v, 'Territory_Reconfiguration_Setup', 'territory_reconfiguration_portal.html')
    ]
    
    hashes = {}
    for p in portal_paths:
        h = get_file_sha256(p)
        rel_p = os.path.relpath(p, REPO_DIR)
        if h:
            hashes[rel_p] = h
            print(f"  [OK] {rel_p} -> SHA256: {h[:16]}... ({os.path.getsize(p):,} bytes)")
        else:
            print(f"  [FAIL] Missing file: {rel_p}")
            return False

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
    meta_file = os.path.join(REPO_DIR, 'releases', 'legacy_versions', version_str, 'metadata.json')
    meta_ver = None
    if os.path.exists(meta_file):
        with open(meta_file, 'r', encoding='utf-8') as f:
            meta_data = json.load(f)
            meta_ver = meta_data.get('version')

    print(f"  VERSION file:    {version_str}")
    print(f"  pubspec.yaml:    {pub_ver}")
    print(f"  app_version.dart:{dart_ver}")
    print(f"  metadata.json:   {meta_ver}")

    clean_v = version_str.lstrip('V.')
    clean_dart = dart_ver.lstrip('V.') if dart_ver else None
    clean_pub = pub_ver.split('+')[0] if pub_ver else None
    clean_meta = meta_ver.lstrip('V.') if meta_ver else None

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

    packages = [
        os.path.join(REPO_DIR, 'releases', 'Territory_Reconfiguration_Setup.exe'),
        os.path.join(REPO_DIR, 'releases', 'Territory_Reconfiguration_Setup.zip'),
        os.path.join(REPO_DIR, 'releases', 'HCP_Profiling_Release.apk'),
        os.path.join(REPO_DIR, 'releases', 'legacy_versions', current_v, 'Territory_Reconfiguration_Setup.exe'),
        os.path.join(REPO_DIR, 'releases', 'legacy_versions', current_v, 'Territory_Reconfiguration_Setup.zip'),
        os.path.join(REPO_DIR, 'releases', 'legacy_versions', current_v, f'HCP_Profiling_{current_v}.apk')
    ]

    all_exist = True
    for p in packages:
        rel_p = os.path.relpath(p, REPO_DIR)
        if os.path.exists(p) and os.path.getsize(p) > 0:
            print(f"  [OK] {rel_p} ({os.path.getsize(p):,} bytes)")
        else:
            print(f"  [FAIL] Missing or empty package: {rel_p}")
            all_exist = False

    if all_exist:
        print("  --> PASS: All release executables, APKs, and ZIP packages verified!")
        return True
    else:
        print("  --> FAIL: Missing release packages!")
        return False

def main():
    print("=======================================================================")
    print("  PIMS HCP PROFILING & RECONFIGURATION: TECH DEBT PREVENTION AUDIT")
    print("=======================================================================")

    parity_ok = check_asset_parity()
    version_ok = check_version_alignment()
    hygiene_ok = check_root_hygiene()
    package_ok = check_package_artifacts()

    print_header("OVERALL TECHNICAL DEBT AUDIT SCORE")
    results = [parity_ok, version_ok, hygiene_ok, package_ok]
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
