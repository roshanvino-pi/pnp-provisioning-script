# CSV contracts

Every column below was derived by reading the scripts in `template/Script/`. The scripts are the
source of truth. If a header name here does not match what the script reads via `$row.Xxx`, the
value silently becomes empty and the row misbehaves — PowerShell does not error on a missing CSV
property.

Write all CSVs with a header row even when there are no data rows. An empty-but-headed CSV is
normal and expected (the Asset Management example ships `CalculatedColumns.csv` and
`ListLookupColumns.csv` as header-only). Never delete a CSV — `MainScript.ps1` runs all nine steps
unconditionally and `Import-Csv` throws on a missing file.

---

## SiteColumns.csv → `01-CreateSiteColumns.ps1`

`Title,DisplayName,Group,FieldType,ChoiceValue,IsMulti,UserMode,Mult`

| Column | Meaning |
|---|---|
| `Title` | **Internal name.** No spaces, no special chars. This is what every other CSV references. |
| `DisplayName` | Human-facing label. Spaces fine. |
| `Group` | Site column group. Use one group name for the whole project. |
| `FieldType` | See table below. |
| `ChoiceValue` | Choice/MultiChoice only. Comma-separated. |
| `IsMulti` | `Note` only: `Yes`, `Plain`, or empty. |
| `UserMode` | User/UserMulti only: `PeopleOnly` or `PeopleAndGroups`. |
| `Mult` | User only: `TRUE` allows multiple. |

The script matches `$field.internalname -eq $column.Title` to decide existence, so `Title` must be
the internal name, not the label.

### FieldType values with special handling

| FieldType | Behavior |
|---|---|
| `Text`, `Number`, `DateTime`, `Boolean`, `Currency` | Falls to the generic `else` branch. Leave `ChoiceValue`/`IsMulti`/`UserMode`/`Mult` empty. |
| `Choice`, `MultiChoice` | Emits `<CHOICES>` from `ChoiceValue`, `FillInChoice='False'`. |
| `Note` | `IsMulti=Yes` → full HTML rich text. `IsMulti=Plain` → plain text. Empty → compatible rich text. |
| `User` | `Mult=TRUE` silently promotes the field to `UserMulti`. |
| `UserMulti` | Always multi. `UserMode` required. |
| `URL` | `Format='Hyperlink'`. |

**Choice values cannot contain commas** — `ChoiceValue.Split(",")` has no escape hatch.

**Re-run behavior differs by type.** For an existing Choice/MultiChoice column, the script *updates*
the choices to match the CSV. For every other type an existing column is left completely untouched —
changing `DisplayName` in the CSV and re-running does nothing.

---

## ContentTypes.csv → `02-CreateContentTypes.ps1`

`Name,Group,Description,ParentContentType`

`ParentContentType` is `Item` for lists or `Document` for libraries. Anything other than the exact
string `Document` takes the Item branch — the value is compared with `-eq "Document"`, so `Folder`
or a blank falls through to Item.

`Document` resolves through `$parentDocumentContentTypeName` in `MainScript.ps1`, which is
`"Document"` for a parent site. On a **subsite**, that variable must be switched to
`"Local Document Content Type"` and the content type created by hand first — the commented block at
the top of `MainScript.ps1` documents this. If the parent is not found the script warns and skips
the row rather than failing.

---

## AddFieldsToContentType.csv → `03-AddFieldsToContentTypes.ps1`

`FieldName,ContentType`

One row per field-to-content-type pairing. `FieldName` matches `SiteColumns.Title`; `ContentType`
matches `ContentTypes.Name`. This is the file that gets long — every column on every content type
needs a row.

Order the rows so each content type's fields are contiguous and in the order they should appear on
the form.

---

## Lists.csv → `04-CreateLists.ps1`

`Url,Title,Template,ContentType`

| Column | Meaning |
|---|---|
| `Url` | Server-relative path, e.g. `lists/HardwareAssets`. No spaces. |
| `Title` | Display name, e.g. `Hardware Assets`. Every other CSV references lists by **Title**. |
| `Template` | `GenericList` or `DocumentLibrary`. |
| `ContentType` | Matches `ContentTypes.Name`. Attached as the **default** content type. |

Beyond creating the list this step also, on every run, enables content types, turns on versioning
with 100 major versions, and **clears the Required flag on every required field** on the list
(except Name/ContentType/Attachments and read-only/hidden fields). Requiredness is deliberately not
provisioned by these scripts — if the functional doc says a field is mandatory, that is enforced
elsewhere (form logic / Power Apps), not here. Do not try to add a `Required` column to
`SiteColumns.csv`; nothing reads it.

---

## CalculatedColumns.csv → `05-CreateCalculatedColumns.ps1`

`ListName,ColumnName,DisplayName,Group,Formula,ResultType,FieldRefs`

| Column | Meaning |
|---|---|
| `ListName` | List **Title**. |
| `ColumnName` | Internal name of the calculated column. |
| `Formula` | SharePoint formula, e.g. `=CONCATENATE([Title]," - ",[Status])`. |
| `ResultType` | `Text`, `Number`, `DateTime`, `Boolean`, `Currency`. |
| `FieldRefs` | Comma-separated **internal names** of every column the formula touches. |

These are list-scoped, not site columns. The script XML-escapes `&`, `<`, `>` in the formula and
`'` in DisplayName/Group for you — write the formula naturally in the CSV.

Every field referenced in `Formula` must also appear in `FieldRefs` or the field creation fails.
Existing columns are skipped, never updated.

Because the CSV is comma-delimited and formulas are full of commas, **quote the Formula cell**.

---

## ListLookupColumns.csv → `06-AddLookupColumnsToList.ps1`

`Name,ParentList,ContentType,FieldType,Group,DisplayName,Mult,CreateColumn,ShowField`

| Column | Meaning |
|---|---|
| `Name` | Internal name of the lookup column. |
| `ParentList` | **Title** of the list being looked up *into* (the source of the values). |
| `ContentType` | Content type the lookup gets added to (the consuming side). |
| `FieldType` | `Lookup` or `LookupMulti`. |
| `Mult` | `TRUE` for LookupMulti, `FALSE` for Lookup. |
| `CreateColumn` | `Y` creates the site column. See trap below. |
| `ShowField` | Internal name of the column shown from the parent list. Defaults to `Title` if empty. |

**Two traps here.**

First, this script runs two passes: `CreateLookupField` honors `CreateColumn -eq "Y"` and skips
everything else, but `AddLookupColumnToList` runs for **every row regardless of `CreateColumn`**. A
row with `CreateColumn=N` will still try to attach the field to the content type. Set `CreateColumn`
to `Y` for normal rows; only use `N` when the site column genuinely already exists.

Second, `ParentList` is resolved with `Get-PnPList` at runtime, which is why this step runs after
`04-CreateLists.ps1`. A lookup pointing at a list that does not exist yet produces a null list ID
and a broken field.

---

## RemoveContentTypes.csv → `07-RemoveContentTypes.ps1`

`Name,ListName`

Almost always `Item,<List Title>` for every list — this strips the stock `Item` content type that
SharePoint attaches on list creation, leaving only the project content type. Safe to re-run;
failures are swallowed by `-ErrorAction SilentlyContinue`.

This must run after `04`, which sets the project content type as default. Removing `Item` before
another content type is the default will fail.

---

## DefaultListViews.csv → `08-DefaultListViews.ps1`

`ListName,ViewTitle,Columns`

**One column per row.** The script groups rows by `ListName` + `ViewTitle` and collects `Columns`
into the field list. Six columns on `All Items` means six rows, all repeating the same
`ListName,All Items`.

`Columns` holds a single **internal name**. Columns that do not exist on the list are reported and
skipped rather than failing the view.

If the view exists, the script **unions** the CSV fields into the existing view fields — it never
removes a column. It cannot reorder or remove; only add. `All Items` is the usual `ViewTitle`; a
title that does not exist creates a new view.

---

## ListIndexes.csv → `09-CreateListIndexes.ps1`

`ListName,FieldName`

One row per indexed field. `FieldName` is an internal name that must already exist on the list.
Missing fields warn and skip; already-indexed fields are left alone.

**SharePoint allows 20 indexes per list.** Index the fields the functional doc filters, sorts, or
groups by — typically the ID/key, the status, and the main category. Do not index everything.
