# Codex / AGENTS.md pointer

Codex does not read Claude Code plugins or `~/.claude/skills/`. To use this skill from Codex, clone
this repo somewhere stable and paste the block below into the project's `AGENTS.md`, replacing every
`<PNP_SKILL_DIR>` with the absolute path to `skills/pnp-provision` inside your clone.

Example — if you cloned to `C:\src\pnp-provision-plugin`, then `<PNP_SKILL_DIR>` is
`C:\src\pnp-provision-plugin\skills\pnp-provision`.

Keep the clone outside the project repo (or gitignore it), so the skill is not vendored into every
project that uses it.

---

## SharePoint PnP provisioning

To generate the PnP provisioning package for this project, follow the procedure in
`<PNP_SKILL_DIR>/SKILL.md`. Read that file first — the list below is the contract, not the procedure.

- The nine scripts in `<PNP_SKILL_DIR>/template/Script/` are pure CSV interpreters, known-good
  against a live tenant. **Copy them byte-for-byte. Never edit or regenerate a `.ps1`.** All project
  variation lives in the eight `Schema/*.csv` files.
- The only permitted edit is replacing `{{SITE_URL}}` in `MainScript.ps1`.
- Read `<PNP_SKILL_DIR>/reference/csv-contracts.md` before writing any CSV — it has the exact headers
  and the traps. `<PNP_SKILL_DIR>/reference/example-schema/` shows a known-good schema; copy its
  shape, never its content.
- Derive the schema from this project's own functional/requirements docs. Do not ask questions the
  docs already answer, and never ask for the site URL — it is a runtime `-SiteUrl` parameter.
- Output to `PnPScript/` at the project root.
- Validate before reporting done, and fix every error:

  ```powershell
  pwsh -File "<PNP_SKILL_DIR>/reference/Validate-Schema.ps1" -SchemaPath "./PnPScript/Schema"
  ```

- Do not run `MainScript.ps1`. It writes to a live SharePoint tenant; that is the user's call.
