﻿Function Add-SPRListItem {
 <#
.SYNOPSIS
    Adds items to a SharePoint list using a Web service proxy object.
    
.DESCRIPTION
    Adds items to a SharePoint list using a Web service proxy object.
    
.PARAMETER Uri
    The address to the web application. You can also pass a hostname and it'll figure it out.

.PARAMETER ListName
    The human readable list name. So 'My List' as opposed to 'MyList', unless you named it MyList.
   
.PARAMETER Credential
    Provide alternative credentials to the web service. Otherwise, it will use default credentials. 
 
.PARAMETER IntputObject
    Allows piping from Get-SPRList
    
.PARAMETER EnableException
    By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
    This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
    Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
 
.PARAMETER WhatIf
    If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

.PARAMETER Confirm
    If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

.EXAMPLE
    $csv = Import-Csv -Path C:\temp\listitems.csv
    Add-SPRListData -Uri intranet.ad.local -ListName 'My List' -InputObject $mycsv

    Imports data from listitems.csv into the My List SharePoint list, so long as there are matching columns.
    
.EXAMPLE
    $csv = Import-Csv -Path C:\temp\listitems.csv
    Add-SPRListData -Uri intranet.ad.local -ListName 'My List' -InputObject $mycsv

    Imports data from listitems.csv into the My List SharePoint list, so long as there are matching columns.
    
.EXAMPLE
    $object = @()
    $object += [pscustomobject]@{ Title = 'Hello'; TestColumn = 'Sample Data'; }
    $object += [pscustomobject]@{ Title = 'Hello2'; TestColumn = 'Sample Data2'; }
    $object += [pscustomobject]@{ Title = 'Hello3'; TestColumn = 'Sample Data3'; }
    Add-SPRListData -Uri intranet.ad.local -ListName 'My List' -InputObject $mycsv

    Imports data from a custom object $object into the My List SharePoint list, so long as there are matching columns (Title and TestColumn).
#>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, HelpMessage = "SharePoint lists.asmx?wsdl location")]
        [string]$Uri,
        [Parameter(Mandatory, HelpMessage = "Human-readble SharePoint list name")]
        [string]$ListName,
        [PSCredential]$Credential,
        [parameter(ValueFromPipeline)]
        [object[]]$InputObject,
        [switch]$EnableException
    )
    begin {
        function Add-Row {
            [cmdletbinding()]
            param (
                [object[]]$Row,
                [object[]]$ColumnInfo
            )
            $collection = @()
            foreach ($currentrow in $row) {
                $columns = $currentrow.PsObject.Members | Where-Object MemberType -eq NoteProperty | Select-Object -ExpandProperty Name
                
                foreach ($fieldname in $columns) {
                    $datatype = ($ColumnInfo | Where-Object Name -eq $fieldname).Type
                    if ($type -eq 'DateTime') {
                        $value = (($currentrow.$fieldname).ToUniversalTime()).ToString("yyyy-MM-ddTHH:mm:ssZ")
                    }
                    else {
                        $value = [System.Security.SecurityElement]::Escape($currentrow.$fieldname)
                    }
                    
                    Write-PSFMessage -Level Verbose -Message "Adding $fieldname to row"
                    $collection += "<Field Name='$fieldname'>$value</Field>"
                }
            }
            $collection
        }
        $xml = @()
    }
    process {
        $list = Get-SPRList -Uri $Uri -Credential $Credential -ListName $ListName
        $columns = $list | Get-SPRColumnDetail | Where-Object Type -ne Computed | Sort-Object Listname, DisplayName
        
        foreach ($row in $InputObject) {
            $start = "<Method ID='1' Cmd='New'><Field Name='ID'>New</Field>"
            $middle = Add-Row -Row $row -ColumnInfo $columns
            $end = "</Method>"
            $xml += "$start $middle $end"
            Write-PSFMessage -Level Verbose -Message "Queued row for $listname"
        }
    }
    end {
        $list.BatchElement.InnerXml = $xml -join ""
        
        if ($Pscmdlet.ShouldProcess($listname, "Adding batch")) {
            try {
                # Do batch
                $results = ($list.Service.UpdateListItems($listName, $list.BatchElement)).Result
                
                foreach ($result in $results) {
                    $id, $method, $null = $result.ID.Split(",")
                    $errorword = switch ($result.ErrorCode) {
                        '0x00000000' { "Success" }
                        else { 'Failure' }
                    }
                    [pscustomobject]@{
                        Method    = $method
                        Result    = $errorword
                        ErrorCode = $result.ErrorCode
                    }
                }
            }
            catch {
                Stop-PSFFunction -Message "Failure" -ErrorRecord $_
            }
        }
    }
}