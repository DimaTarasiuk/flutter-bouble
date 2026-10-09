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

GRADLE_GROOVY="$ANDROID_APP/build.gradle"
GRADLE_KTS="$ANDROID_APP/build.gradle.kts"

python3 - <<'PY'
from pathlib import Path
import re
import sys

root = Path(".")
groovy = root / "android/app/build.gradle"
kts = root / "android/app/build.gradle.kts"

def patch_groovy(text: str) -> str:
    header = """
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

"""
    if "keystoreProperties" not in text:
        text = header + text

    signing_configs = """
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
"""
    if "signingConfigs {" not in text:
        text = text.replace("android {", "android {" + signing_configs, 1)

    # Replace any debug signing assignment on release builds
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
            r"(buildTypes\s*\{[^\]]*?\brelease\s*\{)",
            r"\1\n            signingConfig signingConfigs.release",
            text,
            count=1,
            flags=re.S,
        )
    return text


def patch_kts(text: str) -> str:
    header = """
val keystoreProperties = java.util.Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

"""
    if "keystoreProperties" not in text:
        text = header + text

    signing_configs = """
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
"""
    if "signingConfigs {" not in text:
        text = text.replace("android {", "android {" + signing_configs, 1)

    text = re.sub(
        r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
        'signingConfig = signingConfigs.getByName("release")',
        text,
    )
    if 'getByName("release")' not in text:
        text = re.sub(
            r"(buildTypes\s*\{[^\]]*?\brelease\s*\{)",
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

if "signingConfigs {" not in patched:
    sys.exit("Failed to inject signingConfigs")
if "signingConfigs.release" not in patched and 'getByName("release")' not in patched:
    sys.exit("Failed to set release signingConfig")

path.write_text(patched)
print(f"Patched {path}")
PY

echo "Android release signing configured."