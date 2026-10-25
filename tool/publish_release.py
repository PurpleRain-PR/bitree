import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path


def gh(*arguments):
    subprocess.run(["gh", *arguments], check=True, stdout=subprocess.DEVNULL)


def github(path):
    result = subprocess.run(
        ["gh", "api", path], capture_output=True, text=True, check=False
    )
    if result.returncode == 0:
        return json.loads(result.stdout)
    if "(HTTP 404)" in result.stderr:
        return None

    raise SystemExit(result.stderr.strip())


def release_notes(tag):
    changelog = Path("CHANGELOG.md").read_text(encoding="utf-8")
    entry = re.search(rf"(?ms)^## {re.escape(tag)} - [^\n]*\n.*?(?=^## |\Z)", changelog)
    return entry[0].strip() + "\n"


os.chdir(Path(__file__).resolve().parent.parent)
parser = argparse.ArgumentParser()
parser.add_argument("channel", choices=["dev", "release"])
parser.add_argument("version")
args = parser.parse_args()

repository = os.environ["GITHUB_REPOSITORY"]
sha = os.environ["GITHUB_SHA"]
tag = "dev" if args.channel == "dev" else args.version
endpoint = f"repos/{repository}"
assets = sorted(Path("dist").glob("BITree-*"))

checksums = Path("dist/SHA256SUMS.txt")
with checksums.open("w", encoding="utf-8") as output:
    for asset in assets:
        with asset.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        output.write(f"{digest}  {asset.name}\n")

existing = github(f"{endpoint}/releases/tags/{tag}")
if (
    args.channel == "release"
    and existing is not None
    and (not existing["draft"] or existing["target_commitish"] != sha)
):
    raise SystemExit(f"{tag} 已发布或存在其他提交的草稿。")

if existing is None:
    command = [
        "release",
        "create",
        tag,
        "--repo",
        repository,
        "--target",
        sha,
        "--draft",
        "--latest=false",
        "--title",
        "Dev Build" if args.channel == "dev" else f"BITree {tag}",
    ]
    if args.channel == "dev":
        command.extend(["--prerelease", "--notes", "基于最新commit构建"])
    else:
        notes = Path("dist/release-notes.md")
        notes.write_text(release_notes(tag), encoding="utf-8")
        command.extend(["--notes-file", str(notes)])
        if "-" in tag:
            command.append("--prerelease")

    gh(*command)

gh(
    "release",
    "upload",
    tag,
    "--repo",
    repository,
    "--clobber",
    *map(str, assets),
    str(checksums),
)

if args.channel == "dev" and existing is not None:
    # Keep the fixed release and its manually maintained description.
    gh(
        "api",
        "--method",
        "PATCH",
        f"{endpoint}/git/refs/tags/dev",
        "-f",
        f"sha={sha}",
        "-F",
        "force=true",
    )

    keep = {asset.name for asset in assets} | {checksums.name}
    for asset in existing["assets"]:
        if asset["name"] not in keep:
            gh("api", "--method", "DELETE", f"{endpoint}/releases/assets/{asset['id']}")

latest = args.channel == "release" and "-" not in tag
command = [
    "release",
    "edit",
    tag,
    "--repo",
    repository,
    "--draft=false",
    f"--latest={str(latest).lower()}",
]
if args.channel == "dev":
    command.append("--prerelease")
gh(*command)
