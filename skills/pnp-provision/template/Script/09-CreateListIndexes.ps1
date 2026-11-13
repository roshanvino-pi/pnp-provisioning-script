function CreateListIndexes {
    $indexRows = Import-Csv $CSVLocation

    foreach ($indexRow in $indexRows) {
        try {
            Write-Host "info: Checking index '$($indexRow.FieldName)' on '$($indexRow.ListName)'"
            $field = Get-PnPField -List $indexRow.ListName -Identity $indexRow.FieldName -ErrorAction SilentlyContinue

            if ($null -eq $field) {
                Write-Host "warning: Field '$($indexRow.FieldName)' was not found on '$($indexRow.ListName)'; index skipped" -ForegroundColor Yellow
                continue
            }

            if ($field.Indexed -eq $true) {
                Write-Host "info: Field '$($indexRow.FieldName)' is already indexed on '$($indexRow.ListName)'" -ForegroundColor Yellow
                continue
            }

            $field.Indexed = $true
            $field.Update()
            Invoke-PnPQuery
            Write-Host "info: Field '$($indexRow.FieldName)' indexed on '$($indexRow.ListName)'" -ForegroundColor Green
        }
        catch {
            Write-Host "info: Error indexing '$($indexRow.FieldName)' on '$($indexRow.ListName)': $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

CreateListIndexes
