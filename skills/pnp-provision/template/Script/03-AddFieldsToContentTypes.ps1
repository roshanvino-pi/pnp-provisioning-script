function AddFieldsToContentType {
    
	#load CSV file
    $fieldfieldContentTypes = import-csv $CSVLocation
    
    Write-host $CSVLocation

    #Write-host $fieldfieldContentTypes

     
    #loop through each entry and create the fieldContentTypeGroup
    foreach ($fieldContentType in $fieldfieldContentTypes){
		$fieldContentTypeExists = 0
		Write-host $fieldContentType.FieldName

        #Write-host $fieldContentType.ContentType
        #Get ContentType already exists
        $contentType = Get-PnPContentType -Identity $fieldContentType.ContentType
		
        write-host " ContentType Exists:  $($contentType.Name) "

		#Get Fields in content type
		$fields = Get-PnPProperty -clientobject $contentType -property "Fields"
		
		foreach($field in $fields){
			if($fieldContentTypeExists -eq 0){
				if ($field.Name -eq $fieldContentType.FieldName){
					$fieldContentTypeExists = 1
				}
				else{
					$fieldContentTypeExists = 0
				}        
			}
			else{
				break
			}
        }
         
        if ($fieldContentTypeExists -eq 0){
            #Add field to Content Type
			try{	

			    Add-PnPfieldToContentType -Field $fieldContentType.FieldName -ContentType $contentType

                write-host "info: FieldName '$($fieldContentType.FieldName)' Added" -foregroundcolor green
            }
            catch{
                write-host "info: $($_.Exception.Message)" -foregroundcolor red
            }
        }
        else{
			write-host "Info: FieldName '$($fieldContentType.FieldName)' already exists." -foregroundcolor red
        }
    }
}


AddFieldsToContentType
