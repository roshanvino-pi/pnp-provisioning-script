
function CreateLookupField {
   
    try{
	    #Get All Site contentTypes
	    $fields = Get-PnPField
	
        #send the request containing all operations to the server
        write-host "info (CreateLookupField): Loaded all Fields" -foregroundcolor green
    }
    catch{
        write-host "info: $($_.Exception.Message)" -foregroundcolor red
    }
     
    #load CSV file
    $lookupColumns = import-csv $CSVLocation
     
    #loop through each entry and create the contentTypeGroup
    foreach ($lookupColumn in $lookupColumns){
    
        if($lookupColumn.CreateColumn -eq "Y")
        {
		    $columnExists = 0
            #check if contentType already exists
            foreach($field in $fields){
			    if($columnExists -eq 0){
				    if ($field.internalname -eq $lookupColumn.Name){
					    $columnExists = 1
				    }
				    else{
					    $columnExists = 0
				    }        
			    }
			    else{
				    break
			    }
            }
         
            if ($columnExists -eq 0){
                #create XML entry for a new field 
			
			    $LookupListID = (Get-PnPList -Identity $lookupColumn.ParentList).ID
			
			    # Use ShowField from CSV if provided, otherwise default to Title for backward compatibility
			    $showFieldValue = if ($lookupColumn.ShowField) { $lookupColumn.ShowField } else { "Title" }
			
			    $fieldAsXML = "<Field Type='$($lookupColumn.FieldType)' 
				    ID='$([GUID]::NewGuid())'
				    Name='$($lookupColumn.Name)' 				
				    Group='$($lookupColumn.Group)' 
				    DisplayName='$($lookupColumn.DisplayName)'
				    List='$LookupListID'
				    ShowField='$showFieldValue' Mult='$($lookupColumn.Mult)'/>"

			    try{				
			        #Add Site Column to list
			        Add-PnPFieldFromXml -FieldXml $fieldAsXML    
			
                    write-host "info: Lookup Column $($lookupColumn.Name) created" -foregroundcolor green
                }
                catch{
                    write-host "info: $($_.Exception.Message)" -foregroundcolor red
                }
            }
            else{
			    write-host "Info: The Lookup Column $($contentType.Name) already exists." -foregroundcolor red
            }
        }
    }
}





function AddLookupColumnToList {
   #load CSV file
    $lookupColumns = import-csv $CSVLocation
     
    #loop through each entry and create the fieldContentTypeGroup
    foreach ($lookupColumn in $lookupColumns){
		$columnExists = 0
		
        Write-host "Adding Column $($lookupColumn.Name) to Content Type : " $lookupColumn.ContentType
        #Get ContentType already exists
        $contentType = Get-PnPContentType -Identity $lookupColumn.ContentType
		
		#Get Fields in content type
		$fields = Get-PnPProperty -clientobject $contentType -property "Fields"
		
		foreach($field in $fields){
			if($columnExists -eq 0){
				if ($field.Name -eq $lookupColumn.Name){
					$columnExists = 1
				}
				else{
					$columnExists = 0
				}        
			}
			else{
				break
			}
        }
         
        if ($columnExists -eq 0){
            #Add field to Content Type
			try{
			    Add-PnPfieldToContentType -Field $lookupColumn.Name -ContentType $contentType
                write-host "info: lookupColumn $($lookupColumn.Name) Added to Content Type $($lookupColumn.ContentType)" -foregroundcolor green
            }
            catch{
                write-host "info: $($_.Exception.Message)" -foregroundcolor red
            }
        }
        else{
			write-host "Info: The lookupColumn $($lookupColumn.Title) already added to Content Type." -foregroundcolor red
        }
    }
}

CreateLookupField
AddLookupColumnToList

