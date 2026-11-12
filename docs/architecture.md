# Architecture

## Scope model

Claude Code loads four kinds of configuration, and they do not behave the same way. The
installer is built around that asymmetry.

| Config | Location | Discovered from | Walks up to git root? |
|---|---|---|---|
| Skills | `.claude/skills/<name>/SKILL.md` | working directory | **yes** |
| Project settings (`enabledPlugins`) | `.claude/settings.json` | working directory only | **no** |
| Project memory | `CLAUDE.md` or `.claude/CLAUDE.md` | working directory | **yes** |
| MCP servers | `.mcp.json` | working directory | **yes**, to the filesystem root |

Consequences that shaped the design:

- **Plugins are the odd one out.** A monorepo with the kit at the root would not enable
  plugins for a session opened in a subfolder. Install at the manuscript folder instead.
- **Skills and MCP servers walk up.** Installing at `D:\repo\buku-kp` means a session at
  `D:\repo` also sees them. Install at the deepest folder that needs them.
- **Skills are not scanned recursively.** Each skill must be
  `.claude/skills/<name>/SKILL.md`; a nested directory is ignored.
- **A settings file in a parent folder does not layer onto a subfolder.** Each project's
  settings must stand alone.

## What the installer writes

```
<project>/
├── .claude/
│   ├── skills/<name>/        junction to the kit (default) or a copy (-Portable)
│   ├── settings.json         {"enabledPlugins": {<id>: true, ...}}
│   ├── CLAUDE.md             rules between <!-- academic-kit:start/end -->
│   └── .academic-kit.json    manifest: profile, portable flag, skills, plugins
├── .mcp.json                 four servers, absolute paths substituted
└── .gitignore                marked block ignoring .claude/ and .mcp.json
```

Everything is additive and reversible. `-Off` reads the manifest rather than trusting
directory contents, so it removes exactly what it installed.

## Repo layout

```
academic-kit/
├── academic-kit.ps1        installer and remover
├── profiles.ini            plugin ids per profile
├── vendor.ini              third-party skill sources, pinned by commit
├── plugins.txt             full plugin list (reference)
├── mcp.json                MCP template with placeholders
├── skills/                 skills shipped in this repo
├── rules/academic-writing.md   content of .claude/CLAUDE.md
├── latex/latex_mcp.py      thesis-latex MCP server
├── scripts/fetch-vendor.ps1    clones and pins third-party skills
└── docs/
```

`vendor/` (84 MB of cloned repositories) is gitignored and created at install time.

## Templates and placeholders

`mcp.json` holds placeholders that the installer substitutes:

| Placeholder | Replaced with |
|---|---|
| `{{KIT_PYTHON}}` | the Python interpreter that runs `thesis-latex` |
| `{{KIT_SCRIPT}}` | absolute path to `latex/latex_mcp.py` |

`THESIS_ROOT` is written only into `thesis-latex`, and only as an absolute path for the
target project. Other servers ignore it.

## The thesis-latex server

A FastMCP server exposing three tools. Its job is context economy: a failing LaTeX build
otherwise dumps three thousand lines of log into the conversation.

| Tool | Returns |
|---|---|
| `compile_thesis(main_file)` | engine, exit code, each `!` error with its `l.<n>` source line, and every `Reference`/`Citation ... undefined` warning |
| `check_bibtex(bib_file)` | entry count, type breakdown, duplicate keys, entries missing `author`/`title`/`year` |
| `read_chapter(chapter_path)` | one chapter file, so the whole manuscript never enters context |

Two robustness measures, both discovered through real failures:

1. **Engine detection.** A `% !TEX program = xelatex` comment selects the engine;
   otherwise `pdflatex`.
2. **PATH sanitizing.** MiKTeX aborts with Windows error 267 when any PATH entry is a
   file rather than a directory — a stray `...\psql.exe\` entry is enough. Every
   subprocess gets a PATH containing only real directories, with the TeX bin directory
   prepended. If `latexmk` still cannot start (for example, Perl is missing), the server
   falls back to running the engine directly with `bibtex` between passes.

## Profiles and token cost

Plugins are loaded for every session and their descriptions occupy context. The three
profiles exist so the cost matches the task:

| Profile | Plugins | Always-on | Typical task |
|---|---|---|---|
| `ringkas` | 5 | ~3.5k | drafting a chapter |
| `riset` | 4 | ~2.3k | literature search and citation work |
| `lengkap` | 17 | ~13.9k | grants, peer review, figures |

Switching profiles uninstalls every managed plugin the new profile does not list, so
costs cannot creep upward across switches.

## Third-party skills

`vendor.ini` lists each upstream repository, an optional pinned commit, and which
directories contain skills. `scripts/fetch-vendor.ps1` clones them into `vendor/` and
writes `vendor/.manifest.json` mapping skill name to path. The installer merges local
and fetched skills into `.claude/skills/`.

Rationale: 84 MB of upstream content stays out of this repository, each project keeps
its own license and history, and updates are a `git pull` in the upstream repo rather
than a merge in this one.

## Failure modes and their handling

| Failure | Handling |
|---|---|
| Junction target moved | `-Off` tolerates missing targets; reinstall re-links |
| Manifest deleted | `-Off` falls back to junction-target detection |
| Marketplace cache cold, plugin install drops | installer retries each plugin once, then reports failures in yellow |
| User skill with the same name | installer skips it, `-Off` never deletes it |
| `.gitignore` already has content | marked block is appended and replaced in place; surrounding content untouched |
| `.mcp.json` already exists | entries are merged per server name; unrelated servers survive |
| `.claude/CLAUDE.md` already exists | rules are wrapped in markers and replaced in place |
