param(
    [string]$SiteUrl = "{{SITE_URL}}"
)

Clear-Host

Set-Location $PSScriptRoot

# Now all relative paths will work from here
Write-Host "Current script location: $PSScriptRoot"

$siteURL = $SiteUrl #Dev

#$siteURL = "" #PRE

#$siteURL = "" #PROD

##For Parent Sites
$parentDocumentContentTypeName = "Document"

##For Subsite, create 'Local Document Content Type' manually before running this script. Request this action during deployment.
##$parentDocumentContentTypeName = "Local Document Content Type"


$ErrorActionPreference = 'SilentlyContinue'

#Connect-PnPOnline -Url $siteURL -Interactive
Connect-PnPOnline -Url $siteURL -UseWebLogin

# Files need to read to create Site Columns
write-host "Starting Site Column scripts" -foregroundcolor green
$CSVLocation = "Schema\SiteColumns.csv"
.\Script\01-CreateSiteColumns.ps1
write-host "Site Columns created" -foregroundcolor yellow

###Pause
# Files need to read to create Content Types
write-host "Starting Content Types scripts" -foregroundcolor green
$CSVLocation = "Schema\ContentTypes.csv"
.\Script\02-CreateContentTypes.ps1
write-host "Site Content types created" -foregroundcolor yellow

###Pause
# Files need to read to Add Fields to Content Type
write-host "Starting Add site columns to content type" -foregroundcolor green
$CSVLocation = "Schema\AddFieldsToContentType.csv"
.\Script\03-AddFieldsToContentTypes.ps1
write-host "Site columns added to Content types" -foregroundcolor yellow

###Pause
# Files need to read to create list
write-host "Starting list creation scripts" -foregroundcolor green
$CSVLocation = "Schema\Lists.csv"     	
.\Script\04-CreateLists.ps1
write-host "Lists creation completed" -foregroundcolor yellow

###Pause
# Files need to read to create calculated columns on lists
write-host "Starting calculated columns creation script" -foregroundcolor green
$CSVLocation = "Schema\CalculatedColumns.csv"
.\Script\05-CreateCalculatedColumns.ps1
write-host "Calculated columns created" -foregroundcolor yellow

###Pause
# Files need to read to create lookup columns
write-host "Starting lookup columns creation script" -foregroundcolor green
$CSVLocation = "Schema\ListLookupColumns.csv"     	
.\Script\06-AddLookupColumnsToList.ps1
write-host "Lookup columns created against content types" -foregroundcolor yellow

###Pause
# Files need to read to remove content types
write-host "Removing item content types" -foregroundcolor green
$CSVLocation = "Schema\RemoveContentTypes.csv"    	
.\Script\07-RemoveContentTypes.ps1
write-host "Removing item content types completed" -foregroundcolor yellow

###Pause
# Files need to read to add columns in views of list 
write-host "Starting adding column to list default view scripts" -foregroundcolor green
$CSVLocation = "Schema\DefaultListViews.csv"
.\Script\08-DefaultListViews.ps1
write-host "Default views columns are enabled" -foregroundcolor yellow

###Pause
# Files need to read to create list indexes
write-host "Starting list index creation script" -foregroundcolor green
$CSVLocation = "Schema\ListIndexes.csv"
.\Script\09-CreateListIndexes.ps1
write-host "List indexes are enabled" -foregroundcolor yellow


Write-Host "All done"

Disconnect-PnPOnline
