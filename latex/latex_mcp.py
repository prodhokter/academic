"""FastMCP server for a modular LaTeX thesis workflow.

Tools keep Claude's context clean: compile output is reduced to errors,
undefined references and undefined citations instead of a raw .log dump.

Run: python latex/latex_mcp.py
Register: claude mcp add thesis-latex -- python /path/to/latex/latex_mcp.py
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from fastmcp import FastMCP

mcp = FastMCP("thesis-latex")


def _resolve_project_root() -> Path:
    """Pick the thesis root: explicit env var, then cwd, then the script's parent repo."""
    override = os.environ.get("THESIS_ROOT")
    if override:
        return Path(override).expanduser().resolve()
    for candidate in (Path.cwd(), Path(__file__).resolve().parent.parent):
        if (candidate / "main.tex").is_file():
            return candidate
    return Path.cwd()


PROJECT_ROOT = _resolve_project_root()

# latexmk picks the engine from the .latexmkrc or from these flags.
ENGINE_FLAGS = {
    "pdflatex": ["-pdf"],
    "xelatex": ["-xelatex"],
    "lualatex": ["-lualatex"],
}

ENGINE_BINARIES = {"pdflatex": "pdflatex", "xelatex": "xelatex", "lualatex": "lualatex"}

# MiKTeX and TeX Live for Windows do not always land on PATH.
# Set THESIS_TEX_BIN to your own bin directory when it lives elsewhere.
TOOL_DIRS = tuple(
    directory
    for directory in (
        os.environ.get("THESIS_TEX_BIN", ""),
        os.path.expandvars(r"%LOCALAPPDATA%\Programs\MiKTeX\miktex\bin\x64"),
        r"C:\Program Files\MiKTeX\miktex\bin\x64",
        r"C:\Program Files\MiKTeX\miktex\bin",
        r"C:\texlive\2025\bin\windows",
        r"C:\texlive\2024\bin\windows",
        "/usr/local/texlive/2025/bin/x86_64-linux",
        "/Library/TeX/texbin",
        "/opt/homebrew/bin",
        "/usr/local/bin",
    )
    if directory
)


def _find_tool(name: str) -> str | None:
    """Locate a TeX binary on PATH or in the usual Windows install roots."""
    found = shutil.which(name)
    if found:
        return found
    for directory in TOOL_DIRS:
        for suffix in (".exe", ""):
            candidate = Path(directory) / f"{name}{suffix}"
            if candidate.is_file():
                return str(candidate)
    return None


def _clean_env() -> dict[str, str]:
    """Return an env whose PATH holds only real directories.

    MiKTeX aborts with Windows error 267 when any PATH entry is a file rather
    than a directory (a stray `...\\psql.exe\\` entry is enough), so every
    subprocess gets a sanitized PATH.
    """
    env = dict(os.environ)
    entries = env.get("PATH", "").split(os.pathsep)
    kept = [entry for entry in entries if entry and Path(entry).is_dir()]
    # MiKTeX needs its own bin dir (and Perl) on PATH even when it was found
    # through a hard-coded fallback path.
    for directory in TOOL_DIRS:
        if Path(directory).is_dir():
            kept.append(directory)
    seen: set[str] = set()
    unique = []
    for entry in kept:
        lowered = entry.lower().rstrip("\\/")
        if lowered not in seen:
            seen.add(lowered)
            unique.append(entry)
    env["PATH"] = os.pathsep.join(unique)
    return env

MAX_ERRORS = 40
MAX_WARNINGS = 40
MAX_CONTEXT_LINES = 3


def _limit(items: list[str], cap: int, noun: str) -> list[str]:
    if len(items) <= cap:
        return items
    return items[:cap] + [f"... {len(items) - cap} more {noun} truncated"]


def _detect_engine(main_file: Path) -> str:
    """Read a magic comment such as '% !TEX program = xelatex' if present."""
    try:
        head = main_file.read_text(encoding="utf-8", errors="ignore")[:4000]
    except OSError:
        return "pdflatex"
    match = re.search(r"%\s*!TEX\s+program\s*=\s*(\w+)", head, re.IGNORECASE)
    if match and match.group(1).lower() in ENGINE_FLAGS:
        return match.group(1).lower()
    return "pdflatex"


def _log_error_blocks(log_text: str) -> list[str]:
    """Return each LaTeX error (`! ...`) plus a few following context lines."""
    lines = log_text.splitlines()
    blocks: list[str] = []
    for index, line in enumerate(lines):
        if not line.startswith("!"):
            continue
        context = lines[index : index + 1 + MAX_CONTEXT_LINES]
        # l.<number> marks the offending source line; append it only when the
        # fixed-length window above missed it.
        for offset in range(index + 1, min(index + 12, len(lines))):
            if re.match(r"^l\.\d+", lines[offset]):
                candidate = lines[offset].strip()
                if not any(candidate in part for part in context):
                    context.append(lines[offset])
                break
        blocks.append("\n".join(part.rstrip() for part in context if part.strip()))
    return blocks


def _undefined_warnings(log_text: str) -> list[str]:
    patterns = (
        re.compile(r"LaTeX Warning: (Reference `[^']+' on page \S+ undefined.*)"),
        re.compile(r"LaTeX Warning: (Citation `[^']+' on page \S+ undefined.*)"),
        re.compile(r"(Package \w+ Warning: Citation `[^']+' .*undefined.*)"),
    )
    found: list[str] = []
    for line in log_text.splitlines():
        stripped = line.strip()
        for pattern in patterns:
            match = pattern.search(stripped)
            if match:
                found.append(match.group(1).strip())
                break
    return found


@mcp.tool
def compile_thesis(main_file: str = "main.tex") -> str:
    """Compile the thesis with latexmk and report only actionable diagnostics.

    Args:
        main_file: Path to the root .tex file, relative to the project root.
    """
    target = PROJECT_ROOT / main_file
    if not target.is_file():
        return f"ERROR: main file not found: {target}"

    engine = _detect_engine(target)
    latexmk = _find_tool("latexmk")
    engine_bin = _find_tool(ENGINE_BINARIES[engine])

    if latexmk:
        command = [
            latexmk,
            *ENGINE_FLAGS[engine],
            "-interaction=nonstopmode",
            target.name,
        ]
    elif engine_bin:
        command = [engine_bin, "-interaction=nonstopmode", target.name]
    else:
        return (
            "ERROR: no LaTeX toolchain found. Install MiKTeX (winget install MiKTeX.MiKTeX) "
            "or TeX Live, then reopen the session so the MCP server sees the new PATH."
        )

    def run(cmd: list[str]) -> subprocess.CompletedProcess:
        return subprocess.run(
            cmd,
            cwd=target.parent,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=300,
            env=_clean_env(),
        )

    # latexmk aborts when MiKTeX cannot stat every PATH entry (a stale or
    # non-directory entry is enough). Fall back to the bare engine in that case.
    runs = 1 if latexmk else 3
    completed = None
    for _ in range(runs):
        try:
            completed = run(command)
        except subprocess.TimeoutExpired:
            return f"ERROR: LaTeX timed out after 300s while compiling {target.name}."
        if completed.returncode != 0:
            break

    notes: list[str] = []
    if latexmk and completed.returncode != 0 and engine_bin:
        combined = (completed.stderr or "") + (completed.stdout or "")
        if "cannot retrieve attributes" in combined.lower() or "major issue" in combined.lower():
            notes.append("latexmk failed on a broken PATH entry; fell back to the engine directly.")
            bibtex = _find_tool("bibtex")
            # engine -> bibtex -> engine -> engine: the pass order needed for
            # \cite, \ref and the bibliography to settle without latexmk.
            steps = [[engine_bin, "-interaction=nonstopmode", target.name]]
            if bibtex:
                steps.append([bibtex, target.stem])
            steps.append([engine_bin, "-interaction=nonstopmode", target.name])
            steps.append([engine_bin, "-interaction=nonstopmode", target.name])

            ok = True
            for step in steps:
                try:
                    completed = run(step)
                except subprocess.TimeoutExpired:
                    return f"ERROR: LaTeX timed out after 300s while compiling {target.name}."
                # bibtex returns 1 for undefined citations; the engine passes
                # afterwards are what decide success.
                if step[0] == engine_bin and completed.returncode != 0:
                    ok = False
                    break
            if ok:
                notes.append("engine ran 3x with bibtex in between.")

    log_path = target.with_suffix(".log")
    log_text = ""
    if log_path.is_file():
        log_text = log_path.read_text(encoding="utf-8", errors="replace")

    errors = _limit(_log_error_blocks(log_text), MAX_ERRORS, "errors")
    warnings = _limit(_undefined_warnings(log_text), MAX_WARNINGS, "warnings")

    summary = [
        f"engine: {engine}",
        f"exit code: {completed.returncode}",
        *notes,
    ]
    pdf_path = target.with_suffix(".pdf")
    if completed.returncode == 0 and pdf_path.is_file():
        summary.append(f"status: SUCCESS — {pdf_path.name} ({pdf_path.stat().st_size} bytes)")

    if errors:
        summary.append("\n=== ERRORS ===")
        summary.extend(errors)
    if warnings:
        summary.append("\n=== UNDEFINED REFERENCES / CITATIONS ===")
        summary.extend(warnings)

    if not errors and not warnings:
        if completed.returncode != 0:
            tail = "\n".join(completed.stderr.strip().splitlines()[-8:])
            summary.append("No '!' errors parsed. stderr tail:\n" + tail)
        else:
            summary.append("No errors and no undefined references.")

    return "\n".join(summary)


@mcp.tool
def check_bibtex(bib_file: str = "daftar-pustaka.bib") -> str:
    """Audit a BibTeX file for duplicate keys, missing required fields, and totals.

    Args:
        bib_file: Path to the .bib file, relative to the project root.
    """
    path = PROJECT_ROOT / bib_file
    if not path.is_file():
        return f"ERROR: bibliography not found: {path}"

    text = path.read_text(encoding="utf-8", errors="replace")
    header = re.compile(r"@(\w+)\s*\{\s*([^,\s]+)\s*,", re.IGNORECASE)
    headers = list(header.finditer(text))

    keys: list[str] = []
    duplicates: list[str] = []
    missing_fields: list[str] = []
    entry_types: dict[str, int] = {}

    # Fields where an entry legitimately carries no author.
    author_optional = {"book", "phdthesis", "mastersthesis", "manual", "misc"}

    for position, match in enumerate(headers):
        entry_type = match.group(1).lower()
        key = match.group(2)
        keys.append(key)
        entry_types[entry_type] = entry_types.get(entry_type, 0) + 1

        end = headers[position + 1].start() if position + 1 < len(headers) else len(text)
        body = text[match.start() : end]

        def has_field(name: str) -> bool:
            return re.search(rf"(?<![\w-]){name}\s*=", body, re.IGNORECASE) is not None

        absent = []
        if not has_field("title"):
            absent.append("title")
        if entry_type not in author_optional and not has_field("author") and not has_field("editor"):
            absent.append("author")
        if not has_field("year") and not has_field("date"):
            absent.append("year")
        if absent:
            missing_fields.append(f"{key} ({entry_type}): missing {', '.join(absent)}")

    seen: set[str] = set()
    for key in keys:
        if key in seen and key not in duplicates:
            duplicates.append(key)
        seen.add(key)

    report = [
        f"file: {path.name}",
        f"total entries: {len(keys)}",
        "entry types: " + ", ".join(f"{name}={count}" for name, count in sorted(entry_types.items())),
    ]
    report.append("\n=== DUPLICATE KEYS ===")
    report.extend(_limit(duplicates, MAX_ERRORS, "duplicates") if duplicates else ["none"])
    report.append("\n=== ENTRIES WITH MISSING FIELDS ===")
    report.extend(_limit(missing_fields, MAX_ERRORS, "entries") if missing_fields else ["none"])

    return "\n".join(report)


@mcp.tool
def read_chapter(chapter_path: str) -> str:
    """Read one chapter sub-file without pulling the whole thesis into context.

    Args:
        chapter_path: Path to the chapter .tex file, relative to the project root.
    """
    path = PROJECT_ROOT / chapter_path
    if not path.is_file():
        return f"ERROR: chapter not found: {path}"

    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    return f"file: {chapter_path}\nlines: {len(lines)}\n\n{text}"


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] in {"--help", "-h"}:
        print(__doc__)
        print(f"project root: {PROJECT_ROOT}")
        sys.exit(0)
    mcp.run()
