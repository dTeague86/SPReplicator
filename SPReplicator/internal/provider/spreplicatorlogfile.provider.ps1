﻿# Action that is performed on registration of the provider using Register-PSFLoggingProvider
$registrationEvent = {
    
}

#region Logging Execution
# Action that is performed when starting the logging script (or the very first time if enabled after launching the logging script)
$begin_event = {
    function Get-SpReplicatorLogFilePath {
        [CmdletBinding()]
        param (
            
        )
        
        $path = Get-PSFConfigValue -FullName 'spreplicator.Logging.LogFile.FilePath'
        $logname = Get-PSFConfigValue -FullName 'spreplicator.Logging.LogFile.LogName'
        
        $scriptBlock = {
            param (
                [string]$Match
            )
            
            $hash = @{
                '%date%' = (Get-Date -Format 'yyyy-MM-dd')
                '%dayofweek%' = (Get-Date).DayOfWeek
                '%day%'  = (Get-Date).Day
                '%hour%' = (Get-Date).Hour
                '%minute%' = (Get-Date).Minute
                '%username%' = $env:USERNAME
                '%userdomain%' = $env:USERDOMAIN
                '%computername%' = $env:COMPUTERNAME
                '%processid%' = $PID
                '%logname%' = $logname
            }
            
            $hash.$Match
        }
        
        [regex]::Replace($path, '%day%|%computername%|%hour%|%processid%|%date%|%username%|%dayofweek%|%minute%|%userdomain%|%logname%', $scriptBlock)
    }
    
    function Write-SpReplicatorLogFileMessage {
        [CmdletBinding()]
        param (
            [Parameter(ValueFromPipeline = $true)]
            $Message,
            [bool]$IncludeHeader,
            [string]$FileType,
            [string]$Path,
            [string]$CsvDelimiter,
            [string[]]$Headers
        )
        
        $parent = Split-Path $Path
        if (-not (Test-Path $parent)) {
            $null = New-Item $parent -ItemType Directory -Force
        }
        $fileExists = Test-Path $Path
        
        #region Type-Based Output
        switch ($FileType) {
            #region Csv
            "Csv"
            {
                if ((-not $fileExists) -and $IncludeHeader) { $Message | ConvertTo-Csv -NoTypeInformation -Delimiter $CsvDelimiter | Set-Content -Path $Path -Encoding UTF8 }
                else { $Message | ConvertTo-Csv -NoTypeInformation -Delimiter $CsvDelimiter | Select-Object -SkipLast 1 | Add-Content -Path $Path -Encoding UTF8 }
            }
            #endregion Csv
            #region Json
            "Json"
            {
                if ($fileExists) { Add-Content -Path $Path -Value "," -Encoding UTF8 }
                $Message | ConvertTo-Json | Add-Content -Path $Path -NoNewline -Encoding UTF8
            }
            #endregion Json
            #region XML
            "XML"
            {
                [xml]$xml = $message | ConvertTo-Xml -NoTypeInformation
                $xml.Objects.InnerXml | Add-Content -Path $Path -Encoding UTF8
            }
            #endregion XML
            #region Html
            "Html"
            {
                [xml]$xml = $message | ConvertTo-Html -Fragment
                
                if ((-not $fileExists) -and $IncludeHeader) {
                    $xml.table.tr[0].OuterXml | Add-Content -Path $Path -Encoding UTF8
                }
                
                $xml.table.tr[1].OuterXml | Add-Content -Path $Path -Encoding UTF8
            }
            #endregion Html
        }
        #endregion Type-Based Output
    }
    
    $SpReplicatorlogfile_includeheader = Get-PSFConfigValue -FullName 'spreplicator.Logging.LogFile.IncludeHeader'
    $SpReplicatorlogfile_headers = Get-PSFConfigValue -FullName 'spreplicator.Logging.LogFile.Headers'
    $SpReplicatorlogfile_filetype = Get-PSFConfigValue -FullName 'spreplicator.Logging.LogFile.FileType'
    $SpReplicatorlogfile_CsvDelimiter = Get-PSFConfigValue -FullName 'spreplicator.Logging.LogFile.CsvDelimiter'
    
    if ($SpReplicatorlogfile_headers -contains 'Tags') {
        $SpReplicatorlogfile_headers = $SpReplicatorlogfile_headers | ForEach-Object {
            if ($_ -ne 'Tags') { $_ }
            else {
                @{
                    Name       = 'Tags'
                    Expression = { $_.Tags -join "," }
                }
            }
        }
    }
    
    $SpReplicatorlogfile_paramWriteLogFileMessage = @{
        IncludeHeader = $SpReplicatorlogfile_includeheader
        FileType      = $SpReplicatorlogfile_filetype
        CsvDelimiter  = $SpReplicatorlogfile_CsvDelimiter
        Headers       = $SpReplicatorlogfile_headers
    }
}

# Action that is performed at the beginning of each logging cycle
$start_event = {
    $SpReplicatorlogfile_paramWriteLogFileMessage["Path"] = Get-SpReplicatorLogFilePath
}

# Action that is performed for each message item that is being logged
$message_Event = {
    Param (
        $Message
    )
    
    $Message | Select-Object $SpReplicatorlogfile_headers | Write-SpReplicatorLogFileMessage @SpReplicatorlogfile_paramWriteLogFileMessage
}

# Action that is performed for each error item that is being logged
$error_Event = {
    Param (
        $ErrorItem
    )
    
    
}

# Action that is performed at the end of each logging cycle
$end_event = {
    
}

# Action that is performed when stopping the logging script
$final_event = {
    
}
#endregion Logging Execution

#region Function Extension / Integration
# Script that generates the necessary dynamic parameter for Set-PSFLoggingProvider
$configurationParameters = {
    $configroot = "spreplicator.logging.logfile"
    
    $configurations = Get-PSFConfig -FullName "$configroot.*"
    
    $RuntimeParamDic = New-Object  System.Management.Automation.RuntimeDefinedParameterDictionary
    
    foreach ($config in $configurations) {
        $ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
        $ParamAttrib.ParameterSetName = '__AllParameterSets'
        $AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $AttribColl.Add($ParamAttrib)
        $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter(($config.FullName.Replace($configroot, "").Trim(".")), $config.Value.GetType(), $AttribColl)
        
        $RuntimeParamDic.Add(($config.FullName.Replace($configroot, "").Trim(".")), $RuntimeParam)
    }
    return $RuntimeParamDic
}

# Script that is executes when configuring the provider using Set-PSFLoggingProvider
$configurationScript = {
    $configroot = "spreplicator.logging.logfile"
    
    $configurations = Get-PSFConfig -FullName "$configroot.*"
    
    foreach ($config in $configurations) {
        if ($PSBoundParameters.ContainsKey(($config.FullName.Replace($configroot, "").Trim(".")))) {
            Set-PSFConfig -Module $config.Module -Name $config.Name -Value $PSBoundParameters[($config.FullName.Replace($configroot, "").Trim("."))]
        }
    }
}

# Script that returns a boolean value. "True" if all prerequisites are installed, "False" if installation is required
$isInstalledScript = {
    return $true
}

# Script that provides dynamic parameter for Install-PSFLoggingProvider
$installationParameters = {
    # None needed
}

# Script that performs the actual installation, based on the parameters (if any) specified in the $installationParameters script
$installationScript = {
    # Nothing to be done - if you need to install your filesystem, you probably have other issues you need to deal with first ;)
}
#endregion Function Extension / Integration

# Configuration settings to initialize
$configuration_Settings = {
    Set-PSFConfig -Module SpReplicator -Name 'Logging.LogFile.FilePath' -Value "" -Initialize -Validation string -Handler { } -Description "The path to where the logfile is written. Supports some placeholders such as %Date% to allow for timestamp in the name. For full documentation on the supported wildcards, see the documentation on https://psframework.org"
    Set-PSFConfig -Module SpReplicator -Name 'Logging.LogFile.Logname' -Value "" -Initialize -Validation string -Handler { } -Description "A special string you can use as a placeholder in the logfile path (by using '%logname%' as placeholder)"
    Set-PSFConfig -Module SpReplicator -Name 'Logging.LogFile.IncludeHeader' -Value $true -Initialize -Validation bool -Handler { } -Description "Whether a written csv file will include headers"
    Set-PSFConfig -Module SpReplicator -Name 'Logging.LogFile.Headers' -Value @('ComputerName', 'File', 'FunctionName', 'Level', 'Line', 'Message', 'ModuleName', 'Runspace', 'Tags', 'TargetObject', 'Timestamp', 'Type', 'Username') -Initialize -Validation stringarray -Handler { } -Description "The properties to export, in the order to select them."
    Set-PSFConfig -Module SpReplicator -Name 'Logging.LogFile.FileType' -Value "CSV" -Initialize -Validation psframework.logfilefiletype -Handler { } -Description "In what format to write the logfile. Supported styles: CSV, XML, Html or Json. Html, XML and Json will be written as fragments."
    Set-PSFConfig -Module SpReplicator -Name 'Logging.LogFile.CsvDelimiter' -Value "," -Initialize -Validation string -Handler { } -Description "The delimiter to use when writing to csv."
    
    Set-PSFConfig -Module LoggingProvider -Name 'SpReplicatorLogFile.Enabled' -Value $false -Initialize -Validation "bool" -Handler { } -Description "Whether the logging provider should be enabled on registration"
    Set-PSFConfig -Module LoggingProvider -Name 'SpReplicatorLogFile.AutoInstall' -Value $false -Initialize -Validation "bool" -Handler { } -Description "Whether the logging provider should be installed on registration"
    Set-PSFConfig -Module LoggingProvider -Name 'SpReplicatorLogFile.InstallOptional' -Value $true -Initialize -Validation "bool" -Handler { } -Description "Whether installing the logging provider is mandatory, in order for it to be enabled"
    Set-PSFConfig -Module LoggingProvider -Name 'SpReplicatorLogFile.IncludeModules' -Value @() -Initialize -Validation "stringarray" -Handler { } -Description "Module whitelist. Only messages from listed modules will be logged"
    Set-PSFConfig -Module LoggingProvider -Name 'SpReplicatorLogFile.ExcludeModules' -Value @() -Initialize -Validation "stringarray" -Handler { } -Description "Module blacklist. Messages from listed modules will not be logged"
    Set-PSFConfig -Module LoggingProvider -Name 'SpReplicatorLogFile.IncludeTags' -Value @() -Initialize -Validation "stringarray" -Handler { } -Description "Tag whitelist. Only messages with these tags will be logged"
    Set-PSFConfig -Module LoggingProvider -Name 'SpReplicatorLogFile.ExcludeTags' -Value @() -Initialize -Validation "stringarray" -Handler { } -Description "Tag blacklist. Messages with these tags will not be logged"
}

Register-PSFLoggingProvider -Name "spreplicatorlogfile" -RegistrationEvent $registrationEvent -BeginEvent $begin_event -StartEvent $start_event -MessageEvent $message_Event -ErrorEvent $error_Event -EndEvent $end_event -FinalEvent $final_event -ConfigurationParameters $configurationParameters -ConfigurationScript $configurationScript -IsInstalledScript $isInstalledScript -InstallationScript $installationScript -InstallationParameters $installationParameters -ConfigurationSettings $configuration_Settings