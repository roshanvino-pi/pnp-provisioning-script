---
name: pnp-provision
description: Generate a complete PnP PowerShell provisioning package (MainScript + Script/ + Schema/ CSVs) for a SharePoint project from its functional/requirements docs. Use when the user asks for a PnP script, PnP schema, SharePoint provisioning scripts, site columns/content types/lists provisioning, or says "build the PnP package for this project".
---

# PnP provisioning package generator

Generates a ready-to-run SharePoint provisioning package by copying a known-good script engine
verbatim and writing only the CSVs that drive it.

## Where this skill's own files live

Two folders ship next to this `SKILL.md`. **Resolve them relative to this file's own location** —
never hardcode an absolute path. The install location differs per machine and per tool (plugin
install, `~/.claude/skills/`, a project's `.claude/skills/`, or a plain clone read by Codex).

| Path | What it is |
|---|---|
| `template/` | The script engine. Copied verbatim into every generated package. |
| `reference/csv-contracts.md` | Exact CSV headers and the traps. Read before writing any CSV. |
| `reference/Validate-Schema.ps1` | Offline validator. Run before reporting done. |
| `reference/example-schema/` | A known-good filled-in schema (Asset Management), for format reference only. |

When installed as a plugin this directory is `${CLAUDE_PLUGIN_ROOT}/skills/pnp-provision/`.

## The one rule

**Never write, edit, regenerate, or "improve" any `.ps1` file.** Copy `template/` byte-for-byte.

The nine scripts in `template/Script/` are pure CSV interpreters — they contain zero project-specific
logic. They are battle-tested against a live tenant and their exact error handling, existence checks,
and XML construction are the reason the package works. All project variation lives in the eight CSVs
and one URL. If a requirement seems to need a script change, it almost certainly does not; express it
in the CSVs, and if it truly cannot be, say so in your report rather than editing the engine.

The single permitted edit: replace `{{SITE_URL}}` in `MainScript.ps1`.

## Procedure

### 1. Gather requirements — do not ask the user

Find and read the project's own docs before asking anything. Look for functional specs, requirement
chapters, BRDs, data dictionaries, entity/field tables, `docs/`, `*.md`, `*.docx`, `*.xlsx`. Read
every one that describes entities or fields. Existing code — models, DTOs, Power Apps YAML, SQL
schemas — is equally valid input.

Only ask the user something if, after reading, an entity's fields or relationships are genuinely
undeterminable. Assumptions you can make reasonably: make them, and list them in your report.

Never ask for the site URL. It goes in as `{{SITE_URL}}` → a placeholder the user passes at runtime
via `-SiteUrl`.

### 2. Build the entity model

From the docs, derive for each entity: its lists, every field with a SharePoint type, choice options,
relationships between entities, what gets filtered/sorted (→ indexes), and any derived values
(→ calculated columns).

Map requirement language to field types honestly: "dropdown"/"one of" → `Choice`; "multi-select" →
`MultiChoice`; "owner"/"assigned to"/"approver" → `User`; "notes"/"description"/"comments" → `Note`;
"link" → `URL`; "yes/no" → `Boolean`; "amount"/"cost" → `Currency`; "date" → `DateTime`. A field that
points at another entity is a lookup, not a Text field.

### 3. Pick the internal-name prefix

Every internal name gets a project prefix, following the reference package's `ASTHW…` convention
(Asset Management + Hardware). Derive it from the module name in the docs — take initials or a
compressed form, 2–5 uppercase chars. Where a project has clearly distinct entity families, extend
the prefix per family the way `ASTHW` does. Report the prefix you chose; do not ask first.

Internal names: `<PREFIX><PascalCaseFieldName>`, no spaces or special characters. Display names stay
human-readable.

### 4. Create the package

Output to `<project>/PnPScript/` unless the user named a location. Copy the whole `template/` tree —
`MainScript.ps1` plus all of `Script/` — preserving filenames exactly. `MainScript.ps1` calls each
script by its numbered name and its `Set-Location $PSScriptRoot` makes `Schema\*.csv` resolve
relatively, so the folder layout is load-bearing.

If the target already has a `PnPScript/`, stop and ask before overwriting — the user may have
hand-edited CSVs there.

### 5. Write the eight CSVs

Read `reference/csv-contracts.md` in full before writing any CSV. It documents the exact header of
each file, which script consumes it, and the traps (comma-splitting on choices, one-row-per-column
views, the `CreateColumn` two-pass quirk in lookups, requiredness being cleared on every run).

All eight files must exist in `Schema/` with their header row, even if a project has no calculated
or lookup columns — `MainScript.ps1` runs all nine steps unconditionally and `Import-Csv` throws on a
missing file.

`reference/example-schema/` holds a real, known-good schema (an Asset Management project). Consult it
to confirm formatting — quoting, empty-column conventions, how a header-only CSV looks. **Do not
adapt its content.** Its entities and `ASTHW` prefix belong to that project, not the one you are
generating. Deriving your schema from the docs and using the example only for shape is the difference
between a real package and a renamed copy of someone else's.

### 6. Set the URL

Replace `{{SITE_URL}}` in `MainScript.ps1` with the site URL if the docs state one, otherwise leave
the placeholder and tell the user to pass `-SiteUrl`.

If the target is a **subsite**, uncomment the `$parentDocumentContentTypeName = "Local Document
Content Type"` line and flag that the content type must be created manually first. Only relevant if
any content type has `ParentContentType=Document`.

### 7. Validate

Run `reference/Validate-Schema.ps1` against the generated `Schema/` folder. It cross-checks
references between CSVs offline — no tenant connection needed — and catches the failure mode that
otherwise only surfaces mid-run against a live site.

```powershell
pwsh -File "<this-skill-dir>/reference/Validate-Schema.ps1" -SchemaPath "<project>/PnPScript/Schema"
```

Substitute `<this-skill-dir>` with the directory this `SKILL.md` was loaded from. Quote both paths —
install paths and project paths routinely contain spaces. If `pwsh` is not on PATH, fall back to
`powershell -File`; the validator targets Windows PowerShell 5.1 and up.

Fix every error it reports and re-run until clean. Warnings are judgment calls; address or explain.

### 8. Report

Tell the user: the prefix you chose, the entities/lists you derived and from which doc, anything you
assumed or could not determine, the validator result, and the run command:

```powershell
cd <project>/PnPScript
.\MainScript.ps1 -SiteUrl "https://tenant.sharepoint.com/sites/YourSite/"
```

Note that it authenticates with `-UseWebLogin` and will open a browser. Do not run it yourself — it
writes to a live SharePoint tenant. That is the user's call.

## Ordering is fixed

`MainScript.ps1` runs the steps in a dependency order that must not be reasoned around: site columns
→ content types → fields onto content types → lists → calculated columns → lookups → remove `Item` →
views → indexes. Lookups resolve their parent list at runtime, so parent lists must be created
first; `Item` removal requires the project content type to already be default; views and indexes need
their fields to exist. If two entities look up at each other, both still work — the lookup step runs
after every list exists.

## Re-running

The package is idempotent by design — every script checks existence first. But "idempotent" here
means *skip*, not *update*: re-running does not apply CSV edits to columns that already exist
(Choice options are the sole exception; `01` updates those). Tell the user that changing a
DisplayName and re-running is a no-op, and the column must be removed in SharePoint first.
