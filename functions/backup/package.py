"""Build the Oracle code-only Python archive, including Linux x86 wheels."""

import pathlib
import shutil
import subprocess
import zipfile

root = pathlib.Path(__file__).resolve().parent
package = root / "package"
shutil.rmtree(package, ignore_errors=True)
(package / "function").mkdir(parents=True)
shutil.copyfile(root / "func.py", package / "function" / "func.py")
subprocess.run(
    [
        "uv",
        "pip",
        "install",
        "--python-version",
        "3.12",
        "--python-platform",
        "x86_64-manylinux_2_28",
        "--only-binary",
        ":all:",
        "--target",
        str(package / "python"),
        "-r",
        str(root / "requirements.txt"),
    ],
    check=True,
)
with zipfile.ZipFile(root / "function.zip", "w", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(package.rglob("*")):
        if path.is_file():
            info = zipfile.ZipInfo(
                path.relative_to(package).as_posix(), (2026, 1, 1, 0, 0, 0)
            )
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())
