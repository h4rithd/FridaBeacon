#!/usr/bin/env python3
"""Rebuild the platform-independent Android HTTPS helper from source."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SDK = Path(os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT") or "")
if not SDK.is_dir() or not (SDK / "build-tools").is_dir():
    raise SystemExit("Set ANDROID_HOME or ANDROID_SDK_ROOT to an Android SDK")

BUILD_TOOLS = sorted((SDK / "build-tools").iterdir())[-1]
PLATFORMS = sorted((SDK / "platforms").iterdir())[-1]
JAVA_HOME = os.environ.get("JAVA_HOME")
JAVAC = str(Path(JAVA_HOME) / "bin/javac") if JAVA_HOME else shutil.which("javac")
if not JAVAC:
    raise SystemExit("Install a JDK or set JAVA_HOME")

environment = os.environ.copy()
if JAVA_HOME:
    environment["PATH"] = str(Path(JAVA_HOME) / "bin") + os.pathsep + environment.get("PATH", "")

with tempfile.TemporaryDirectory(prefix="fridabeacon-dex-") as temporary:
    workspace = Path(temporary)
    classes = workspace / "classes"
    classes.mkdir()
    source = ROOT / "android/src/com/h4rithd/fridabeacon/Fetcher.java"
    subprocess.run(
        [JAVAC, "-source", "8", "-target", "8", "-Xlint:-options", "-bootclasspath",
         str(PLATFORMS / "android.jar"), "-d", str(classes), str(source)],
        check=True,
        env=environment,
    )
    subprocess.run(
        [str(BUILD_TOOLS / "d8"), "--min-api", "21", "--output",
         str(ROOT / "module/fetcher.jar"),
         str(classes / "com/h4rithd/fridabeacon/Fetcher.class")],
        check=True,
        env=environment,
    )

print("Built module/fetcher.jar")
