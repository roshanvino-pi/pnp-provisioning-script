function CreateSiteColumns {
    
	$fields = Get-PnPField	
    #send the request containing all operations to the server
    try{
        write-host "info: Loaded all Site Columns" -foregroundcolor green
    }
    catch{
        write-host "info: $($_.Exception.Message)" -foregroundcolor red
    }
       
    #load CSV file
    $siteColumns = import-csv $CSVLocation
     
    #loop through each entry and create the columnGroup
    foreach ($column in $sitecolumns)
    {
		$columnExists = 0
        $existingField = $null
        #write-host "Excel Field name $($column.Title)"	
        #write-host "Internal Name $($field.internalname)  and  excel name $($column.Title)"	
     #check if column already exists
        foreach($field in $fields){
			
			if($columnExists -eq 0){
			    
				if ($field.internalname -eq $column.Title){
					$columnExists = 1
                    $existingField = $field
				}
				else{
                    
					$columnExists = 0
				}        
			}
			else{
				break
			}
        }

         $fieldAsXML=""
        if ($columnExists -eq 0){
            #create XML entry for a new field 
			if(($column.FieldType -eq "Choice") -or ($column.FieldType -eq "MultiChoice"))
			{
				$ChoiceOptions=[string]::Empty
				$Choices = $column.ChoiceValue.Split(",")
				foreach ($Choice in $Choices)
				{
					$ChoiceOptions = $ChoiceOptions + "<CHOICE>$Choice</CHOICE>"
				}
				
				$fieldAsXML = "<Field Type='$($column.FieldType)' 
								DisplayName='$($column.DisplayName)' 
								Name='$($column.Title)' 				
								ID='$([GUID]::NewGuid())'
								Group='$($column.Group)' 
								FillInChoice='False'>
								<CHOICES>$ChoiceOptions</CHOICES></Field>"				
			}			
			elseif($column.FieldType -eq "Note"){
				if($column.IsMulti -eq "Yes"){
					$fieldAsXML = "<Field Type='$($column.FieldType)' 
						DisplayName='$($column.DisplayName)' 
						ID='$([GUID]::NewGuid())'
						Name='$($column.Title)' 				
						Group='$($column.Group)' 
						RichText='TRUE' RichTextMode='FullHtml' IsolateStyles='TRUE' Sortable='FALSE' AppendOnly='FALSE'/>"
				}
            elseif($column.IsMulti -eq "Plain"){
					$fieldAsXML = "<Field Type='$($column.FieldType)' 
					DisplayName='$($column.DisplayName)' 
					ID='$([GUID]::NewGuid())'
					Name='$($column.Title)' 				
					Group='$($column.Group)' 
					RichText='FALSE'/>"
				}
				else{
					$fieldAsXML = "<Field Type='$($column.FieldType)' 
					DisplayName='$($column.DisplayName)' 
					ID='$([GUID]::NewGuid())'
					Name='$($column.Title)' 				
					Group='$($column.Group)' 
					RichText='TRUE' RichTextMode='Compatible' IsolateStyles='FALSE' Sortable='FALSE' AppendOnly='FALSE'/>"
				}				
			}
            elseif($column.FieldType -eq "UserMulti"){
                $fieldAsXML= "<Field Type='$($column.FieldType)' 
				DisplayName='$($column.DisplayName)' 
				ID='$([GUID]::NewGuid())'
				Name='$($column.Title)' 				
				Group='$($column.Group)' 
                List='UserInfo'
                UserSelectionMode='$($column.UserMode)' 
                Mult='TRUE' />"
                #Type='UserMulti' Name='TeamMembers' ID='$([GUID]::NewGuid())' DisplayName='Team Members' Required ='FALSE' UserSelectionMode='PeopleAndGroups' Mult='TRUE' ></Field>"

            }
            elseif($column.FieldType -eq "User"){
                # Add a User column as UserMulti if multiple selections allowed; otherwise add a column as User.
                if ($column.Mult -eq $true) {
                    $fieldAsXML= "<Field Type='UserMulti' 
				    DisplayName='$($column.DisplayName)' 
				    ID='$([GUID]::NewGuid())'
				    Name='$($column.Title)' 				
				    Group='$($column.Group)'
                    List='UserInfo'
                    UserSelectionMode='$($column.UserMode)' 
                    Mult='$($column.Mult)'/>"
                } else {
                    $fieldAsXML= "<Field Type='$($column.FieldType)' 
				    DisplayName='$($column.DisplayName)' 
				    ID='$([GUID]::NewGuid())'
				    Name='$($column.Title)' 				
				    Group='$($column.Group)' 
                    List='UserInfo'
                    UserSelectionMode='$($column.UserMode)'
                    Mult='$($column.Mult)'/>"
                    #UserSelectionMode='$($column.UserMode)' UserSelectionScope='0' Format='Dropdown' IsModern='TRUE' />"
                }
            }
            elseif($column.FieldType -eq "URL"){
                $fieldAsXML= "<Field Type='$($column.FieldType)' 
				DisplayName='$($column.DisplayName)' 
				ID='$([GUID]::NewGuid())'
				Name='$($column.Title)' 				
				Group='$($column.Group)' 
                Format='Hyperlink'/>"
            }
			else{
				$fieldAsXML = "<Field Type='$($column.FieldType)' 
				DisplayName='$($column.DisplayName)' 
				ID='$([GUID]::NewGuid())'
				Name='$($column.Title)' 				
				Group='$($column.Group)' />"
			} 
			#Add Site Column to list
			
			
			try{			
				Add-PnPFieldFromXml -FieldXml $fieldAsXML            
                write-host "info: column '$($column.Title)' created" -foregroundcolor green
                
            }
            catch{
                write-host $fieldAsXML
                write-host "info: $($_.Exception.Message)" -foregroundcolor red
                pause
            }
        }
        else{
			write-host "Info: The column '$($column.Title)' already exists." -foregroundcolor yellow

            if ((($column.FieldType -eq "Choice") -or ($column.FieldType -eq "MultiChoice")) -and $column.ChoiceValue -and $existingField) {
                $desiredChoices = @($column.ChoiceValue.Split(",") | ForEach-Object { $_.Trim() })
                $existingChoices = @($existingField.Choices)

                if (($desiredChoices -join "|") -ne ($existingChoices -join "|")) {
                    try {
                        $existingField.Choices = [string[]]$desiredChoices
                        $existingField.Update()
                        Invoke-PnPQuery
                        write-host "info: Choices updated for '$($column.Title)'" -foregroundcolor green
                    }
                    catch {
                        write-host "info: Unable to update choices for '$($column.Title)': $($_.Exception.Message)" -foregroundcolor red
                    }
                }
            }
            #pause
        }
    }
}

CreateSiteColumns
