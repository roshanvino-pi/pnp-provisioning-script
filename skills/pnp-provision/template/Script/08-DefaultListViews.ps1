function CreateDefaultListViews {
    #load CSV file
    $viewRows = Import-Csv $CSVLocation
    $viewGroups = $viewRows | Group-Object -Property ListName, ViewTitle

    foreach ($viewGroup in $viewGroups) {
        $firstRow = $viewGroup.Group[0]
        $listName = $firstRow.ListName
        $viewTitle = $firstRow.ViewTitle
        $desiredFields = @(
            $viewGroup.Group |
                ForEach-Object { $_.Columns } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique
        )

        try {
            Write-Host "list $listName View - $viewTitle columns $($desiredFields -join ', ')"

            $availableFields = @(
                Get-PnPField -List $listName |
                    ForEach-Object { $_.InternalName }
            )

            $validFields = @()
            foreach ($fieldName in $desiredFields) {
                if ($availableFields -contains $fieldName) {
                    $validFields += $fieldName
                }
                else {
                    Write-Host "info: Column '$fieldName' does not exist on '$listName'; skipping it for '$viewTitle'" -ForegroundColor Yellow
                }
            }

            if ($validFields.Count -eq 0) {
                Write-Host "info: No valid columns found for '$viewTitle' on '$listName'; view skipped" -ForegroundColor Yellow
                continue
            }

            $view = Get-PnPView -List $listName -Identity $viewTitle -ErrorAction SilentlyContinue

            if ($null -eq $view) {
                Add-PnPView -List $listName -Title $viewTitle -Fields $validFields | Out-Null
                Write-Host "info: list $listName $viewTitle created" -ForegroundColor Green
                continue
            }

            $existingFields = @($view.ViewFields)
            $updatedFields = @(
                $existingFields + $validFields |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    Select-Object -Unique
            )

            Set-PnPView -List $listName -Identity $viewTitle -Fields $updatedFields | Out-Null
            Write-Host "info: list $listName $viewTitle updated" -ForegroundColor Green
        }
        catch {
            Write-Host "info: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

CreateDefaultListViews
