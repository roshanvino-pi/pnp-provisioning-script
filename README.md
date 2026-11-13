# SharePoint PnP Provisioning skill

Generates a ready-to-run SharePoint PnP PowerShell provisioning package for a project, derived from
that project's own functional/requirements docs.

You point it at a project, it reads the functional doc, and writes a `PnPScript/` folder you can run:

```powershell
cd <project>/PnPScript
.\MainScript.ps1 -SiteUrl "https://tenant.sharepoint.com/sites/YourSite/"
```

## How it works, and why it's reliable

The nine scripts in `skills/pnp-provision/template/Script/` are **pure CSV interpreters**. Not one of
them contains project-specific logic — each imports a CSV, loops, checks whether the thing already
exists, creates it, and logs. They have been run against a live tenant and their exact error
handling, existence checks, and XML construction are the reason the package works.

So the skill **never generates PowerShell**. It copies that engine verbatim and writes only the eight
CSVs in `Schema/` plus the site URL. The engine is structurally out of reach of the model, which is
what keeps it trustworthy on the twentieth project as much as the first.

Everything the model is allowed to vary lives in:

| | |
|---|---|
| `Schema/*.csv` | Eight CSVs — the entire project schema |
| `MainScript.ps1` | One line: the `{{SITE_URL}}` placeholder |

## Install (Claude Code)

```
/plugin marketplace add mukundsharma-pidigital/pnp-provision-plugin
/plugin install pnp-provision@pi-sharepoint
```

Restart Claude Code, then invoke it from any project:

```
/pnp-provision
```

To update later: `/plugin update pnp-provision`.

> Private repo? Install uses your existing git credentials. If `git clone` of this repo works in your
> terminal, install will work. Otherwise run `gh auth setup-git` first.

## Install (Codex, or any other agent)

Clone the repo somewhere stable, then follow
[`skills/pnp-provision/reference/AGENTS-snippet.md`](skills/pnp-provision/reference/AGENTS-snippet.md).
It contains a block to paste into a project's `AGENTS.md` pointing at your clone, so Claude and Codex
work from the same template and the same rules.

## What it does when invoked

1. Reads the project's functional spec / requirements chapter / data dictionary. **It does not
   interview you** — if the docs answer it, it doesn't ask.
2. Derives the entity model: lists, fields with SharePoint types, choices, relationships, which
   fields get indexed, which are calculated.
3. Picks an internal-name prefix from the module name and tells you what it chose.
4. Writes `<project>/PnPScript/` — engine copied verbatim, CSVs generated.
5. Validates, and fixes anything it finds.
6. Reports the prefix, the entities and which doc each came from, every assumption it made, and the
   run command.

It will not run `MainScript.ps1` for you. That writes to a live SharePoint tenant, so it's your call.

## The validator

`skills/pnp-provision/reference/Validate-Schema.ps1` cross-checks the eight CSVs against each other
offline — no tenant connection, no side effects. It exists because generated CSVs fail *late*: a
lookup pointing at a list that doesn't exist doesn't error, it silently creates a broken field
halfway through a run against your live site.

Run it against any schema, generated or hand-edited:

```powershell
pwsh -File .\skills\pnp-provision\reference\Validate-Schema.ps1 -SchemaPath .\PnPScript\Schema
```

It exits non-zero on errors, so it works in CI. It passes clean on
`skills/pnp-provision/reference/example-schema/` — a real Asset Management schema, kept as the
ground-truth smoke test:

```powershell
pwsh -File .\skills\pnp-provision\reference\Validate-Schema.ps1 `
     -SchemaPath .\skills\pnp-provision\reference\example-schema
```

It checks referential integrity across CSVs (lookups pointing at real lists, calculated columns
declaring every field their formula uses, views and indexes naming fields that exist), type rules per
`FieldType`, duplicates, and the SharePoint 20-index-per-list limit.

## Things worth knowing before you run a generated package

**It's idempotent by *skipping*, not updating.** Every script checks existence first, so re-running is
safe — but it does not apply CSV edits to columns that already exist. Change a `DisplayName` and
re-run and nothing happens; the column has to be removed in SharePoint first. Choice options are the
one exception (`01` updates those in place).

**`01-CreateSiteColumns.ps1` has a `pause` in its error path.** If a column fails to create, the run
stops and waits for Enter. That's deliberate — it surfaces the failure — but if a run appears to hang
about a minute in, that's why. The exception message is printed just above the prompt.

**Requiredness is not provisioned.** `04-CreateLists.ps1` clears the Required flag on every required
field on every run, by design. Mandatory fields are enforced in the form layer, not here.

**Subsites need a manual step.** If any content type has `ParentContentType=Document`, a subsite
needs `Local Document Content Type` created by hand first, and
`$parentDocumentContentTypeName` in `MainScript.ps1` switched to match. The skill flags this.

## Repo layout

```
.claude-plugin/
  plugin.json                    # plugin manifest
  marketplace.json               # marketplace manifest (this repo is both)
skills/pnp-provision/
  SKILL.md                       # the procedure
  template/                      # the engine — copied verbatim, never edited
    MainScript.ps1
    Script/01..09-*.ps1
  reference/
    csv-contracts.md             # exact CSV headers + traps, derived from the scripts
    Validate-Schema.ps1          # offline validator
    example-schema/              # known-good schema; ground truth for the validator
    AGENTS-snippet.md            # Codex pointer
```

## Contributing

Changing the engine (`template/`) means every future generated package changes. If you fix a bug in a
`.ps1`, bump `version` in `.claude-plugin/plugin.json` and say what changed — colleagues on older
installs won't pick it up until they `/plugin update`.

If you teach the CSVs something new, `reference/csv-contracts.md` and `Validate-Schema.ps1` both need
to learn it too, or the validator will reject valid schemas.

Line endings are pinned in `.gitattributes` (`.ps1` and `.csv` to CRLF). Don't remove that — it's
what keeps the engine identical across machines regardless of anyone's `core.autocrlf`.
