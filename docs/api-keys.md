# API keys

Every key below is optional. The kit works without any of them; keys raise rate limits
or unlock write access. Set them once at the **User** level and restart the terminal and
the Claude Code session.

```powershell
setx OPENALEX_EMAIL "you@university.ac.id"
```

Verify (open a **new** terminal first):

```powershell
[Environment]::GetEnvironmentVariable("OPENALEX_EMAIL", "User")   # reads the registry
python -c "import os; print(os.environ.get('OPENALEX_EMAIL'))"    # reads the session
```

The second line is empty until the session restarts. That is expected.

MCP servers inherit the environment from the Claude Code process. Never write keys into
`.mcp.json`: that file travels with the project and is often copied or committed.

---

## OpenAlex — email (free, one minute)

Raises the limit from 1 to 10 requests per second and identifies you to the polite pool.
Used by the `academic-research` MCP, the `openalex` skill, and `opencite`.

1. No signup. Any valid address works.
2. `setx OPENALEX_EMAIL "you@university.ac.id"`

## CrossRef — email (free, one minute)

Enters the polite pool, which returns faster responses. Used for DOI verification.

1. No signup.
2. `setx CROSSREF_EMAIL "you@university.ac.id"`

## NCBI / PubMed — API key (free, three minutes)

Raises the PubMed limit from 3 to 10 requests per second. Used by the
`academic-research` MCP for PubMed, MeSH, and PRISMA workflows.

1. <https://account.ncbi.nlm.nih.gov/> — register, verify the email.
2. Sign in, open **Account Settings**, scroll down.
3. **Create an API Key**.
4. Copy the 36-character string; it is shown once.
5. `setx NCBI_API_KEY "..."`

## Semantic Scholar — API key (free, two minutes)

Raises the limit from 100 requests per 5 minutes to 1 request per second sustained.
Used for citation snowballing and the citation graph.

1. <https://www.semanticscholar.org/product/api#api-key-form>
2. Name, email, and a one-line reason (for example, "systematic review for a thesis").
3. Activate from the email you receive.
4. The key arrives by email or in the dashboard.

Set both names, because different tools read different ones:

```powershell
setx SEMANTIC_SCHOLAR_API_KEY "..."
setx S2_API_KEY "..."
```

## Zotero — Web API key (free, four minutes)

Lets the `zotero` MCP and the `zotero-*` skills read and write a Zotero library: add
items, upload PDFs, fix metadata, export BibTeX.

### Library ID

1. <https://www.zotero.org/settings/keys> — sign in.
2. The page states **"Your userID for use in API calls is XXXXXXX"**. Note the number.

### Key

1. **Create new key**, name it (for example `claude-code-academic`).
2. Tick **Allow library access**, **Allow notes access**, **Allow write access**.
3. Leave **Default Group Permissions** at **None** unless you work in a group library.
4. **Save Key** and copy the 24-character string (shown once).

```powershell
setx ZOTERO_API_KEY "..."
setx ZOTERO_LIBRARY_ID "12345678"
setx ZOTERO_LIBRARY_TYPE "user"
```

For a group library, set `ZOTERO_LIBRARY_TYPE` to `group` and use the group ID from the
group's URL.

### Local mode (faster, no key needed for reads)

With Zotero Desktop running on the same machine, reads can go straight to
`zotero.sqlite`, which is far faster on large libraries.

1. Zotero → **Settings → Advanced → Allow other applications on this computer to
   communicate with Zotero**.
2. `setx ZOTERO_LOCAL "true"`

Without that setting, or with Zotero closed, keep `ZOTERO_LOCAL=false` and let the Web
API serve reads.

## Parallel — API key (paid, optional)

Real-time web research for the `claude-scientific-writer` plugin. Without a key the
plugin still runs; it just cannot do live lookups.

1. <https://platform.parallel.ai/> — register, open **API Keys**.
2. `setx PARALLEL_API_KEY "..."`

CLI alternative:

```powershell
uv tool install "parallel-web-tools[cli]==0.7.1"
parallel-cli login
```

## Exa — no key required

The `exa` MCP in this setup uses OAuth via `https://mcp.exa.ai/mcp`. A personal key is
only needed for self-hosting: <https://dashboard.exa.ai/api-keys>

---

## Summary

| Variable | Service | Cost | Priority | Obtain |
|---|---|---|---|---|
| `OPENALEX_EMAIL` | OpenAlex | free | high (one minute) | direct, no signup |
| `CROSSREF_EMAIL` | CrossRef | free | medium | direct, no signup |
| `NCBI_API_KEY` | PubMed | free | high for biomedicine | account.ncbi.nlm.nih.gov |
| `SEMANTIC_SCHOLAR_API_KEY` + `S2_API_KEY` | Semantic Scholar | free | medium | semanticscholar.org/product/api |
| `ZOTERO_API_KEY` + `ZOTERO_LIBRARY_ID` + `ZOTERO_LIBRARY_TYPE` | Zotero | free | high | zotero.org/settings/keys |
| `ZOTERO_LOCAL` | Zotero local reads | free | high | set `true` with Zotero running |
| `PARALLEL_API_KEY` | Parallel.ai | paid | low | platform.parallel.ai |
| — | Exa | OAuth | automatic | included |

## After setting keys

1. Close VS Code, terminals, and every Claude Code session.
2. Reopen, enter a project that has the kit installed.
3. `/mcp` → approve the four servers.
4. Ask for one search to confirm the key is visible.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `OPENALEX_EMAIL not set` warning | session predates the `setx` | restart the terminal and Claude Code |
| 403 from PubMed | key copied with whitespace | re-run `setx` with the bare string |
| Zotero returns nothing | library is empty, or wrong library ID | check `zotero.org/settings/keys` for the userID |
| Zotero write fails | key lacks write access | recreate the key with **Allow write access** |
| Local mode errors | Zotero Desktop closed or the setting is off | enable it, or set `ZOTERO_LOCAL=false` |
