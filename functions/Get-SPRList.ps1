﻿Function Get-SPRList {
<#
.SYNOPSIS
    Creates a SharePoint Web service proxy object that lets you use and manage a SharePoint list in Windows PowerShell.
    
.DESCRIPTION
    Creates a SharePoint Web service proxy object that lets you use and manage a SharePoint list in Windows PowerShell.
    
.PARAMETER Uri
    The address to the web application. You can also pass a hostname and it'll figure it out.

.PARAMETER ListName
    The human readable list name. So 'My List' as opposed to 'MyList', unless you named it MyList.
    
.PARAMETER RowLimit
    Limit the number of rows returned. The entire list is returned by default.
  
.PARAMETER Credential
    Provide alternative credentials to the web service. Otherwise, it will use default credentials. 
    
.PARAMETER EnableException
    By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
    This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
    Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
    
.PARAMETER IntputObject
    Allows piping from Connect-SPRSite
    
.EXAMPLE
    Get-SPRList -Uri intranet.ad.local -ListName 'My List'

    Creates a web service object for My List on intranet.ad.local. Figures out the wsdl address automatically.
    
.EXAMPLE
    Connect-SPRSite -Uri intranet.ad.local | Get-SPRList -ListName 'My List'

    Creates a web service object for My List on intranet.ad.local. Figures out the wsdl address automatically.
    
.EXAMPLE
    Get-SPRList -Uri intranet.ad.local -ListName 'My List' -Credential (Get-Credential ad\user)

    Creates a web service object for My List and logs into the webapp as ad\user.
#>
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage = "SharePoint lists.asmx?wsdl location")]
        [string]$Uri,
        [Parameter(Mandatory, HelpMessage = "Human-readble SharePoint list name")]
        [string[]]$ListName,
        [int]$RowLimit = 0,
        [PSCredential]$Credential,
        [parameter(ValueFromPipeline)]
        [object]$InputObject,
        [switch]$EnableException
    )
    process {
        if (-not $InputObject) {
            if ($Uri) {
                $InputObject = Connect-SPRSite -Uri $Uri -Credential $Credential
            }
            elseif ($global:server) {
                $InputObject = $global:server
            }
            else {
                Stop-PSFFunction -EnableException:$EnableException -Message "You must specify Uri or run Connect-SPRSite"
                return
            }
        }
        
        foreach ($server in $InputObject) {
            foreach ($currentlist in $ListName) {
                try {
                    $lists = $server.Web.Lists
                    $global:server.Load($lists)
                    $global:server.ExecuteQuery()
                    
                    if ($currentlist -notin $lists.Title) {
                        # Let's see if this works better
                        continue
                        Stop-PSFFunction -EnableException:$EnableException -Message "List $currentlist cannot be found on $($global:server.Url)" -Continue
                    }
                    
                    Write-PSFMessage -Level Verbose -Message "Getting $currntlist from $global:server"
                    $list = $lists.GetByTitle($currentlist)
                    $global:server.Load($list)
                    $global:server.ExecuteQuery()
                    Select-DefaultView -InputObject $list -Property Id, Title, Description, ItemCount, BaseType, Created
                }
                catch {
                    Stop-PSFFunction -EnableException:$EnableException -Message "Failure" -ErrorRecord $_
                }
            }
        }
    }
}