#Requires -Version 5.1
<#
.SYNOPSIS
    Offline validator for a generated PnP Schema folder.

.DESCRIPTION
    Cross-checks the eight CSVs against each other and against what the scripts in Script/ actually
    read. Catches broken references before they surface mid-run against a live tenant. Connects to
    nothing and changes nothing.

.EXAMPLE
    pwsh -File Validate-Schema.ps1 -SchemaPath .\PnPScript\Schema
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$SchemaPath
)

$ErrorActionPreference = 'Stop'

$script:errors   = @()
$script:warnings = @()

function Add-Failure { param([string]$m) $script:errors   += $m }
function Add-Warning { param([string]$m) $script:warnings += $m }

# Built-in fields always present on a list; never declared in SiteColumns.csv.
$builtInFields = @(
    'Title', 'ID', 'Created', 'Modified', 'Author', 'Editor',
    'Attachments', 'ContentType', 'Name', 'FileLeafRef', 'DocIcon', 'LinkTitle', 'Edit'
)

$validFieldTypes = @(
    'Text', 'Note', 'Number', 'Currency', 'DateTime', 'Boolean',
    'Choice', 'MultiChoice', 'User', 'UserMulti', 'URL', 'Lookup', 'LookupMulti'
)

$expectedHeaders = @{
    'SiteColumns.csv'           = @('Title', 'DisplayName', 'Group', 'FieldType', 'ChoiceValue', 'IsMulti', 'UserMode', 'Mult')
    'ContentTypes.csv'          = @('Name', 'Group', 'Description', 'ParentContentType')
    'AddFieldsToContentType.csv' = @('FieldName', 'ContentType')
    'Lists.csv'                 = @('Url', 'Title', 'Template', 'ContentType')
    'CalculatedColumns.csv'     = @('ListName', 'ColumnName', 'DisplayName', 'Group', 'Formula', 'ResultType', 'FieldRefs')
    'ListLookupColumns.csv'     = @('Name', 'ParentList', 'ContentType', 'FieldType', 'Group', 'DisplayName', 'Mult', 'CreateColumn', 'ShowField')
    'RemoveContentTypes.csv'    = @('Name', 'ListName')
    'DefaultListViews.csv'      = @('ListName', 'ViewTitle', 'Columns')
    'ListIndexes.csv'           = @('ListName', 'FieldName')
}

# --- Load -------------------------------------------------------------------

if (-not (Test-Path $SchemaPath)) {
    Write-Host "FATAL: Schema path not found: $SchemaPath" -ForegroundColor Red
    exit 1
}

$data = @{}

foreach ($fileName in $expectedHeaders.Keys) {
    $path = Join-Path $SchemaPath $fileName

    if (-not (Test-Path $path)) {
        Add-Failure "$fileName is missing. MainScript.ps1 runs all nine steps unconditionally; Import-Csv throws on a missing file."
        $data[$fileName] = @()
        continue
    }

    $rows = @(Import-Csv $path)
    $data[$fileName] = $rows

    # Header check works off the first row's properties; a header-only CSV is legal and skipped here.
    if ($rows.Count -gt 0) {
        $actual = @($rows[0].PSObject.Properties.Name)
        $missing = @($expectedHeaders[$fileName] | Where-Object { $_ -notin $actual })
        if ($missing.Count -gt 0) {
            Add-Failure "$fileName is missing column(s): $($missing -join ', '). The script reads these by name and silently gets `$null."
        }
    }
}

$siteColumns   = $data['SiteColumns.csv']
$contentTypes  = $data['ContentTypes.csv']
$fieldMappings = $data['AddFieldsToContentType.csv']
$lists         = $data['Lists.csv']
$calcColumns   = $data['CalculatedColumns.csv']
$lookupColumns = $data['ListLookupColumns.csv']
$removeCTs     = $data['RemoveContentTypes.csv']
$views         = $data['DefaultListViews.csv']
$indexes       = $data['ListIndexes.csv']

$contentTypeNames = @($contentTypes | ForEach-Object { $_.Name })
$listTitles       = @($lists | ForEach-Object { $_.Title })
$siteColumnNames  = @($siteColumns | ForEach-Object { $_.Title })
$lookupNames      = @($lookupColumns | ForEach-Object { $_.Name })

# --- SiteColumns.csv --------------------------------------------------------

$seenColumns = @{}
foreach ($col in $siteColumns) {
    $name = $col.Title

    if ([string]::IsNullOrWhiteSpace($name)) {
        Add-Failure "SiteColumns.csv: a row has an empty Title (internal name)."
        continue
    }

    if ($seenColumns.ContainsKey($name)) {
        Add-Failure "SiteColumns.csv: '$name' is declared more than once."
    }
    $seenColumns[$name] = $true

    if ($name -notmatch '^[A-Za-z][A-Za-z0-9_]*$') {
        Add-Failure "SiteColumns.csv: internal name '$name' is invalid. Must start with a letter and contain only letters, digits, underscore."
    }

    if ($name.Length -gt 32) {
        Add-Warning "SiteColumns.csv: internal name '$name' exceeds 32 chars; SharePoint may truncate it."
    }

    if ($col.FieldType -notin $validFieldTypes) {
        Add-Failure "SiteColumns.csv: '$name' has unrecognized FieldType '$($col.FieldType)'. 01-CreateSiteColumns.ps1 would fall through to the generic branch."
    }

    if ($col.FieldType -in @('Choice', 'MultiChoice')) {
        if ([string]::IsNullOrWhiteSpace($col.ChoiceValue)) {
            Add-Failure "SiteColumns.csv: '$name' is $($col.FieldType) but ChoiceValue is empty."
        }
    }
    elseif (-not [string]::IsNullOrWhiteSpace($col.ChoiceValue)) {
        Add-Warning "SiteColumns.csv: '$name' is $($col.FieldType) but has a ChoiceValue; it will be ignored."
    }

    if ($col.FieldType -in @('User', 'UserMulti')) {
        if ($col.UserMode -notin @('PeopleOnly', 'PeopleAndGroups')) {
            Add-Failure "SiteColumns.csv: '$name' is $($col.FieldType) but UserMode is '$($col.UserMode)'. Must be PeopleOnly or PeopleAndGroups."
        }
    }

    if ($col.FieldType -eq 'Note' -and -not [string]::IsNullOrWhiteSpace($col.IsMulti)) {
        if ($col.IsMulti -notin @('Yes', 'Plain')) {
            Add-Warning "SiteColumns.csv: '$name' has IsMulti='$($col.IsMulti)'. Only 'Yes' and 'Plain' are recognized; anything else takes the default rich-text branch."
        }
    }

    if ($col.FieldType -in @('Lookup', 'LookupMulti')) {
        Add-Failure "SiteColumns.csv: '$name' is a lookup. Lookups belong in ListLookupColumns.csv, which resolves the parent list ID at runtime."
    }
}

# --- ContentTypes.csv -------------------------------------------------------

foreach ($ct in $contentTypes) {
    if ([string]::IsNullOrWhiteSpace($ct.Name)) {
        Add-Failure "ContentTypes.csv: a row has an empty Name."
        continue
    }
    if ($ct.ParentContentType -notin @('Item', 'Document')) {
        Add-Warning "ContentTypes.csv: '$($ct.Name)' has ParentContentType='$($ct.ParentContentType)'. 02-CreateContentTypes.ps1 compares against 'Document' exactly; anything else takes the Item branch."
    }
}

$dupCTs = @($contentTypeNames | Group-Object | Where-Object { $_.Count -gt 1 })
foreach ($d in $dupCTs) { Add-Failure "ContentTypes.csv: '$($d.Name)' is declared more than once." }

# --- AddFieldsToContentType.csv ---------------------------------------------

foreach ($m in $fieldMappings) {
    if ($m.FieldName -notin $siteColumnNames -and $m.FieldName -notin $builtInFields) {
        Add-Failure "AddFieldsToContentType.csv: field '$($m.FieldName)' is not declared in SiteColumns.csv."
    }
    if ($m.ContentType -notin $contentTypeNames) {
        Add-Failure "AddFieldsToContentType.csv: content type '$($m.ContentType)' is not declared in ContentTypes.csv."
    }
}

$orphans = @($siteColumnNames | Where-Object { $_ -notin @($fieldMappings | ForEach-Object { $_.FieldName }) })
foreach ($o in $orphans) {
    Add-Warning "SiteColumns.csv: '$o' is created but never attached to a content type in AddFieldsToContentType.csv."
}

# --- Lists.csv --------------------------------------------------------------

foreach ($list in $lists) {
    if ($list.ContentType -notin $contentTypeNames) {
        Add-Failure "Lists.csv: list '$($list.Title)' references content type '$($list.ContentType)', not declared in ContentTypes.csv."
    }
    if ($list.Template -notin @('GenericList', 'DocumentLibrary')) {
        Add-Warning "Lists.csv: list '$($list.Title)' has Template='$($list.Template)'; expected GenericList or DocumentLibrary."
    }
    if ($list.Url -match '\s') {
        Add-Failure "Lists.csv: Url '$($list.Url)' contains a space."
    }
    if ($list.Url -match '^/') {
        Add-Warning "Lists.csv: Url '$($list.Url)' starts with '/'; the reference package uses a relative form like 'lists/HardwareAssets'."
    }
}

$dupTitles = @($listTitles | Group-Object | Where-Object { $_.Count -gt 1 })
foreach ($d in $dupTitles) { Add-Failure "Lists.csv: list title '$($d.Name)' is declared more than once; other CSVs reference lists by Title." }

# Resolve the fields available on each list: content-type fields + calc + lookups + built-ins.
$listFields = @{}
foreach ($list in $lists) {
    $ctFields = @($fieldMappings | Where-Object { $_.ContentType -eq $list.ContentType } | ForEach-Object { $_.FieldName })
    $lkFields = @($lookupColumns | Where-Object { $_.ContentType -eq $list.ContentType } | ForEach-Object { $_.Name })
    $cxFields = @($calcColumns   | Where-Object { $_.ListName    -eq $list.Title       } | ForEach-Object { $_.ColumnName })
    $listFields[$list.Title] = @($ctFields + $lkFields + $cxFields + $builtInFields | Select-Object -Unique)
}

# --- CalculatedColumns.csv --------------------------------------------------

foreach ($c in $calcColumns) {
    if ($c.ListName -notin $listTitles) {
        Add-Failure "CalculatedColumns.csv: '$($c.ColumnName)' targets list '$($c.ListName)', not declared in Lists.csv."
        continue
    }
    if ($c.ResultType -notin @('Text', 'Number', 'DateTime', 'Boolean', 'Currency')) {
        Add-Failure "CalculatedColumns.csv: '$($c.ColumnName)' has ResultType='$($c.ResultType)'."
    }
    if (-not [string]::IsNullOrWhiteSpace($c.FieldRefs)) {
        foreach ($ref in $c.FieldRefs.Split(',')) {
            $r = $ref.Trim()
            if ($r -and $r -notin $listFields[$c.ListName]) {
                Add-Failure "CalculatedColumns.csv: '$($c.ColumnName)' references '$r' in FieldRefs, which is not available on list '$($c.ListName)'."
            }
        }
    }
    # Every [Bracketed] token in the formula must be declared in FieldRefs.
    $tokens = @([regex]::Matches($c.Formula, '\[([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value })
    $declared = @()
    if (-not [string]::IsNullOrWhiteSpace($c.FieldRefs)) {
        $declared = @($c.FieldRefs.Split(',') | ForEach-Object { $_.Trim() })
    }
    foreach ($t in ($tokens | Select-Object -Unique)) {
        if ($t -notin $declared) {
            Add-Failure "CalculatedColumns.csv: '$($c.ColumnName)' uses [$t] in Formula but does not list it in FieldRefs. Field creation will fail."
        }
    }
}

# --- ListLookupColumns.csv --------------------------------------------------

foreach ($lk in $lookupColumns) {
    if ($lk.ParentList -notin $listTitles) {
        Add-Failure "ListLookupColumns.csv: '$($lk.Name)' points at ParentList '$($lk.ParentList)', not declared in Lists.csv. Get-PnPList would return null and the field would be broken."
    }
    if ($lk.ContentType -notin $contentTypeNames) {
        Add-Failure "ListLookupColumns.csv: '$($lk.Name)' targets content type '$($lk.ContentType)', not declared in ContentTypes.csv."
    }
    if ($lk.FieldType -notin @('Lookup', 'LookupMulti')) {
        Add-Failure "ListLookupColumns.csv: '$($lk.Name)' has FieldType='$($lk.FieldType)'. Must be Lookup or LookupMulti."
    }
    if ($lk.FieldType -eq 'LookupMulti' -and $lk.Mult -notmatch '^(?i)true$') {
        Add-Failure "ListLookupColumns.csv: '$($lk.Name)' is LookupMulti but Mult='$($lk.Mult)'. Set Mult=TRUE."
    }
    if ($lk.FieldType -eq 'Lookup' -and $lk.Mult -match '^(?i)true$') {
        Add-Failure "ListLookupColumns.csv: '$($lk.Name)' is Lookup but Mult=TRUE. Use FieldType=LookupMulti."
    }
    if ($lk.CreateColumn -ne 'Y') {
        Add-Warning "ListLookupColumns.csv: '$($lk.Name)' has CreateColumn='$($lk.CreateColumn)'. 06 skips creating the field but STILL tries to attach it to '$($lk.ContentType)'. Use Y unless the column already exists on the site."
    }
    if ($lk.Name -in $siteColumnNames) {
        Add-Failure "ListLookupColumns.csv: '$($lk.Name)' is also declared in SiteColumns.csv. Declare a lookup in exactly one place."
    }
    # ShowField must exist on the parent list; empty is fine (defaults to Title).
    if (-not [string]::IsNullOrWhiteSpace($lk.ShowField) -and $lk.ParentList -in $listTitles) {
        if ($lk.ShowField -notin $listFields[$lk.ParentList]) {
            Add-Failure "ListLookupColumns.csv: '$($lk.Name)' has ShowField='$($lk.ShowField)', which is not available on parent list '$($lk.ParentList)'."
        }
    }
}

# --- RemoveContentTypes.csv -------------------------------------------------

foreach ($r in $removeCTs) {
    if ($r.ListName -notin $listTitles) {
        Add-Failure "RemoveContentTypes.csv: list '$($r.ListName)' is not declared in Lists.csv."
    }
}

foreach ($list in $lists) {
    $hasRemoval = @($removeCTs | Where-Object { $_.ListName -eq $list.Title -and $_.Name -eq 'Item' })
    if ($hasRemoval.Count -eq 0 -and $list.Template -eq 'GenericList') {
        Add-Warning "RemoveContentTypes.csv: no 'Item' removal row for list '$($list.Title)'. The stock Item content type will remain attached."
    }
}

# --- DefaultListViews.csv ---------------------------------------------------

foreach ($v in $views) {
    if ($v.ListName -notin $listTitles) {
        Add-Failure "DefaultListViews.csv: list '$($v.ListName)' is not declared in Lists.csv."
        continue
    }
    if ([string]::IsNullOrWhiteSpace($v.Columns)) { continue }
    if ($v.Columns -match ',') {
        Add-Failure "DefaultListViews.csv: '$($v.ListName)'/'$($v.ViewTitle)' has multiple columns in one cell ('$($v.Columns)'). 08 reads ONE column per row."
    }
    elseif ($v.Columns -notin $listFields[$v.ListName]) {
        Add-Warning "DefaultListViews.csv: column '$($v.Columns)' is not available on list '$($v.ListName)'; 08 will skip it."
    }
}

# --- ListIndexes.csv --------------------------------------------------------

foreach ($ix in $indexes) {
    if ($ix.ListName -notin $listTitles) {
        Add-Failure "ListIndexes.csv: list '$($ix.ListName)' is not declared in Lists.csv."
        continue
    }
    if ($ix.FieldName -notin $listFields[$ix.ListName]) {
        Add-Warning "ListIndexes.csv: field '$($ix.FieldName)' is not available on list '$($ix.ListName)'; 09 will skip it."
    }
}

foreach ($g in @($indexes | Group-Object -Property ListName)) {
    if ($g.Count -gt 20) {
        Add-Failure "ListIndexes.csv: list '$($g.Name)' has $($g.Count) indexes. SharePoint allows a maximum of 20 per list."
    }
}

# --- Report -----------------------------------------------------------------

Write-Host ""
Write-Host "Validated $SchemaPath" -ForegroundColor Cyan
Write-Host "  $($siteColumns.Count) site columns, $($contentTypes.Count) content types, $($lists.Count) lists, $($lookupColumns.Count) lookups, $($calcColumns.Count) calculated, $($indexes.Count) indexes"
Write-Host ""

foreach ($w in $script:warnings) { Write-Host "WARN  $w" -ForegroundColor Yellow }
if ($script:warnings.Count -gt 0) { Write-Host "" }

foreach ($e in $script:errors) { Write-Host "ERROR $e" -ForegroundColor Red }

Write-Host ""
if ($script:errors.Count -eq 0) {
    Write-Host "PASS - $($script:warnings.Count) warning(s), 0 errors." -ForegroundColor Green
    exit 0
}
else {
    Write-Host "FAIL - $($script:errors.Count) error(s), $($script:warnings.Count) warning(s)." -ForegroundColor Red
    exit 1
}
