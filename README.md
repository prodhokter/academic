# Academic Kit for Claude Code

A project-scoped academic writing toolkit for Claude Code: 41 skills, 4 MCP servers,
and a compact set of plugins that turn a coding agent into a careful research and
writing assistant.

Install it into any project folder. Remove it with one command. Nothing is global.

```powershell
git clone https://github.com/prodhokter/academic.git
cd academic
./academic-kit.ps1 -Project D:\skripsi
```

Then open Claude Code in that folder and approve the MCP servers with `/mcp`.

---

## Why this exists

Claude Code is a strong writer but a careless scholar. Left alone it invents citations,
invents numbers, reads a 3,000-line LaTeX log into the context window, and buries the
real error. This kit fixes the parts that matter:

| Problem | What the kit does |
|---|---|
| Fabricated references | Citations are verified against Zotero, CrossRef, OpenAlex, and Semantic Scholar before they enter the bibliography |
| Context blown by build logs | `compile_thesis` returns only errors, the offending source line, and undefined references |
| Style drift | A rules file enforces EYD Indonesian, label conventions, paragraph discipline, and citation hygiene |
| Mixed-language output | Skills for Nature-style, IEEE, Elsevier, APA, GB/T 7714, and Indonesian academic prose |
| Tool sprawl | Three profiles (`ringkas`, `riset`, `lengkap`) sized from 3.5k to 13.9k always-on tokens |

---

## What you get

### Skills (41)

Installed into `.claude/skills/`, discovered by Claude Code per project.

| Group | Examples |
|---|---|
| Writing | `nature-writing`, `nature-polishing`, `academic-humanizer`, `manuscript-writing` (plugin) |
| Literature | `searching-literature`, `subagent-driven-review`, `traversing-citations`, `nature-literature-pipeline` |
| Citations | `zotero`, `zotero-merge-prep`, `zotero-pdf-to-text`, `openalex`, `semantic-scholar`, `arxiv`, `nature-ref-verifier` |
| Review | `nature-reviewer`, `nature-response`, reviewer-simulation and rebuttal flows |
| Output | `nature-paper2word`, `nature-paper2ppt`, `nature-figure`, `nature-image2ppt` |
| Data | `nature-statistics`, `nature-data` |

Skills come from three upstream repositories, cloned at install time
(see [Third-party skills](#third-party-skills)). Nothing third-party is redistributed
inside this repo.

### MCP servers (4)

| Server | Purpose |
|---|---|
| `zotero` | Read and write a Zotero library (Web API or local SQLite) |
| `arxiv` | Search arXiv, read original LaTeX sections, export BibTeX |
| `academic-research` | 25 tools across OpenAlex, Semantic Scholar, PubMed, CrossRef, arXiv, medRxiv, ORCID, Unpaywall, plus PRISMA counts and snowballing |
| `thesis-latex` | Compile LaTeX and return a compact diagnostic instead of the raw log |

`thesis-latex` is a small FastMCP server in [`latex/latex_mcp.py`](latex/latex_mcp.py).
It detects the engine from `% !TEX program = xelatex`, sanitizes the PATH before calling
MiKTeX (a stray non-directory PATH entry makes MiKTeX fail with Windows error 267),
and falls back to running the engine directly with `bibtex` in between when `latexmk`
cannot start.

### Plugins

Selected from public marketplaces and enabled per project, so a session in another
folder does not pay for them.

| Profile | Plugins | Always-on tokens | Use for |
|---|---|---|---|
| `ringkas` (default) | academic-research, manuscript, zotero-skills, opencite, document-skills | ~3.5k | drafting, theses, articles |
| `riset` | academic-research, zotero-skills, opencite, research | ~2.3k | literature review, citation work |
| `lengkap` | all 17 | ~13.9k | grants, peer review, figures, scientific writer |

Switching profiles removes plugins that the new profile does not include, so nothing
accumulates.

---

## Requirements

| Requirement | Why | Install |
|---|---|---|
| Claude Code 2.1+ | plugin and MCP scopes | `npm i -g @anthropic-ai/claude-code` |
| PowerShell 7+ | the installer | `winget install Microsoft.PowerShell` |
| git | fetching third-party skills | `winget install Git.Git` |
| Python 3.10+ | `thesis-latex` server | `winget install Python.Python.3.12` |
| `uv` | runs the MCP servers | `winget install astral-sh.uv` |
| LaTeX (MiKTeX or TeX Live) | compiling documents | `winget install MiKTeX.MiKTeX` |
| Perl | `latexmk` on MiKTeX | `winget install StrawberryPerl.StrawberryPerl` |

Optional: Pandoc for DOCX conversion, LibreOffice for previews, R for statistics,
Inkscape for figure export. Each skill states what it needs when it needs it.

`thesis-latex` needs the `fastmcp` package:

```powershell
python -m venv .venv
.venv\Scripts\python -m pip install fastmcp
```

Point the MCP entry at that interpreter with `-Python` or edit `.mcp.json` afterwards.

---

## Usage

### Install into a project

```powershell
./academic-kit.ps1 -Project D:\skripsi
```

Creates:

```
D:\skripsi\
├── .claude\
│   ├── skills\            41 skills (junctions by default)
│   ├── settings.json      plugins for the chosen profile
│   ├── CLAUDE.md          writing rules
│   └── .academic-kit.json manifest used by -Off
├── .mcp.json              4 MCP servers
└── .gitignore             a marked block ignoring .claude/ and .mcp.json
```

### Accept the MCP servers once

```powershell
cd D:\skripsi
claude
/mcp
```

### Check or remove

```powershell
./academic-kit.ps1 -Project D:\skripsi -Status
./academic-kit.ps1 -Project D:\skripsi -Off
```

### Profiles

```powershell
./academic-kit.ps1 -Project D:\skripsi -Profile lengkap
```

Restart the session afterwards so new plugins load. Skills and MCP servers are read
per session and need no restart.

### Monorepo

Install into the manuscript folder, not the repo root. Claude Code reads
`.claude/settings.json` (where `enabledPlugins` lives) only from the session's working
directory, while skills and `.mcp.json` walk up to the repo root. Installing at the
manuscript folder keeps the coding session at the root clean.

```powershell
cd D:\monorepo\buku-kp
./academic-kit.ps1
```

Or, from anywhere:

```powershell
./academic-kit.ps1 -Project D:\monorepo -ThesisRoot D:\monorepo\buku-kp
```

### Portable

Default installs use junctions: near-zero disk and one update propagates everywhere.
Use `-Portable` when the folder must move to another machine:

```powershell
./academic-kit.ps1 -Project D:\skripsi -Portable
```

Skills are copied (about 39 MB) and the folder becomes self-contained.

---

## API keys

All optional. Without them the kit still works, at lower rate limits.

```powershell
setx OPENALEX_EMAIL          "you@university.ac.id"
setx CROSSREF_EMAIL          "you@university.ac.id"
setx NCBI_API_KEY            "<from account.ncbi.nlm.nih.gov>"
setx SEMANTIC_SCHOLAR_API_KEY "<from semanticscholar.org/product/api>"
setx S2_API_KEY              "<same value; some tools read this name>"
setx ZOTERO_API_KEY          "<from zotero.org/settings/keys>"
setx ZOTERO_LIBRARY_ID       "<your numeric userID>"
setx ZOTERO_LIBRARY_TYPE     "user"
```

Restart the terminal and the Claude Code session afterwards. MCP servers inherit the
environment from the Claude Code process, so no key ever needs to be written into
`.mcp.json` — and none should be, since that file travels with the project.

Full walkthrough: [`docs/api-keys.md`](docs/api-keys.md).

### Zotero permissions

Create the key with **Allow library access**, **Allow notes access**, and
**Allow write access**; leave group permissions at **None** unless you collaborate in a
group library. For faster reads on a large library, run Zotero Desktop, enable
*Settings → Advanced → Allow other applications on this computer to communicate with
Zotero*, then set `ZOTERO_LOCAL=true`.

---

## What gets installed where

| Path | Content | Safe to delete by hand? |
|---|---|---|
| `.claude/skills/` | 41 skills | yes, they disappear from the session |
| `.claude/settings.json` | enabled plugins | yes, plugins become `disabled` |
| `.claude/CLAUDE.md` | writing rules, marker-wrapped | yes |
| `.mcp.json` | 4 MCP servers | yes |
| `.claude/.academic-kit.json` | manifest for `-Off` | yes, but `-Off` then falls back to junction detection |
| `.gitignore` | marked block | yes |

`-Off` never touches a skill you added yourself, nor content in `.gitignore` outside its
own block.

---

## Third-party skills

This repository bundles only its own code and one MIT-licensed skill
(`academic-humanizer`, see [`licenses/`](licenses/)). Everything else is cloned at
install time by [`scripts/fetch-vendor.ps1`](scripts/fetch-vendor.ps1), pinned by
commit in [`vendor.ini`](vendor.ini):

| Source | License | Skills |
|---|---|---|
| [Yuan1z0825/nature-skills](https://github.com/Yuan1z0825/nature-skills) | Apache-2.0 | 24 |
| [thurlow-research/ResearchClaudeCodeSkills](https://github.com/thurlow-research/ResearchClaudeCodeSkills) | MIT | 6 |
| [kthorn/research-superpower](https://github.com/kthorn/research-superpower) | MIT | 10 |
| [AIScientists-Dev/academic-humanizer](https://github.com/AIScientists-Dev/academic-humanizer) | MIT | 1 |

Each upstream keeps its license in its own repository. If you redistribute this kit,
check those licenses first. Use `-NoVendor` to skip fetching entirely.

---

## Repository layout

```
academic-kit/
├── academic-kit.ps1        installer and remover
├── profiles.ini            which plugins belong to which profile
├── plugins.txt             full plugin list
├── vendor.ini              third-party skill sources, pinned by commit
├── mcp.json                MCP template (no secrets)
├── skills/                 skills shipped with this repo
├── rules/academic-writing.md   rules written into .claude/CLAUDE.md
├── latex/latex_mcp.py      the thesis-latex MCP server
├── scripts/fetch-vendor.ps1    clones and pins third-party skills
├── docs/                   api-keys.md, architecture.md, workflow.md
└── licenses/               licenses for bundled third-party content
```

---

## Documentation

- [docs/api-keys.md](docs/api-keys.md) — obtaining every key, step by step
- [docs/architecture.md](docs/architecture.md) — how discovery and scoping actually work
- [docs/workflow.md](docs/workflow.md) — daily flows: drafting, citations, review, export

---

## License

MIT for this repository's own code. Bundled and fetched third-party skills keep their
own licenses.

## Contributing

Issues and pull requests welcome. When changing `mcp.json` or `rules/`, keep both free of
personal paths and secrets; the installer substitutes anything machine-specific.
