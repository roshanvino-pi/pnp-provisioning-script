function CreateContentTypes {
 	$parentContentTypeName = $parentDocumentContentTypeName
    #$parentContentTypeID = "0x010100C66B15A57FA9BB459645ED3178E703D5"
	#Get All Site contentTypes
    $allcontenttypes = Get-PnPContentType
	#$allcontenttypes  | Select-Object Name
    #send the request containing all operations to the server
    try{
        write-host "info: Loaded all Site Content Type" -foregroundcolor green
    }
    catch{
        write-host "info: $($_.Exception.Message)" -foregroundcolor red
    }
     
    #Get the Parent content type
    $ParentContentType = Get-PnPContentType -Identity $parentContentTypeName -ErrorAction SilentlyContinue
    Write-Host "parent content type"
    if ($null -ne $ParentContentType) {
        Write-Host $ParentContentType.Name
    } else {
        Write-Host "Warning: Parent content type '$parentContentTypeName' not found. Content types with ParentContentType=Document will be skipped." -ForegroundColor Yellow
    }
    #load CSV file
    $contentTypes = import-csv $CSVLocation
    #loop through each entry and create the contentTypeGroup
    foreach ($contentType in $contentTypes){
		#$contentTypeExists = 0
        #Get ContentType already exists
        $contentTypeExists = Get-PnPContentType -Identity $contentType.Name -ErrorAction SilentlyContinue

        if ($contentTypeExists){
            write-host "Info: The contentType '$($contentType.Name)' already exists." -foregroundcolor red
        }
		else{

            try{
                #Write-Host $contentType.Name
                #Write-Host $contentType.ParentContentType
                #create XML entry for a new field
                if($contentType.ParentContentType -eq "Document") {
                    if ($null -eq $ParentContentType) {
                        write-host "Warning: Skipping '$($contentType.Name)' - parent '$parentContentTypeName' not found." -foregroundcolor yellow
                    } else {
			            $newCType=Add-PnPContentType -Name $contentType.Name -Group $contentType.Group -Description $contentType.Description -ParentContentType $ParentContentType
					    write-host "info: contentType '$($contentType.Name)' created with '$($parentContentTypeName)'" -foregroundcolor green
                    }
                }
                else{
                    $newCType=Add-PnPContentType -Name $contentType.Name -Group $contentType.Group -Description $contentType.Description
					write-host "info: contentType '$($contentType.Name)' created with Item Parent" -foregroundcolor green
                }

                
            }
            catch{
                write-host "info: $($_.Exception.Message)" -foregroundcolor red
            }
        }
    }
}
CreateContentTypes