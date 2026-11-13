function Set-OptionalRequiredFields {
    param(
        [Parameter(Mandatory = $true)]
        $List
    )

    $requiredFields = Get-PnPField -List $List | Where-Object {
        $_.Required -eq $true `
            -and $_.Title -ne "Name" `
            -and $_.ReadOnlyField -eq $false `
            -and $_.Hidden -eq $false `
            -and $_.InternalName -ne "ContentType" `
            -and $_.InternalName -ne "Attachments"
    }

    foreach ($field in $requiredFields) {
        $field.Required = $false
        $field.Update()
        Invoke-PnPQuery
        Write-Host "info: Required flag cleared for '$($field.Title)' on '$($List.Title)'" -ForegroundColor Green
    }
}

function Add-ListContentType {
    param(
        [Parameter(Mandatory = $true)]
        $List,

        [Parameter(Mandatory = $true)]
        [string]$ContentTypeName
    )

    $contentType = Get-PnPContentType -Identity $ContentTypeName -ErrorAction SilentlyContinue
    $listContentTypes = Get-PnPContentType -List $List
    $contentTypeExistsOnList = $listContentTypes | Where-Object { $_.Name -eq $contentType.Name }

    if ($contentTypeExistsOnList) {
        Write-Host "info: Content type '$ContentTypeName' already exists on '$($List.Title)'" -ForegroundColor Yellow
    }
    else {
        Add-PnPContentTypeToList -List $List -ContentType $contentType -DefaultContentType | Out-Null
        Write-Host "info: Content type '$ContentTypeName' added to '$($List.Title)'" -ForegroundColor Green
    }
}

function CreateLists {
    Write-Host "info: Create Lists" -ForegroundColor Green

    $lists = Import-Csv $CSVLocation

    foreach ($listDefinition in $lists) {
        try {
            Write-Host "info: Checking list '$($listDefinition.Title)'"

            $targetList = Get-PnPList -Identity $listDefinition.Url -ErrorAction SilentlyContinue

            if ($null -eq $targetList) {
                $targetList = Get-PnPList -Identity $listDefinition.Title -ErrorAction SilentlyContinue
            }

            if ($null -eq $targetList) {
                New-PnPList -Title $listDefinition.Title -Template $listDefinition.Template -Url $listDefinition.Url | Out-Null
                $targetList = Get-PnPList -Identity $listDefinition.Url -ErrorAction SilentlyContinue
                Write-Host "info: List '$($listDefinition.Title)' created" -ForegroundColor Green
            }
            else {
                Write-Host "info: List '$($listDefinition.Title)' already exists; reusing it" -ForegroundColor Yellow
            }

            Set-PnPList -Identity $targetList -EnableContentTypes $true -EnableVersioning $true -MajorVersions 100 | Out-Null
            Set-OptionalRequiredFields -List $targetList
            Add-ListContentType -List $targetList -ContentTypeName $listDefinition.ContentType
        }
        catch {
            Write-Host "info: Error provisioning list '$($listDefinition.Title)': $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

CreateLists
