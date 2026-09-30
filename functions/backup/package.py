"""Package the locked application wheel for OCI's code-only archive layout."""

import pathlib
import shutil
import subprocess
import zipfile
import hashlib
import json

root = pathlib.Path(__file__).resolve().parent
project = root.parent.parent
package = root / "package"
shutil.rmtree(package, ignore_errors=True)
(package / "function").mkdir(parents=True)
(package / "function" / "func.py").write_text("from backup.func import handler\n")
# uv build has no --locked flag: use the backend installed from uv.lock, offline.
subprocess.run(
    [
        "uv",
        "build",
        "--no-build-isolation",
        "--offline",
        "--wheel",
        "--out-dir",
        str(package / "wheels"),
    ],
    check=True,
)
subprocess.run(
    [
        "uv",
        "export",
        "--locked",
        "--no-dev",
        "--no-emit-project",
        "--format",
        "requirements-txt",
        "--output-file",
        str(package / "requirements.txt"),
    ],
    check=True,
    stdout=subprocess.DEVNULL,
)
subprocess.run(
    [
        "uv",
        "pip",
        "sync",
        "--python-version",
        "3.12",
        "--python-platform",
        "x86_64-manylinux_2_28",
        "--only-binary",
        ":all:",
        "--require-hashes",
        "--no-compile-bytecode",
        "--target",
        str(package / "python"),
        str(package / "requirements.txt"),
    ],
    check=True,
)
wheel = next((package / "wheels").glob("*.whl"))
with zipfile.ZipFile(wheel) as archive:
    archive.extractall(package / "python")
# Installer provenance contains absolute paths; it is not runtime content.
for path in (package / "python").glob("*.dist-info/direct_url.json"):
    path.unlink()
with zipfile.ZipFile(root / "function.zip", "w", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(
        p for folder in ["function", "python"] for p in (package / folder).rglob("*")
    ):
        if path.is_file() and "__pycache__" not in path.parts:
            info = zipfile.ZipInfo(
                path.relative_to(package).as_posix(), (2026, 1, 1, 0, 0, 0)
            )
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())
inputs = ["pyproject.toml", "uv.lock", "mise.toml", "mise.lock"]
inputs += [p.relative_to(project).as_posix() for p in sorted(root.glob("src/**/*.py"))]
inputs += ["functions/backup/package.py"]
(root / "function.manifest.json").write_text(
    json.dumps(
        {
            "inputs": {
                p: hashlib.sha256((project / p).read_bytes()).hexdigest()
                for p in inputs
            },
            "archive_sha256": hashlib.sha256(
                (root / "function.zip").read_bytes()
            ).hexdigest(),
        },
        sort_keys=True,
    )
    + "\n"
)
