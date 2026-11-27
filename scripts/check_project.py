#!/usr/bin/env python3
"""Conservative, reproducible source/history/documentation readiness audit."""
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def git(*args):
    return subprocess.check_output(["git",*args],cwd=ROOT).decode("utf-8").strip()


def substantive(line):
    line = line.strip()
    return bool(line) and not line.startswith(("//","pub extend")) and not re.fullmatch(r"[{}\[\](),;]+",line)


def validate_release_metadata(manifest, readme, changelog):
    names = re.findall(r'^name\s*=\s*"([^"\n]+)"\s*$', manifest, re.M)
    versions = re.findall(r'^version\s*=\s*"([^"\n]+)"\s*$', manifest, re.M)
    assert len(names) == len(versions) == 1, "ambiguous manifest identity/version"
    module, version = names[0], versions[0]
    documented = re.findall(re.escape(module) + r"@([0-9A-Za-z.+-]+)", readme)
    assert len(documented) >= 2, "README must identify the module and installation version"
    assert all(v == version for v in documented), ("README version mismatch", version, documented)
    install = "moon add " + module + "@" + version
    assert install in readme, "README installation command must use the current version"
    headings = re.findall(r"^## ([0-9]+\.[0-9]+\.[0-9]+) .+$", changelog, re.M)
    assert headings and headings[0] == version, "first CHANGELOG entry must match the manifest"



def validate_documented_toolchain(workflow, documents):
    pins = re.findall(r"^\s*MOONBIT_INSTALL_VERSION:\s*([^\s]+)\s*$", workflow, re.M)
    assert len(pins) == 1, "CI must declare one MoonBit compiler pin"
    pin = pins[0]
    assert re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+\+[0-9a-f]+", pin), "invalid CI compiler pin"
    for path, text in documents.items():
        versions = re.findall(r"[0-9]+\.[0-9]+\.[0-9]+\+[0-9a-f]+", text)
        assert versions, (path, "missing documented compiler version")
        assert all(version == pin for version in versions), (path, "compiler version differs from CI", pin, versions)


def main():
    validate_release_metadata(
        (ROOT / "moon.mod").read_text(encoding="utf-8"),
        (ROOT / "README.md").read_text(encoding="utf-8"),
        (ROOT / "CHANGELOG.md").read_text(encoding="utf-8"),
    )
    validate_documented_toolchain(
        (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8"),
        {name: (ROOT / name).read_text(encoding="utf-8")
         for name in ("README.md", "docs/validation.md")},
    )
    production = sorted(p for p in ROOT.glob("*.mbt") if not p.name.endswith(("_test.mbt","_wbtest.mbt")))
    physical = sum(len(p.read_text(encoding="utf-8").splitlines()) for p in production)
    useful = sum(sum(substantive(line) for line in p.read_text(encoding="utf-8").splitlines()) for p in production)
    assert useful >= 1500, ("substantive production lines",useful)
    revisions = git("rev-list","--reverse","HEAD").splitlines()
    meaningful = 0
    for revision in revisions:
        parents = git("show","-s","--format=%P",revision).split()
        if len(parents) > 1:
            continue
        changed = git("diff-tree","--root","--no-commit-id","--numstat","-r",revision)
        count = 0
        for row in changed.splitlines():
            added,removed,path = row.split("\t",2)
            if path.endswith(".mbti"):
                continue
            if added.isdigit() and removed.isdigit():
                count += int(added)+int(removed)
        if count >= 10:
            meaningful += 1
    assert meaningful >= 20, ("nontrivial commits",meaningful)
    # Size alone cannot establish engineering value; docs list the reviewed slices.
    required = ["README.md","LICENSE","THIRD_PARTY.md","SECURITY.md","CHANGELOG.md",
                "docs/design.md","docs/protocol.md","docs/validation.md","docs/competition/duplicate-check.md",
                "pkg.generated.mbti",".github/workflows/ci.yml"]
    for name in required:
        assert (ROOT/name).is_file(),name
    for path in [ROOT/"README.md",ROOT/"docs/design.md",ROOT/"docs/protocol.md",ROOT/"docs/validation.md"]:
        text = path.read_text(encoding="utf-8")
        assert not re.search(r"\bTODO\b|\bTBD\b|\{\{[A-Z_]",text),path
        for target in re.findall(r"\]\(([^)]+)\)",text):
            if "://" in target or target.startswith("#"):
                continue
            assert (path.parent/target.split("#")[0]).exists(),(path,target)
    for name in git("ls-files").splitlines():
        assert not re.search(r"(?i)(application|proposal|credentials|\.dpapi|__pycache__)",name),name
    print(json.dumps({"production_files":len(production),"production_physical_lines":physical,
                      "substantive_lines":useful,"commits":len(revisions),
                      "nontrivial_commits":meaningful,"documentation":"passed"}))


if __name__ == "__main__":
    main()
