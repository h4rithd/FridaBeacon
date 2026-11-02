#!/usr/bin/env python3
"""Package the FridaBeacon Magisk module without third-party binaries."""

from __future__ import annotations

import os
import re
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent
MODULE = ROOT / "module"
OUTPUT = Path(os.environ.get("FRIDABEACON_OUTPUT_DIR", str(ROOT / "dist")))
REQUIRED = {
    "action.sh",
    "customize.sh",
    "fetcher.jar",
    "frida-ctl.sh",
    "module.prop",
    "service.sh",
    "skip_mount",
}


def main() -> None:
    present = {path.name for path in MODULE.iterdir() if path.is_file()}
    if present != REQUIRED:
        raise ValueError(f"Unexpected module files: missing={REQUIRED - present}, extra={present - REQUIRED}")
    metadata = dict(
        line.split("=", 1)
        for line in (MODULE / "module.prop").read_text().splitlines()
        if "=" in line
    )
    version = metadata.get("version", "")
    if not re.fullmatch(r"[0-9]+\.[0-9]+(?:\.[0-9]+)?", version):
        raise ValueError(f"Invalid module version: {version!r}")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    destination = OUTPUT / f"FridaBeacon-v{version}.zip"
    with tempfile.TemporaryDirectory(prefix="fridabeacon-build-") as temporary:
        incomplete = Path(temporary) / "module.zip"
        with zipfile.ZipFile(incomplete, "w") as package:
            for name in sorted(REQUIRED):
                path = MODULE / name
                entry = zipfile.ZipInfo(name)
                entry.compress_type = zipfile.ZIP_DEFLATED
                entry.external_attr = ((0o755 if name.endswith(".sh") else 0o644) << 16)
                package.writestr(entry, path.read_bytes())
            package.write(ROOT / "LICENSE", "LICENSE", compress_type=zipfile.ZIP_DEFLATED)
        os.replace(incomplete, destination)
    print(f"Built {destination} ({destination.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
