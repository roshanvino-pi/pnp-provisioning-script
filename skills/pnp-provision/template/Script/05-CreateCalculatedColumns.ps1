function CreateCalculatedColumns {

    try {
        write-host "info: Loading Calculated Columns CSV" -foregroundcolor green
    }
    catch {
        write-host "info: $($_.Exception.Message)" -foregroundcolor red
    }

    # Load CSV file
    $calculatedColumns = Import-Csv $CSVLocation

    foreach ($col in $calculatedColumns) {
        try {
            Write-Host "Processing calculated column '$($col.DisplayName)' on list '$($col.ListName)'"

            # Check if the column already exists on the list
            $existingField = Get-PnPField -List $col.ListName -Identity $col.ColumnName -ErrorAction SilentlyContinue

            if ($existingField) {
                Write-Host "info: Calculated column '$($col.ColumnName)' already exists on list '$($col.ListName)'. Skipping." -ForegroundColor Yellow
                continue
            }

            # Build FieldRefs XML from comma-separated list in CSV
            $fieldRefsXml = ""
            if ($col.FieldRefs) {
                $refs = $col.FieldRefs.Split(",")
                foreach ($ref in $refs) {
                    $fieldRefsXml += "<FieldRef Name='$($ref.Trim())'/>"
                }
            }

            # Encode the formula for XML (special characters must be escaped)
            $formulaXml = $col.Formula
            $formulaXml = $formulaXml.Replace("&", "&amp;")
            $formulaXml = $formulaXml.Replace("<", "&lt;")
            $formulaXml = $formulaXml.Replace(">", "&gt;")

            # Escape single quotes in display name and group for XML attributes
            $displayNameXml = $col.DisplayName.Replace("'", "&apos;")
            $groupXml = $col.Group.Replace("'", "&apos;")

            # Build the calculated field XML
            $fieldXml = "<Field Type='Calculated' 
                            DisplayName='$displayNameXml' 
                            Name='$($col.ColumnName)' 
                            ID='$([GUID]::NewGuid())' 
                            Group='$groupXml' 
                            ResultType='$($col.ResultType)' 
                            ReadOnlyField='TRUE'>
                            <Formula>$formulaXml</Formula>
                            <FieldRefs>$fieldRefsXml</FieldRefs>
                        </Field>"

            Add-PnPFieldFromXml -List $col.ListName -FieldXml $fieldXml
            Write-Host "info: Calculated column '$($col.DisplayName)' created successfully on list '$($col.ListName)'" -ForegroundColor Green
        }
        catch {
            Write-Host "info: Error creating calculated column '$($col.ColumnName)' on list '$($col.ListName)': $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

CreateCalculatedColumns
