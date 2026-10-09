#!/usr/bin/env bash
# Patches android/app/build.gradle(.kts) to sign release with a stable keystore.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIGNING_DIR="$ROOT/signing"
ANDROID_APP="$ROOT/android/app"

if [[ ! -f "$SIGNING_DIR/bouble-upload.jks" || ! -f "$SIGNING_DIR/key.properties" ]]; then
  echo "Missing signing/bouble-upload.jks or signing/key.properties"
  exit 1
fi

mkdir -p "$ANDROID_APP"
cp "$SIGNING_DIR/bouble-upload.jks" "$ANDROID_APP/bouble-upload.jks"
cp "$SIGNING_DIR/key.properties" "$ROOT/android/key.properties"

python3 - <<'PY'
from pathlib import Path
import re
import sys

root = Path(".")
props_path = root / "android" / "key.properties"
groovy = root / "android/app/build.gradle"
kts = root / "android/app/build.gradle.kts"

props = {}
for line in props_path.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    k, v = line.split("=", 1)
    props[k.strip()] = v.strip()

required = ("storePassword", "keyPassword", "keyAlias", "storeFile")
missing = [k for k in required if k not in props]
if missing:
    sys.exit(f"key.properties missing: {', '.join(missing)}")

def kt_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

def groovy_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def patch_groovy(text: str) -> str:
    # Prefer inlined values — avoids FileInputStream / AGP script classpath issues
    signing_configs = f"""
    signingConfigs {{
        release {{
            keyAlias {groovy_str(props['keyAlias'])}
            keyPassword {groovy_str(props['keyPassword'])}
            storeFile file({groovy_str(props['storeFile'])})
            storePassword {groovy_str(props['storePassword'])}
        }}
    }}
"""
    if "signingConfigs {" not in text:
        text = text.replace("android {", "android {" + signing_configs, 1)

    text = re.sub(
        r"signingConfig\s*=\s*signingConfigs\.debug",
        "signingConfig = signingConfigs.release",
        text,
    )
    text = re.sub(
        r"signingConfig\s+signingConfigs\.debug",
        "signingConfig signingConfigs.release",
        text,
    )
    if "signingConfigs.release" not in text:
        text = re.sub(
            r"(buildTypes\s*\{.*?\brelease\s*\{)",
            r"\1\n            signingConfig signingConfigs.release",
            text,
            count=1,
            flags=re.S,
        )
    return text


def patch_kts(text: str) -> str:
    # Inline credentials — do NOT use java.util.Properties (breaks on modern AGP/Kotlin DSL)
    signing_configs = f"""
    signingConfigs {{
        create("release") {{
            keyAlias = {kt_str(props['keyAlias'])}
            keyPassword = {kt_str(props['keyPassword'])}
            storeFile = file({kt_str(props['storeFile'])})
            storePassword = {kt_str(props['storePassword'])}
        }}
    }}
"""
    if "signingConfigs {" not in text:
        text = text.replace("android {", "android {" + signing_configs, 1)

    text = re.sub(
        r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
        'signingConfig = signingConfigs.getByName("release")',
        text,
    )
    # Also handle older style without getByName
    text = re.sub(
        r"signingConfig\s*=\s*signingConfigs\.debug",
        'signingConfig = signingConfigs.getByName("release")',
        text,
    )
    if 'getByName("release")' not in text:
        text = re.sub(
            r"(buildTypes\s*\{.*?\brelease\s*\{)",
            r'\1\n            signingConfig = signingConfigs.getByName("release")',
            text,
            count=1,
            flags=re.S,
        )
    return text


if kts.exists():
    path = kts
    patched = patch_kts(path.read_text())
elif groovy.exists():
    path = groovy
    patched = patch_groovy(path.read_text())
else:
    sys.exit("No android/app/build.gradle(.kts) found")

# Strip any previously injected Properties() header that breaks AGP 9
patched = re.sub(
    r"\n?val keystoreProperties = java\.util\.Properties\(\).*?keystoreProperties\.load\(java\.io\.FileInputStream\(keystorePropertiesFile\)\)\n\}\n*",
    "\n",
    patched,
    count=1,
    flags=re.S,
)
patched = re.sub(
    r"\n?def keystoreProperties = new Properties\(\).*?keystoreProperties\.load\(new FileInputStream\(keystorePropertiesFile\)\)\n\}\n*",
    "\n",
    patched,
    count=1,
    flags=re.S,
)

if "signingConfigs {" not in patched:
    sys.exit("Failed to inject signingConfigs")
if "signingConfigs.release" not in patched and 'getByName("release")' not in patched:
    sys.exit("Failed to set release signingConfig")

path.write_text(patched)
print(f"Patched {path}")
print("Release signing uses inlined key.properties values (no java.util.Properties).")
PY

echo "Android release signing configured."
