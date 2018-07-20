﻿function Select-SPRObject {
    <#
.SYNOPSIS
    Makes it easier to alias columns to select and rename for export.
    
.DESCRIPTION
    Makes it easier to alias columns to select and rename for export.
    
    This command also enables the ability to change the default view without destroying objects.
    
    A lot of this is from boe, thanks boe!
    https://learn-powershell.net/2013/08/03/quick-hits-set-the-default-property-display-in-powershell-on-custom-objects/

.PARAMETER InputObject
    Allows piping
 
.PARAMETER TypeName
    TypeName creates a new type so that we can use ps1xml to modify the output
    
.PARAMETER Property
    Only includes specific properties
    
.PARAMETER ExcludeProperty
    Excludes other properties
    
EXAMPLE
    Export-SPRListData -Site intranet.ad.local -ListName 'My List' | Select-SPRObject -Property Title

    Exports only the title column
#>    
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject,
        [string[]]$Property,
        [string[]]$ExcludeProperty,
        [string]$TypeName
    )
    process {
        if ($TypeName) {
            $InputObject.PSObject.TypeNames.Insert(0, "spreplicator.$TypeName")
        }
        
        if ($ExcludeProperty) {
            if ($InputObject.GetType().Name.ToString() -eq 'DataRow') {
                $ExcludeProperty += 'Item', 'RowError', 'RowState', 'Table', 'ItemArray', 'HasErrors'
            }
            
            $props = ($InputObject | Get-Member | Where-Object MemberType -in 'Property','NoteProperty','AliasProperty' | Where-Object { $_.Name -notin $ExcludeProperty }).Name
            $defaultset = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$props)
        }
        else {
            # property needs to be string
            if ("$property" -like "* as *") {
                $newproperty = @()
                foreach ($p in $property) {
                    if ($p -like "* as *") {
                        $old, $new = $p -isplit " as "
                        # Do not be tempted to not pipe here
                        $inputobject | Add-Member -Force -MemberType AliasProperty -Name $new -Value $old -ErrorAction SilentlyContinue
                        $newproperty += $new
                    }
                    else {
                        $newproperty += $p
                    }
                }
                $property = $newproperty
            }
            $defaultset = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$Property)
        }
        
        $standardmembers = [System.Management.Automation.PSMemberInfo[]]@($defaultset)
        
        # Do not be tempted to not pipe here
        $inputobject | Add-Member -Force -MemberType MemberSet -Name PSStandardMembers -Value $standardmembers -ErrorAction SilentlyContinue
        
        $inputobject
    }
}