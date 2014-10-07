<#
Module: SumoTools
Author: Derek Ardolf
Version: 0.2
Date: 10/05/14

NOTE: Please check out GitHub for latest revisions
Link: https://github.com/ScriptAutomate/SumoTools
#>

#requires -version 3

function New-SumoCredential {
<#
	.SYNOPSIS
		Creates an encrypted dump of credentials for use by the SumoTools Module agains the Sumo Logic API.

	.DESCRIPTION
		Using credentials securely dumped by New-SumoCredential, SumoTool Module functions interact with the Sumo Logic API. Use of a generated Access ID is recommended, versus using primary Sumo Logic logon credentials. Credentials are encrypted using DPAPI -- see link at end of help documentation.

	.PARAMETER  Credential
		Credentials for accessing the Sumo Logic API.

	.PARAMETER  Force
		Will overwrite any previously generated credentials.

  .INPUT
    System.Management.Automation.PSCredential
  
  .OUTPUT
    None

	.EXAMPLE
		PS C:\> New-SumoCredential -Credential $Creds
      
      Uses the credentials stored in the $Creds variable to dump to module's root path.

	.EXAMPLE
		PS C:\> $Creds | New-SumoCredential -Force
    
      Uses the credentials stored in the $Creds variable to dump to module's root path. The -Force parameter overwrites pre-existing credentials.

	.LINK
		https://github.com/ScriptAutomate/SumoTools
  .LINK
    https://github.com/SumoLogic/sumo-api-doc/wiki
	.LINK
		http://msdn.microsoft.com/en-us/library/ms995355.aspx
  .LINK
    http://powershell.org/wp/2013/11/24/saving-passwords-and-preventing-other-processes-from-decrypting-them/comment-page-1/
  
  .COMPONENT
    Invoke-RestMethod
    Get-Credential
    ConvertTo-SecureString
    ConvertFrom-SecureString
    
#>
[CmdletBinding()]
Param
(
  [Parameter(Mandatory=$False,ValueFromPipeline=$True)]
  [System.Management.Automation.PSCredential]$Credential,
  [Parameter(Mandatory=$False)]
  [Switch]$Force 
)
  $ModuleLocation = (Get-Module SumoTools).Path.Replace('\SumoTools.psm1','')
  if (Test-Path "$ModuleLocation\SumoAuth1") {
    if (!$Force) {
      Write-Error "$ModuleLocation\SumoAuth* credentials already exist. Use with -Force parameter to overwrite."
      break
    }
    else { 
      Write-Warning "$ModuleLocation\SumoAuth* credentials already exist. -Force parameter was used -- overwriting..."
    }
  }
  
  try {
    if (!$Credential) {
      Get-Credential -Message "Enter Credentials to Query Sumo Logic API"
      if (!$Credential) {break}
    }
    
    Write-Warning "Verifying credentials..."
    $SumoBaseAPI = "https://api.sumologic.com/api/v1"
    Invoke-RestMethod $SumoBaseAPI -Credential $Credential
    
    # If credentials worked, export secure string text
    $Credential.GetNetworkCredential().Password | 
      ConvertTo-SecureString -AsPlainText -Force | 
      ConvertFrom-SecureString | 
      Out-File "$ModuleLocation\SumoAuth1"
    $Credential.GetNetworkCredential().UserName | 
      ConvertTo-SecureString -AsPlainText -Force | 
      ConvertFrom-SecureString | 
      Out-File "$ModuleLocation\SumoAuth2"
      
    Write-Warning "Credentials successfully tested, and exported." 
    Write-Warning "All commands from the SumoTools Module will now use these credentials."
  }
  catch {
    Write-Error $_.Exception
    break
  }
}
  
function Get-SumoCollector {
<#
	.SYNOPSIS
		Uses the Sumo Logic Collector Management API to query Sumo Collector information.

	.DESCRIPTION
		Using credentials securely dumped by New-SumoCredential, Get-SumoCredential queries the Collector Management API for Collector information. The returned JSON information is converted into happy PowerShell objects.

	.PARAMETER  Name
		Name of Sumo Collector. Accepts wildcards.

	.PARAMETER  OSType
		Filters the Collectors by the OS they are installed on. Accepts either 'Windows' or 'Linux.'
    
  .PARAMETER  Active
		Filters the results to only show Collectors based on the boolean value of Active.

	.EXAMPLE
		PS C:\> Get-SumoCollector -Name SQL*
    
      Returns all Collectors with SQL* at the beginning of the Collector name

	.EXAMPLE
		PS C:\> Get-SumoCollector -OSType Linux -Active
    
      Returns all active Linux Collectors

  .EXAMPLE
    PS C:\> Get-SumoCollector -Name SQLSRV01 | Get-SumoCollectorSource
    
      Retrieve all sources for the Collector with the name 'SQLSRV01'

	.INPUTS
		System.String

	.OUTPUTS
		System.Management.Automation.PSCustomObject

	.LINK
		https://github.com/ScriptAutomate/SumoTools

	.LINK
		https://github.com/SumoLogic/sumo-api-doc/wiki
    
  .COMPONENT
    Invoke-RestMethod
    ConvertTo-SecureString
#>

[CmdletBinding()]
Param
(
  [Parameter(Mandatory=$False,
    ValueFromPipelineByPropertyName=$True,
    ValueFromPipeline=$True)]
  [Alias("CollectorName")]
  [String[]]$Name,
  [Parameter(Mandatory=$False)]
  [ValidateSet('Linux','Windows')]
  [String[]]$OSType,
  [Parameter(Mandatory=$False)]
  [Switch]$Active,
  [Parameter(Mandatory=$False)]
  [Switch]$Inactive
)
  Begin {
    # Checking for credentials
    $ModuleLocation = (Get-Module SumoTools).Path.Replace('\SumoTools.psm1','')
    $Password = "$ModuleLocation\SumoAuth1"
    $UserName = "$ModuleLocation\SumoAuth2"
    if ((Test-Path $Password) -and (Test-Path $UserName)) {
      $CredUserSecure = Get-Content "$ModuleLocation\SumoAuth2" | ConvertTo-SecureString
      $BSTRU = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredUserSecure)
      $CredUser = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRU)
      $CredPass = Get-Content "$ModuleLocation\SumoAuth1" | ConvertTo-SecureString
      $Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$CredUser",$CredPass
    }
    else {
      Write-Error "Failure to find credentials. You must run New-SumoCredential before you can use the SumoTools Module."
      break
    }
    $SumoBaseAPI = "https://api.sumologic.com/api"
    
    if ($Active -and $Inactive) {
      Clear-Variable Active,Inactive
    }
  }
  
  Process {
    $Retrieve = Invoke-RestMethod "$SumoBaseAPI/v1/collectors" -Credential $Creds
    if (!$Name) {$Collectors = $Retrieve.Collectors}
    else {
      foreach ($Query in $Name) {
        $Collectors += $Retrieve.Collectors | where {$_.Name -like "$Query"}
      }
      $Collectors = $Collectors | select -Unique
    }    
    if ($Active) {$Collectors = $Collectors | where {$_.Alive -eq "True"}}
    elseif ($Inactive) {$Collectors = $Collectors | where {$_.Alive -eq "False"}}
    if ($OSType) {$Collectors | where {$_.OSName -like "$OSType*"}}
    else {$Collectors}
  }
}

function Get-SumoCollectorSource {
[CmdletBinding()]
Param
(
  [Parameter(Mandatory=$False,
    ValueFromPipelineByPropertyName=$True,
    ValueFromPipeline=$True)]
  [Alias("CollectorName")]
  [String[]]$Name
)
  Begin {
    # Checking for credentials
    $ModuleLocation = (Get-Module SumoTools).Path.Replace('\SumoTools.psm1','')
    $Password = "$ModuleLocation\SumoAuth1"
    $UserName = "$ModuleLocation\SumoAuth2"
    if ((Test-Path $Password) -and (Test-Path $UserName)) {
      $CredUserSecure = Get-Content "$ModuleLocation\SumoAuth2" | ConvertTo-SecureString
      $BSTRU = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredUserSecure)
      $CredUser = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRU)
      $CredPass = Get-Content "$ModuleLocation\SumoAuth1" | ConvertTo-SecureString
      $Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$CredUser",$CredPass
    }
    else {
      Write-Error "Failure to find credentials. You must run New-SumoCredential before you can use the SumoTools Module."
      break
    }
    $SumoBaseAPI = "https://api.sumologic.com/api"
  }
  
  Process {
    $Retrieve = Invoke-RestMethod "$SumoBaseAPI/v1/collectors" -Credential $Creds
    if (!$Name) {$Collectors = $Retrieve.Collectors}
    else {
      foreach ($Query in $Name) {
        $Collectors += $Retrieve.Collectors | where {$_.Name -eq "$Query"}
      }
      $Collectors = $Collectors | select -Unique
    }
    foreach ($Collector in $Collectors) {
      $SourceLink = $Collector.links.href
      $SourceConfig = Invoke-RestMethod "$SumoBaseAPI/$SourceLink" -Credential $Creds
      foreach ($Source in $SourceConfig.Sources) {
        $Source | Add-Member -MemberType NoteProperty -Name collectorName -Value $Collector.Name
        $Source | Add-Member -MemberType NoteProperty -Name collectorID -Value $Collector.ID
        $Source
      }
    } #foreach ($Collector in $Collectors)
  } #Process block end
}

function New-SumoCollectorSource {
[CmdletBinding()]
Param
(
  [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True,Position=0)]
  [Alias('ID')]
  [String]$CollectorID,
  [Parameter(ParameterSetName="JSONFile",Mandatory=$True,Position=1)]
  [String]$JSONFile
  
#  [Parameter(ParameterSetName="LocalFile",Mandatory=$True)]
#  [Switch]$LocalFileSource,
#  [Parameter(ParameterSetName="LocalFile",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String]$PathExpression,
#  [Parameter(ParameterSetName="LocalFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [String[]]$BlackList,
#  
#  [Parameter(ParameterSetName="RemoteFile",Mandatory=$True)]
#  [Switch]$RemoteFileSource,
#  [Parameter(ParameterSetName="LocalFile",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String]$RemoteHost,
#  [Parameter(ParameterSetName="LocalFile",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [Int]$RemotePort,
#  [Parameter(ParameterSetName="LocalFile",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String]$RemoteUser,
#  [Parameter(ParameterSetName="LocalFile",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [System.Security.SecureString]$RemotePassword,
#  [Parameter(ParameterSetName="LocalFile",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String]$SSHKeyPath,
#  [Parameter(ParameterSetName="LocalFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [System.Security.SecureString]$SSHKeyPassword,
#  [Parameter(ParameterSetName="LocalFile",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String]$RemotePath,
#  [Parameter(ParameterSetName="LocalFile",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String]$AuthenticationMethod,  
#
#  [Parameter(ParameterSetName="LocalWinLog",Mandatory=$True)]
#  [Switch]$LocalEventLogSource,
#  [Parameter(ParameterSetName=("RemoteWinLog" -or "LocalWinLog"),Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [ValidateSet("Security","Application","System","Others")]
#  [String[]]$LogNames,
#  
#  [Parameter(ParameterSetName="RemoteWinLog",Mandatory=$True)]
#  [Switch]$RemoteEventLogSource,
#  [Parameter(ParameterSetName="RemoteWinLog",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String]$Domain,
#  [Parameter(ParameterSetName="RemoteWinLog",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String]$UserName,
#  [Parameter(ParameterSetName="RemoteWinLog",Mandatory=$True)]
#  [System.Security.SecureString]$Password,
#  [Parameter(ParameterSetName="RemoteWinLog",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [Switch[]]$Hosts,
#  
#  [Parameter(ParameterSetName="Syslog",Mandatory=$True)]
#  [Switch]$SysLogSource,
#  [Parameter(ParameterSetName="Syslog",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String]$Port,
#  [Parameter(ParameterSetName="Syslog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [String]$Protocol="UDP",
#  
#  [Parameter(ParameterSetName="Script",Mandatory=$True)]
#  [Switch]$ScriptSource,
#  [Parameter(ParameterSetName="Script" -and "ScriptBlock",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String[]]$ScriptBlock,
#  [Parameter(ParameterSetName="Script" -and "ScriptFile",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String]$ScriptFile,
#  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [String]$WorkingDirectory,
#  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [Int]$TimeOutInMilliseconds,
#  [Parameter(ParameterSetName="Script",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String]$CronExpression,
#  
#  [Parameter(ParameterSetName=!"JSONFile",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String]$SourceName,
#  [Parameter(ParameterSetName=!"JSONFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [String]$Description,
#  [Parameter(ParameterSetName=!"JSONFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [String]$Category,
#  [Parameter(ParameterSetName=!"JSONFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [String]$HostName,
#  [Parameter(ParameterSetName=!"JSONFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [String]$TimeZone,
#  [Parameter(ParameterSetName=!"JSONFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [Switch]$AutomaticDateParsing,
#  [Parameter(ParameterSetName=!"JSONFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [Switch]$MultilineProcessingEnabled,
#  [Parameter(ParameterSetName=!"JSONFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [Switch]$UseAutolineMatching,
#  [Parameter(ParameterSetName=!"JSONFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [String]$ManualPrefixRegexp,
#  [Parameter(ParameterSetName=!"JSONFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [Switch]$ForceTimeZone,
#  [Parameter(ParameterSetName=!"JSONFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [String]$DefaultDateFormat,
#  [Parameter(ParameterSetName=!"JSONFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [String]$CutOffTimeStamp,
#  [Parameter(ParameterSetName=!"JSONFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [String]$CutoffRelativeTime
  
#  [Parameter(ParameterSetName=!"JSONFile" -and "Filter",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
#  [String]$Filters,
# Add filters: https://github.com/SumoLogic/sumo-api-doc/wiki/collector-management-api
)
  Begin {
    # Checking for credentials
    $ModuleLocation = (Get-Module SumoTools).Path.Replace('\SumoTools.psm1','')
    $Password = "$ModuleLocation\SumoAuth1"
    $UserName = "$ModuleLocation\SumoAuth2"
    if ((Test-Path $Password) -and (Test-Path $UserName)) {
      $CredUserSecure = Get-Content "$ModuleLocation\SumoAuth2" | ConvertTo-SecureString
      $BSTRU = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredUserSecure)
      $CredUser = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRU)
      $CredPass = Get-Content "$ModuleLocation\SumoAuth1" | ConvertTo-SecureString
      $Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$CredUser",$CredPass
    }
    else {
      Write-Error "Failure to find credentials. You must run New-SumoCredential before you can use the SumoTools Module."
      break
    }
    $SumoBaseAPI = "https://api.sumologic.com/api"
  }
  
  Process {
    $SumoSourcesBase = "$SumoBaseAPI/v1/collectors/$ID/sources"

    if ($JSONFile) {
      $Output = Invoke-RestMethod $Hash -Uri $SumoSourcesBase -Method Post -ContentType "application/json" -InFile $JSONFile -Credential $Creds
    }
#    elseif ($LocalFileSource) {
#      $Hash = @{'Uri'="$SumoSourcesBase";
#                'Method'="Post";
#                'ContentType'="application/json";
#                'InFile'="$JSONFile";
#                'Credential'=$Creds}
#      $Output = Invoke-RestMethod $Hash
#    }
#    elseif ($RemoteFileSource) {
#      
#    }
#    elseif ($ScriptSource) {
#    
#    }
#    elseif ($SysLogSource) {
#    
#    }
#    elseif ($LocalEventLogSource) {
#    
#    }
#    elseif ($RemoteEventLogSource) {
#    
#    }

    $Collector = Get-SumoCollector | where {$_.ID -eq $ID}
    $Output.source | Add-Member -MemberType NoteProperty -Name collectorName -Value $Collector.Name
    $Output.source | Add-Member -MemberType NoteProperty -Name collectorID -Value $Collector.ID
    $Output.source
  }
}

function Remove-SumoCollectorSource {
[CmdletBinding()]
Param
(
  [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [String]$CollectorID,
  [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [Alias("ID")]
  [String]$SourceID
)
  Begin {
    # Checking for credentials
    $ModuleLocation = (Get-Module SumoTools).Path.Replace('\SumoTools.psm1','')
    $Password = "$ModuleLocation\SumoAuth1"
    $UserName = "$ModuleLocation\SumoAuth2"
    if ((Test-Path $Password) -and (Test-Path $UserName)) {
      $CredUserSecure = Get-Content "$ModuleLocation\SumoAuth2" | ConvertTo-SecureString
      $BSTRU = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredUserSecure)
      $CredUser = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRU)
      $CredPassSecure = Get-Content "$ModuleLocation\SumoAuth1" | ConvertTo-SecureString
    }
    else {
      Write-Error "Failure to find credentials. You must run New-SumoCredential before you can use the SumoTools Module."
      break
    }
    
    # Configuring connection to Sumo Logic API
    $RESTCreds = New-Object System.Management.Automation.PSCredential("$CredUser",$CredPassSecure)
  }
  
  Process {
    $SourceProperties = Get-SumoCollector | where {$_.ID -eq $CollectorID} | Get-SumoCollectorSource | where {$_.ID -eq $SourceID}
    Write-Warning "REMOVING Sumo Collector Source $SourceID"
    Write-Warning "Collector Name: $($SourceProperties.CollectorName)"
    Write-Warning "Source Name: $($SourceProperties.Name)"
    $WebPageBase = "https://api.sumologic.com/api/v1/collectors/$CollectorID/sources/$SourceID"
    Invoke-RestMethod -Uri $WebPageBase -Method Delete -Credential $RESTCreds -ErrorAction Stop
    Write-Warning "REMOVED Sumo Collector Source. Source Name: $($SourceProperties.Name)"
  }
}

function Remove-SumoCollector {
[CmdletBinding()]
Param
(
  [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [Alias("CollectorID")]
  [String[]]$ID
)
  Begin {
    # Checking for credentials
    $ModuleLocation = (Get-Module SumoTools).Path.Replace('\SumoTools.psm1','')
    $Password = "$ModuleLocation\SumoAuth1"
    $UserName = "$ModuleLocation\SumoAuth2"
    if ((Test-Path $Password) -and (Test-Path $UserName)) {
      $CredUserSecure = Get-Content "$ModuleLocation\SumoAuth2" | ConvertTo-SecureString
      $BSTRU = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredUserSecure)
      $CredUser = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRU)
      $CredPassSecure = Get-Content "$ModuleLocation\SumoAuth1" | ConvertTo-SecureString
    }
    else {
      Write-Error "Failure to find credentials. You must run New-SumoCredential before you can use the SumoTools Module."
      break
    }
    
    # Configuring connection to Sumo Logic API
    $RESTCreds = New-Object System.Management.Automation.PSCredential("$CredUser",$CredPassSecure)
  }
  
  Process {
    foreach ($Collector in $ID) {
      $CollectorName = (Get-SumoCollector | where {$_.ID -eq $ID}).Name
      Write-Warning "REMOVING Sumo Collector $Collector."
      Write-Warning "Name: $CollectorName"
      $WebPageBase = "https://api.sumologic.com/api/v1/collectors/$Collector"
      Invoke-RestMethod -Uri $WebPageBase -Method Delete -Credential $RESTCreds -ErrorAction Stop
      Write-Warning "REMOVED Sumo Collector $Collector. Name: $CollectorName"
    }
  }
}

#function Set-SumoCollectorSource {
#[CmdletBinding()]
#Param
#(
#  [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [Alias("SourceID")]
#  [String]$ID,
#  [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String]$CollectorID,
#  [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String]$Property,
#  [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
#  [String]$Value
#)
#  Begin {
#    # Checking for credentials
#    $ModuleLocation = (Get-Module SumoTools).Path.Replace('\SumoTools.psm1','')
#    $Password = "$ModuleLocation\SumoAuth1"
#    $UserName = "$ModuleLocation\SumoAuth2"
#    if ((Test-Path $Password) -and (Test-Path $UserName)) {
#      $CredUserSecure = Get-Content "$ModuleLocation\SumoAuth2" | ConvertTo-SecureString
#      $BSTRU = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredUserSecure)
#      $CredUser = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRU)
#      $CredPass = Get-Content "$ModuleLocation\SumoAuth1" | ConvertTo-SecureString
#      $Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$CredUser",$CredPass
#    }
#    else {
#      Write-Error "Failure to find credentials. You must run New-SumoCredential before you can use the SumoTools Module."
#      break
#    }
#    $SumoBaseAPI = "https://api.sumologic.com/api"
#  }
#  
#  Process {
#    $TargetSourceURI = "$SumoBaseAPI/v1/collectors/$CollectorID/sources/$ID"
#    $Retrieve = Invoke-WebRequest $TargetSourceURI -Credential $Creds
#    $ETAG = $Retrieve.Headers.Etag
#    $SourceConfig = ($Retrieve.Content | ConvertFrom-Json).Source
#    $ConfigNames = ($SourceConfig | gm -MemberType NoteProperty).Name #|where {$_ -notlike "id" -and $_ -notlike "status" -and $_ -notlike "alive"}
#    
#    foreach ($ConfigName in $ConfigNames) {
#      New-Variable -Name "New$ConfigName" -Value $SourceConfig.$ConfigName
#    } 
#    $ChangeProperty = $ConfigNames | where {$_ -like "$Property"}
#    if ($ChangeProperty) {
#      Set-Variable -Name "New$Property" -Value $Value
#      foreach ($ConfigName in $ConfigNames) {
#        $SourceProps += @{"$ConfigName"=(Get-Variable "New$ConfigName").Value}
#      }
#      $Props = @{'source'=$SourceProps}
#    }
#    else {
#      $New = @("$Property","$Value")
#      $SourceProps = @{$New[0]=$New[1]}
#      foreach ($ConfigName in $ConfigNames) {
#        $SourceProps += @{"$ConfigName"=(Get-Variable "New$ConfigName").Value}
#      }
#      $Props = @{'source'=$SourceProps}
#    }
#    $ModifiedSourceConfig = New-Object -TypeName PSObject -Property $Props
#    
#    $JSONFile = "$($ModifiedSourceConfig.Source.Name).json"
#    $ModifiedSourceConfig | ConvertTo-Json | Out-File $JSONFile -Encoding UTF8
#    $JSONFileContent = Get-Content $JSONFile
#    $JSONFullPath = (Get-Item $JSONFile).FullName
#    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
#    [System.IO.File]::WriteAllLines($JSONFullPath, $JSONFileContent, $Utf8NoBomEncoding)
#
#    $ETAGHash = @{'If-Match'=$ETAG}
#    Invoke-RestMethod -Uri $TargetSourceURI -Method Put -Headers $ETAGHash -InFile $JSONFile -ContentType "application/json"
#  }
#}