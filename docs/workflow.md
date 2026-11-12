# Workflow

Daily flows assuming the kit is installed in the folder you open.

## Drafting a chapter

Open the chapter file in the editor, then ask directly:

```
write section 3.2 on the test method, edit only chapters/chapter3.tex
```

The rules in `.claude/CLAUDE.md` apply automatically: one file per change, formal
academic register, labels `sec:/fig:/tab:/eq:`, citations verified against the `.bib`.

Then:

```
compile_thesis
```

```
engine: pdflatex
exit code: 0
status: SUCCESS — build/main.pdf (1.2 MB)
No errors and no undefined references.
```

On failure it returns only what matters:

```
=== ERRORS ===
! Undefined control sequence.
l.142 \undefinedmacro

=== UNDEFINED REFERENCES / CITATIONS ===
Reference `sec:method' on page 12 undefined on input line 88.
```

## Checking the bibliography

```
check_bibtex
```

```
total entries: 42
entry types: article=30, inproceedings=8, book=4
=== DUPLICATE KEYS ===
none
=== ENTRIES WITH MISSING FIELDS ===
smith2023 (article): missing year
```

Run it before and after adding references.

## Literature review

```
do a literature review on <topic>, search PubMed and arXiv, save to Zotero
```

The chain: the research-superpower skills define a screening rubric, the
`academic-research` MCP fans out across OpenAlex, Semantic Scholar, PubMed, CrossRef,
and arXiv with deduplication, and `zotero` writes the survivors into a collection.
With PRISMA numbers this becomes a systematic review.

For citation snowballing, start from a seed paper:

```
find papers citing <doi> and papers it cites, two levels deep
```

## Verifying citations before submission

```
check every citation in chapters/chapter2.tex against refs/references.bib
```

Three passes: `check_bibtex` for duplicates and missing fields, `nature-ref-verifier` or
the plugin's `verifying-citations` skill for metadata against the live source, then
`compile_thesis` until no `Citation ... undefined` remains.

## Polishing prose

```
polish chapter 4, remove AI-sounding phrasing, do not change numbers or citations
```

`academic-humanizer` or `nature-polishing`. Both preserve facts, figures, terminology,
and citation positions; they change rhythm and word choice only.

## Review before submission

```
review this manuscript as a journal reviewer would
```

`nature-reviewer` or the plugin's `/ars-reviewer` produce a structured report:
significance, validity, major and minor concerns. Then:

```
draft a response letter for these reviewer comments
```

## Exporting

Markdown to journal-formatted Word:

```
convert this manuscript to docx using GB/T 7714
```

LaTeX builds directly through `compile_thesis`. Figures come from `nature-figure` or the
`figures` plugin; slides from `nature-paper2ppt`.

## Quick reference

| Command | Purpose |
|---|---|
| `compile_thesis` | build, return errors only |
| `check_bibtex` | audit the bibliography |
| `read_chapter chapter.tex` | load one chapter without the whole manuscript |
| `/mcp` | MCP status and approval |
| `/plugin` | plugin status |
| `/ars-plan` | research planning dialogue (`lengkap`) |
| `/ars-reviewer` | simulated peer review (`lengkap`) |
| `/research discover "topic"` | multi-database search (`lengkap`) |

## Working in a monorepo

Open the manuscript folder, not the repository root. Claude Code reads
`enabledPlugins` only from the session's working directory, so a session at the root
will not load the plugins even though the skills are visible.

If you need both at once, run from the root with the manuscript folder added:

```powershell
claude --add-dir buku-kp
```

## Cost control

Use `ringkas` while drafting. Switch to `lengkap` for a review or grant push, then switch
back:

```powershell
./academic-kit.ps1 -Profile lengkap
# ... work ...
./academic-kit.ps1 -Profile ringkas
```

Check what is loaded at any time with `-Status` and `/plugin`.
