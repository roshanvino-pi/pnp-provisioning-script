function RemoveContentTypes {
 	
    #load CSV file
    $contentTypes = import-csv $CSVLocation
    #loop through each entry and create the contentTypeGroup
    foreach ($contentType in $contentTypes){
		#$contentTypeExists = 0
        #Get ContentType already exists
         write-host "Removing contentType $($contentType.Name) from  $($contentType.ListName)" -foregroundcolor Green
           
            Remove-PnPContentTypeFromList -List $contentType.ListName -ContentType $contentType.Name  -ErrorAction SilentlyContinue
        
    }
}
RemoveContentTypes