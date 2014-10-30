<#
Module: SumoTools
Author: Derek Ardolf
Version: 0.6
Date: 10/30/14

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

  .INPUTS
    System.Management.Automation.PSCredential

  .OUTPUTS
    None

	.EXAMPLE
		PS C:\> New-SumoCredential -Credential $Credential
      
      Uses the credentials stored in the $Credential variable to dump to module's root path.

	.EXAMPLE
		PS C:\> $Credential | New-SumoCredential -Force
    
      Uses the credentials stored in the $Credential variable to dump to module's root path. The -Force parameter overwrites pre-existing credentials.

	.LINK
		https://github.com/ScriptAutomate/SumoTools
  .LINK
    https://github.com/SumoLogic/sumo-api-doc/wiki
  .LINK
		https://halfwaytoinfinite.wordpress.com
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
		Get-SumoCollector queries the Collector Management API for Collector information. The returned JSON information is converted into happy PowerShell objects.

	.PARAMETER  Name
		Name of Sumo Collector. Accepts wildcards.

	.PARAMETER  OSType
		Filters the Collectors by the OS they are installed on. Accepts either 'Windows' or 'Linux.'
    
  .PARAMETER  Active
		Filters the results to only show Collectors based on the boolean value of Active.
    
  .PARAMETER  Credential
		Credentials for accessing the Sumo Logic API. Unneccessary if New-SumoCredential has been used.

	.EXAMPLE
		PS C:\> Get-SumoCollector -Name SUMOCOLLECT01*
    
      Returns all Collectors with SUMOCOLLECT01* at the beginning of the Collector name

	.EXAMPLE
		PS C:\> Get-SumoCollector -OSType Linux -Active
    
      Returns all active Linux Collectors

  .EXAMPLE
    PS C:\> Get-SumoCollector -Name SUMOCOLLECT01 | Get-SumoCollectorSource
    
      Retrieve all sources for the Collector with the name 'SUMOCOLLECT01'

	.INPUTS
		System.String

	.OUTPUTS
		System.Management.Automation.PSCustomObject

	.LINK
		https://github.com/ScriptAutomate/SumoTools
  .LINK
    https://github.com/SumoLogic/sumo-api-doc/wiki
  .LINK
		https://halfwaytoinfinite.wordpress.com
    
  .COMPONENT
    Invoke-RestMethod
#>

[CmdletBinding()]
Param
(
  [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$True,ValueFromPipeline=$True)]
  [Alias("CollectorName")]
  [String[]]$Name,
  [Parameter(Mandatory=$False)]
  [System.Management.Automation.PSCredential]$Credential,
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
    $SumoPass = "$ModuleLocation\SumoAuth1"
    $SumoUser = "$ModuleLocation\SumoAuth2"
    if (!$Credential) {
      if ((Test-Path "$SumoPass") -and (Test-Path "$SumoUser")) {
        $CredUserSecure = Get-Content "$ModuleLocation\SumoAuth2" | ConvertTo-SecureString
        $BSTRU = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredUserSecure)
        $CredUser = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRU)
        $CredPass = Get-Content "$ModuleLocation\SumoAuth1" | ConvertTo-SecureString
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$CredUser",$CredPass
      }
      else {
        Write-Error "Failure to find credentials. You must run New-SumoCredential before you can use the SumoTools Module."
        break
      }
    }
    $SumoBaseAPI = "https://api.sumologic.com/api"
    if ($Active -and $Inactive) {
      Clear-Variable Active,Inactive
    }
  }
  
  Process {
    $Retrieve = Invoke-RestMethod "$SumoBaseAPI/v1/collectors" -Credential $Credential
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
<#
	.SYNOPSIS
		Uses the Sumo Logic Collector Management API to query Sumo Collector Source information.

	.DESCRIPTION
		Get-SumoCollectorSource queries the Collector Management API for Collector Source information. The returned JSON information is converted into happy PowerShell objects.

	.PARAMETER  Name
		Name of target Sumo Collector, to retrieve Collector Sources. Does NOT take wildcards. If parameter isn't used, absolutely all sources are retrieved.

  .PARAMETER  Credential
		Credentials for accessing the Sumo Logic API. Unneccessary if New-SumoCredential has been used.

	.EXAMPLE
		PS C:\> Get-SumoCollector -Name SUMOCOLLECT01* | Get-SumoCollectorSource

	.EXAMPLE
		PS C:\> Get-SumoCollector -Name SUMOCOLLECT01* | Get-SumoCollectorSource
    
      Queries for all Collectors with SUMOCOLLECT01* at the beginning of the Collector name, and returns all of their sources.

	.EXAMPLE
		PS C:\> Get-SumoCollectorSource -Name SUMOCOLLECT01
    
      Returns all sources for the collector named "SUMOCOLLECT01"

  .EXAMPLE
    PS C:\> Get-SumoCollectorSource -Name SUMOCOLLECT01 | where {$_.Name -like "*IIS*"}
    
      Retrieve all sources from the collector, SUMOCOLLECT01, with "IIS" being found in the source name.

	.INPUTS
		System.String

	.OUTPUTS
		System.Management.Automation.PSCustomObject

	.LINK
		https://github.com/ScriptAutomate/SumoTools
  .LINK
    https://github.com/SumoLogic/sumo-api-doc/wiki
  .LINK
		https://halfwaytoinfinite.wordpress.com
    
  .COMPONENT
    Invoke-RestMethod
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
  [System.Management.Automation.PSCredential]$Credential
)
  Begin {
    # Checking for credentials
    $ModuleLocation = (Get-Module SumoTools).Path.Replace('\SumoTools.psm1','')
    $SumoPass = "$ModuleLocation\SumoAuth1"
    $SumoUser = "$ModuleLocation\SumoAuth2"
    if (!$Credential) {
      if ((Test-Path "$SumoPass") -and (Test-Path "$SumoUser")) {
        $CredUserSecure = Get-Content "$ModuleLocation\SumoAuth2" | ConvertTo-SecureString
        $BSTRU = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredUserSecure)
        $CredUser = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRU)
        $CredPass = Get-Content "$ModuleLocation\SumoAuth1" | ConvertTo-SecureString
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$CredUser",$CredPass
      }
      else {
        Write-Error "Failure to find credentials. You must run New-SumoCredential before you can use the SumoTools Module."
        break
      }
    }
    $SumoBaseAPI = "https://api.sumologic.com/api"
  }
  
  Process {
    $Retrieve = Invoke-RestMethod "$SumoBaseAPI/v1/collectors" -Credential $Credential
    if (!$Name) {$Collectors = $Retrieve.Collectors}
    else {
      foreach ($Query in $Name) {
        $Collectors += $Retrieve.Collectors | where {$_.Name -eq "$Query"}
      }
      $Collectors = $Collectors | select -Unique
    }
    foreach ($Collector in $Collectors) {
      $SourceLink = $Collector.links.href
      $SourceConfig = Invoke-RestMethod "$SumoBaseAPI/$SourceLink" -Credential $Credential
      foreach ($Source in $SourceConfig.Sources) {
        $Source | Add-Member -MemberType NoteProperty -Name collectorName -Value $Collector.Name
        $Source | Add-Member -MemberType NoteProperty -Name collectorID -Value $Collector.ID
        $Source
      }
    } #foreach ($Collector in $Collectors)
  } #Process block end
}

function New-SumoCollectorSource {
<#
	.SYNOPSIS
		Uses the Sumo Logic Collector Management API to add a new Source to a Collector.

	.DESCRIPTION
		Uses the Sumo Logic Collector Management API to add a new Source to a Collector. The returned JSON information is converted into happy PowerShell objects.

	.PARAMETER  Name
		Name of Sumo Collector. Does NOT take wildcards.

  .PARAMETER  Credential
		Credentials for accessing the Sumo Logic API. Unneccessary if New-SumoCredential has been used.

	.EXAMPLE
		PS C:\>Get-SumoCollector -Name SUMOCOLLECT01 | New-SumoCollectorSource -JSONFile C:\sumo\sources.json
    
      Creates a new Sumo Collector Source on the Sumo Collector, SUMOCOLLECT01, using the contents of the c:\sumo\source.json file.

	.EXAMPLE
    PS C:\>$sshpass = Read-Host "Enter SSH Key Pass" -AsSecureString
    
    
    PS C:\>$newsources = Import-Csv newsources.csv
    
    
    PS C:\>$newsources | New-SumoCollectorSource -RemoteFileV2 -KeyPassword $sshpass -MultilineProcessingEnabled $false -Verbose
    

      Using the contents of newsources.csv to fulfill all other mandatory (and otherwise) parameters for RemoteFileV2 sources, New-SumoCollectorSource adds new Sumo Collector Sources. In this case, all of them have the same KeyPassword, and have MultilineProcessing disabled. The verbose flag is being used here, for possible troubleshooting assistance.

	.EXAMPLE
    PS C:\> $Splat = @{"RemoteHosts"="SSHSOURCE01"
    >>                 "RemotePort"=22
    >>                 "RemoteUser"="sumo.serv.account"
    >>                 "KeyPassword"=$sshpass
    >>                 "KeyPath"="c:\sumokeys\sumo.srv.account"
    >>                 "RemotePath"="/var/log/messages"
    >>                 "MultilineProcessingEnabled"=$false
    >>                 "TimeZone"="America/Chicago"
    >>                 "Category"="SSH_VARLOG_MESSAGES"
    >>                 "Name"="SSHSOURCE01_LINUX_MESSAGES"}
    >>
    PS C:\> New-SumoCollectorSource -RemoteFileV2 -Verbose @Splat
    
    
      Creating a new Sumo Collector Remote File Source with splatting. This is nicer in scripts, and also in help documentation.

	.EXAMPLE
    PS C:\>New-SumoCollectorSource -RemoteFileV2 -RemoteHosts "SSHSOURCE01" -RemotePort 22 -RemoteUser "sumo.serv.account" -KeyPassword $sshpass -KeyPath "c:\sumokeys\sumo.srv.account" -RemotePath "/var/log/messages" -MultilineProcessingEnabled $false -TimeZone "America/Chicago" -Category "SSH_VARLOG_MESSAGES" -Name "SSHSOURCE01_LINUX_MESSAGES" -Verbose
    
      Creating a new Sumo Collector Remote File Source, using a Secure.String that has been stored in $sshpass for the KeyPassword parameter. Verbose flag is on.

	.INPUTS
		System.String

	.OUTPUTS
		System.Management.Automation.PSCustomObject

	.LINK
		https://github.com/ScriptAutomate/SumoTools
  .LINK
    https://github.com/SumoLogic/sumo-api-doc/wiki
  .LINK
		https://halfwaytoinfinite.wordpress.com
    
  .COMPONENT
    Invoke-RestMethod
#>
[CmdletBinding()]
Param
(
  [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True,Position=0)]
  [Alias('ID')]
  [Int]$CollectorID,
  [Parameter(ParameterSetName="JSONFile",Mandatory=$True,Position=1)]
  [String]$JSONFile,
  [Parameter(Mandatory=$False)]
  [System.Management.Automation.PSCredential]$Credential,
  
  [Parameter(ParameterSetName="LocalFile",Mandatory=$True)]
  [Alias('LocalFileSource')]
  [Switch]$LocalFile,
  [Parameter(ParameterSetName="LocalFile",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [String]$PathExpression,
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [String[]]$BlackList,
  
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$True)]
  [Alias('RemoteFileSource')]
  [Switch]$RemoteFileV2,
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [String[]]$RemoteHosts,
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [Int]$RemotePort,
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [String]$RemoteUser,
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [System.Security.SecureString]$RemotePassword,
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [String]$KeyPath,
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [System.Security.SecureString]$KeyPassword,

  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$True)]
  [Alias('LocalWindowsEventLogSource')]
  [Switch]$LocalWindowsEventLog,
  
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$True)]
  [Alias('RemoteWindowsEventLogSource')]
  [Switch]$RemoteWindowsEventLog,
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [String]$Domain,
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [String]$UserName,
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$True)]
  [System.Security.SecureString]$Password,
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [String[]]$Hosts,
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]  
  [ValidateSet("Security","Application","System","Others")]
  [String[]]$LogNames,
  
  [Parameter(ParameterSetName="Syslog",Mandatory=$True)]
  [Alias('SysLogSource')]
  [Switch]$SysLog,
  [Parameter(ParameterSetName="Syslog",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [String]$Port,
  [Parameter(ParameterSetName="Syslog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [String]$Protocol="UDP",

  [Parameter(ParameterSetName="Script",Mandatory=$True)]
  [Alias('ScriptSource')]
  [Switch]$Script,
  [Parameter(ParameterSetName="Script",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [String[]]$ScriptBlock,
  [Parameter(ParameterSetName="Script",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [String]$ScriptFile,
  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [String]$WorkingDirectory,
  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Int]$TimeOutInMilliseconds,
  [Parameter(ParameterSetName="Script",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [String]$CronExpression,
  
  # Properties shared across all sources
  [Parameter(ParameterSetName="Script",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [Alias('SourceName')]
  [String]$Name,
  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [String]$Description,
  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [String]$Category,
  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [String]$HostName,
  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [String]$TimeZone,
  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Bool]$AutomaticDateParsing,
  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Bool]$MultilineProcessingEnabled,
  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Bool]$UseAutolineMatching,
  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [String]$ManualPrefixRegexp,
  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Bool]$ForceTimeZone,
  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [String]$DefaultDateFormat,
  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [String]$CutOffTimeStamp,
  [Parameter(ParameterSetName="Script",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False,ValueFromPipelineByPropertyName=$True)]
  [String]$CutoffRelativeTime
)
  Begin {
    # Checking for credentials
    $ModuleLocation = (Get-Module SumoTools).Path.Replace('\SumoTools.psm1','')
    $SumoPass = "$ModuleLocation\SumoAuth1"
    $SumoUser = "$ModuleLocation\SumoAuth2"
    if (!$Credential) {
      if ((Test-Path "$SumoPass") -and (Test-Path "$SumoUser")) {
        $CredUserSecure = Get-Content "$ModuleLocation\SumoAuth2" | ConvertTo-SecureString
        $BSTRU = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredUserSecure)
        $CredUser = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRU)
        $CredPass = Get-Content "$ModuleLocation\SumoAuth1" | ConvertTo-SecureString
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$CredUser",$CredPass
      }
      else {
        Write-Error "Failure to find credentials. You must run New-SumoCredential before you can use the SumoTools Module."
        break
      }
    }
    $SumoBaseAPI = "https://api.sumologic.com/api"
  }
  
  Process {
    $SumoSourcesBase = "$SumoBaseAPI/v1/collectors/$CollectorID/sources"    
    Write-Verbose "Testing credentials and Collector ID..."
    $null = Invoke-WebRequest $SumoSourcesBase -Credential $Credential -ErrorVariable Failed
    if ($Failed) {break}
    if ($JSONFile) {
      Write-Verbose "Checking if file exists..."
      if (!(Test-Path $JSONFile)) {
        Write-Error "File not found: $JSONFile"
        break
      } 
      Write-Verbose "Invoking REST method for new source with $JSONFile..."
      $Output = Invoke-RestMethod -Uri $SumoSourcesBase -Method Post -ContentType "application/json" -InFile $JSONFile -Credential $Credential -ErrorVariable Failed
      if ($Failed) {break}
    }
    else {
      if ($LocalFile) {$SourceType = "LocalFile"}
      elseif ($Script) {$SourceType = "Script"}
      elseif ($SysLog) {$SourceType = "SysLog"}
      elseif ($LocalWindowsEventLog) {$SourceType = "LocalWindowsEventLog"}  
      elseif ($RemoteFileV2) {
        $SourceType = "RemoteFileV2"
        if (($RemotePassword -and $RemoteUser) -and !($KeyPassword -or $KeyPath)) {
          $RemotePasswordPlainText = (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "NULL",$RemotePassword).GetNetworkCredential().Password
          $authMethod = "password"
        }
      elseif (($KeyPassword -and $KeyPath) -and $RemoteUser -and !($RemotePassword)) {
        $KeyPasswordPlainText = (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "NULL",$KeyPassword).GetNetworkCredential().Password
        $authMethod = "key"          
      }
      else {
        Write-Error "RemoteFileV2 source supports two Authentication Methods. You must either use a combination of -RemoteUser / -RemotePassword, or -KeyPath / -KeyPassword / -RemoteUser parameters."
        break
      }
      }
      elseif ($RemoteWindowsEventLog) {
        $SourceType = "RemoteWindowsEventLog"
        $PasswordPlainText = (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "NULL",$Password).GetNetworkCredential().Password
      }
      $SourceSplat = [ordered]@{"sourceType"="$SourceType"}
      
      # Discovering what parameters were used in relevant parameter set
      $CommandName = $PSCmdlet.MyInvocation.InvocationName
      $ParameterList = Get-Command -Name $CommandName
      $PossibleParams = ($ParameterList.Parameters.Values | 
        where {(
          $_.ParameterSets.Keys -like "$SourceType"
          ) -or (
          $_.ParameterSets.Keys -like !"JSONFile")
        }
      ).Name
      
      # Create splat of appropriate source config items, and for Invoke-RestMethod
      foreach ($ParamUsed in $PSBoundParameters.Keys) {
        if (($ParamUsed | Select-String $PossibleParams) -and $ParamUsed -notlike "$SourceType") {
          # Property names in JSON have first letter lowercase; converting first
          $SplatProp = $ParamUsed -replace $ParamUsed.Substring(0,1),$ParamUsed.Substring(0,1).ToLower()
          if ($SplatProp -like "KeyPassword") {
            $SourceSplat += @{"$SplatProp"="$KeyPasswordPlainText"}
          }
          elseif ($SplatProp -like "RemotePassword") {
            $SourceSplat += @{"$SplatProp"="$RemotePasswordPlainText"}
          }
          elseif ($SplatProp -like "Password") {
            $SourceSplat += @{"$SplatProp"="$PasswordPlainText"}
          }
          else {
            $SourceSplat += @{"$SplatProp"=((Get-Variable -Name $ParamUsed).Value)}
          }
        }
      }
      # Ensure that the required "authMethod" property is included if needed
      if ($RemoteFileV2) {
        $SourceSplat += @{"authMethod"="$authMethod"}
      }
      $SourceContent = @{'source'=$SourceSplat}
      $SourceConfig = New-Object -TypeName PSObject -Property $SourceContent |
        ConvertTo-JSON
      $RESTSplat = @{'Uri'="$SumoSourcesBase";
                     'Method'="Post";
                     'ContentType'="application/json";
                     'Body'="$SourceConfig";
                     'Credential'=$Credential}

      Write-Verbose "Invoking REST method for new $SourceType source..."
      $Output = Invoke-RestMethod @RESTSplat
    }

    $Collector = Get-SumoCollector | where {$_.ID -eq $CollectorID}
    $Output.source | Add-Member -MemberType NoteProperty -Name collectorName -Value $Collector.Name
    $Output.source | Add-Member -MemberType NoteProperty -Name collectorID -Value $CollectorID
    $Output.source
  }
}

function Remove-SumoCollectorSource {
<#
	.SYNOPSIS
		Uses the Sumo Logic Collector Management API to remove a Source from a Collector.

	.DESCRIPTION
		Uses the Sumo Logic Collector Management API to remove a Source from a Collector. Will output WARNING messages when removing a source.

	.PARAMETER  CollectorID
		ID of the target collector. You can retrieve this value with Get-SumoCollector.

	.PARAMETER  SourceID
		ID of the target Collector Source. You can retrieve this value with Get-SumoCollectorSource. "ID" can also be used as an alias for this parameter.

  .PARAMETER  Credential
		Credentials for accessing the Sumo Logic API. Unneccessary if New-SumoCredential has been used.

	.EXAMPLE
		PS C:\>Get-SumoCollector -Name SUMOCOLLECT01 | Get-SumoCollectorSource | where {$_.Name -like "DECOMSERV01"} | Remove-SumoCollectorSource
    
      Removes the Sumo Collector Source named "DECOMSERV01" from the Sumo Collector named SUMOCOLLECT01.
      
	.INPUTS
		System.String

	.OUTPUTS
		None

	.LINK
		https://github.com/ScriptAutomate/SumoTools
  .LINK
    https://github.com/SumoLogic/sumo-api-doc/wiki
  .LINK
		https://halfwaytoinfinite.wordpress.com
    
  .COMPONENT
    Invoke-RestMethod
#>
[CmdletBinding()]
Param
(
  [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [String]$CollectorID,
  [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [Alias("ID")]
  [String]$SourceID,
  [Parameter(Mandatory=$False)]
  [System.Management.Automation.PSCredential]$Credential
)
  Begin {
    # Checking for credentials
    $ModuleLocation = (Get-Module SumoTools).Path.Replace('\SumoTools.psm1','')
    $SumoPass = "$ModuleLocation\SumoAuth1"
    $SumoUser = "$ModuleLocation\SumoAuth2"
    if (!$Credential) {
      if ((Test-Path "$SumoPass") -and (Test-Path "$SumoUser")) {
        $CredUserSecure = Get-Content "$ModuleLocation\SumoAuth2" | ConvertTo-SecureString
        $BSTRU = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredUserSecure)
        $CredUser = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRU)
        $CredPass = Get-Content "$ModuleLocation\SumoAuth1" | ConvertTo-SecureString
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$CredUser",$CredPass
      }
      else {
        Write-Error "Failure to find credentials. You must run New-SumoCredential before you can use the SumoTools Module."
        break
      }
    }
    $SumoBaseAPI = "https://api.sumologic.com/api"
  }
  
  Process {
    $SourceProperties = Get-SumoCollector -Credential $Credential | 
      where {$_.ID -eq $CollectorID} | 
      Get-SumoCollectorSource -Credential $Credential | 
      where {$_.ID -eq $SourceID}
    Write-Warning "REMOVING Sumo Collector Source $SourceID"
    Write-Warning "Collector Name: $($SourceProperties.CollectorName)"
    Write-Warning "Source Name: $($SourceProperties.Name)"
    $WebPageBase = "https://api.sumologic.com/api/v1/collectors/$CollectorID/sources/$SourceID"
    Invoke-RestMethod -Uri $WebPageBase -Method Delete -Credential $Credential -ErrorAction Stop
    Write-Warning "REMOVED Sumo Collector Source. Source Name: $($SourceProperties.Name)"
  }
}

function Remove-SumoCollector {
<#
	.SYNOPSIS
		Uses the Sumo Logic Collector Management API to remove a Sumo Collector.

	.DESCRIPTION
		Uses the Sumo Logic Collector Management API to remove a Sumo Collector. Will output WARNING messages when removing a source.

	.PARAMETER  ID
		ID of the target collector. You can retrieve this value with Get-SumoCollector. "CollectorID" can also be used as an alias for this parameter.

  .PARAMETER  Credential
		Credentials for accessing the Sumo Logic API. Unneccessary if New-SumoCredential has been used.

	.EXAMPLE
		PS C:\>Get-SumoCollector -Name SUMOCOLLECT01 | Remove-SumoCollector
    
      Removes the Sumo Collector named SUMOCOLLECT01.
      
	.INPUTS
		System.String

	.OUTPUTS
    None

	.LINK
		https://github.com/ScriptAutomate/SumoTools
  .LINK
    https://github.com/SumoLogic/sumo-api-doc/wiki
  .LINK
		https://halfwaytoinfinite.wordpress.com
    
  .COMPONENT
    Invoke-RestMethod
#>
[CmdletBinding()]
Param
(
  [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [Alias("CollectorID")]
  [String[]]$ID,
  [Parameter(Mandatory=$False)]
  [System.Management.Automation.PSCredential]$Credential
)
  Begin {
    # Checking for credentials
    $ModuleLocation = (Get-Module SumoTools).Path.Replace('\SumoTools.psm1','')
    $SumoPass = "$ModuleLocation\SumoAuth1"
    $SumoUser = "$ModuleLocation\SumoAuth2"
    if (!$Credential) {
      if ((Test-Path "$SumoPass") -and (Test-Path "$SumoUser")) {
        $CredUserSecure = Get-Content "$ModuleLocation\SumoAuth2" | ConvertTo-SecureString
        $BSTRU = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredUserSecure)
        $CredUser = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRU)
        $CredPass = Get-Content "$ModuleLocation\SumoAuth1" | ConvertTo-SecureString
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$CredUser",$CredPass
      }
      else {
        Write-Error "Failure to find credentials. You must run New-SumoCredential before you can use the SumoTools Module."
        break
      }
    }
    $SumoBaseAPI = "https://api.sumologic.com/api"
  }
  
  Process {
    foreach ($Collector in $ID) {
      try {
        $CollectorName = (Get-SumoCollector -Credential $Credential | where {$_.ID -eq $ID}).Name
        Write-Warning "REMOVING Sumo Collector $Collector."
        Write-Warning "Name: $CollectorName"
        $WebPageBase = "https://api.sumologic.com/api/v1/collectors/$Collector"
        Invoke-RestMethod -Uri $WebPageBase -Method Delete -Credential $Credential -ErrorAction Stop
        Write-Warning "REMOVED Sumo Collector $Collector. Name: $CollectorName"
      }
      catch {Write-Error $Error[0]}
    }
  }
}

function Set-SumoCollectorSource {
<#
	.SYNOPSIS
		Uses the Sumo Logic Collector Management API to modify a Sumo Collector Source.

	.DESCRIPTION
		Uses the Sumo Logic Collector Management API to modify a Sumo Collector Source. The returned JSON information is converted into happy PowerShell objects.

	.PARAMETER  ID
		ID of the target Collector Source. You can retrieve this value with Get-SumoCollectorSource. "SourceID" can also be used as an alias for this parameter.

  .PARAMETER  Credential
		Credentials for accessing the Sumo Logic API. Unneccessary if New-SumoCredential has been used.
      
	.INPUTS
		System.String

	.OUTPUTS
		System.Management.Automation.PSCustomObject

	.LINK
		https://github.com/ScriptAutomate/SumoTools
  .LINK
    https://github.com/SumoLogic/sumo-api-doc/wiki
  .LINK
		https://halfwaytoinfinite.wordpress.com
    
  .COMPONENT
    Invoke-RestMethod
#>
[CmdletBinding()]
Param
(
  [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [Alias("SourceID")]
  [Int]$ID,
  [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
  [Int]$CollectorID,
  [Parameter(Mandatory=$False)]
  [System.Management.Automation.PSCredential]$Credential,
  
  [Parameter(ParameterSetName="LocalFile",Mandatory=$True)]
  [Alias('LocalFileSource')]
  [Switch]$LocalFile,
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [String]$PathExpression,
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False)]
  [String[]]$BlackList,
  
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$True)]
  [Alias('RemoteFileSource')]
  [Switch]$RemoteFileV2,
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [String[]]$RemoteHosts,
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [Int]$RemotePort,
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [String]$RemoteUser,
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [System.Security.SecureString]$RemotePassword,
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [String]$KeyPath,
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [System.Security.SecureString]$KeyPassword,

  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$True)]
  [Alias('LocalWindowsEventLogSource')]
  [Switch]$LocalWindowsEventLog,
  
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$True)]
  [Alias('RemoteWindowsEventLogSource')]
  [Switch]$RemoteWindowsEventLog,
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [String]$Domain,
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [String]$UserName,
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [System.Security.SecureString]$Password,
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [String[]]$Hosts,
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False)]  
  [ValidateSet("Security","Application","System","Others")]
  [String[]]$LogNames,
  
  [Parameter(ParameterSetName="Syslog",Mandatory=$True)]
  [Alias('SysLogSource')]
  [Switch]$SysLog,
  [Parameter(ParameterSetName="Syslog",Mandatory=$False)]
  [String]$Port,
  [Parameter(ParameterSetName="Syslog",Mandatory=$False)]
  [String]$Protocol="UDP",

  [Parameter(ParameterSetName="Script",Mandatory=$True)]
  [Alias('ScriptSource')]
  [Switch]$Script,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [String[]]$ScriptBlock,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [String]$ScriptFile,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [String]$WorkingDirectory,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [Int]$TimeOutInMilliseconds,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [String]$CronExpression,
  
  # Properties shared across all sources
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False)]
  [Alias('SourceName')]
  [String]$Name,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False)]
  [String]$Description,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False)]
  [String]$Category,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False)]
  [String]$HostName,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False)]
  [String]$TimeZone,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False)]
  [Bool]$AutomaticDateParsing,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False)]
  [Bool]$MultilineProcessingEnabled,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False)]
  [Bool]$UseAutolineMatching,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False)]
  [String]$ManualPrefixRegexp,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False)]
  [Bool]$ForceTimeZone,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False)]
  [String]$DefaultDateFormat,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False)]
  [String]$CutOffTimeStamp,
  [Parameter(ParameterSetName="Script",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalFile",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteFileV2",Mandatory=$False)]
  [Parameter(ParameterSetName="Syslog",Mandatory=$False)]
  [Parameter(ParameterSetName="RemoteWindowsEventLog",Mandatory=$False)]
  [Parameter(ParameterSetName="LocalWindowsEventLog",Mandatory=$False)]
  [String]$CutoffRelativeTime
)
  Begin {
    # Checking for credentials
    $ModuleLocation = (Get-Module SumoTools).Path.Replace('\SumoTools.psm1','')
    $SumoPass = "$ModuleLocation\SumoAuth1"
    $SumoUser = "$ModuleLocation\SumoAuth2"
    if (!$Credential) {
      if ((Test-Path "$SumoPass") -and (Test-Path "$SumoUser")) {
        $CredUserSecure = Get-Content "$ModuleLocation\SumoAuth2" | ConvertTo-SecureString
        $BSTRU = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredUserSecure)
        $CredUser = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRU)
        $CredPass = Get-Content "$ModuleLocation\SumoAuth1" | ConvertTo-SecureString
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$CredUser",$CredPass
      }
      else {
        Write-Error "Failure to find credentials. You must run New-SumoCredential before you can use the SumoTools Module."
        break
      }
    }
    $SumoBaseAPI = "https://api.sumologic.com/api"
  }
  
  Process {
    $TargetSourceURI = "$SumoBaseAPI/v1/collectors/$CollectorID/sources/$ID"
    $Retrieve = Invoke-WebRequest $TargetSourceURI -Credential $Credential
    $ETAG = $Retrieve.Headers.Etag
    $ETAGHash = @{'If-Match'= "$ETAG"}
    $SourceConfig = ($Retrieve.Content | ConvertFrom-Json).Source
    $SourceConfigType = $SourceConfig.SourceType
    
    if ($LocalFile) {$SourceType = "LocalFile"}
    elseif ($Script) {$SourceType = "Script"}
    elseif ($SysLog) {$SourceType = "SysLog"}
    elseif ($LocalWindowsEventLog) {$SourceType = "LocalWindowsEventLog"}
    elseif ($RemoteWindowsEventLog) {
      $SourceType = "RemoteWindowsEventLog"
      $PasswordPlainText = (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "NULL",$Password).GetNetworkCredential().Password
    }
    elseif ($RemoteFileV2) {
      $SourceType = "RemoteFileV2"
      if (($RemotePassword -and $RemoteUser) -and !($KeyPassword -or $KeyPath)) {
        $RemotePasswordPlainText = (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "NULL",$RemotePassword).GetNetworkCredential().Password
        $authMethod = "password"
      }
      elseif (($KeyPassword -and $KeyPath) -and $RemoteUser -and !($RemotePassword)) {
        $KeyPasswordPlainText = (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "NULL",$KeyPassword).GetNetworkCredential().Password
        $authMethod = "key"          
      }
      else {
        Write-Error "RemoteFileV2 source supports two Authentication Methods. You must either use a combination of -RemoteUser / -RemotePassword, or -KeyPath / -KeyPassword / -RemoteUser parameters."
        break
      }
    }
    
    if ("$SourceConfigType" -ne "$SourceType") {
      Write-Error "Source has a sourceType that is different from Set-SumoCollectorSource parameter set. $($SourcConfig.Name) sourceType: $SourceConfigType -- Parameter set selected: $SourceType"
      break
    }
    
    $ConfigNames = ($SourceConfig | Get-Member -MemberType NoteProperty).Name
    $ConfigsSorted = $ConfigNames | sort
    $ParamsSorted = $PSBoundParameters.Keys | sort
    $Existing = (Compare-Object $ConfigNames $ParamsSorted -ExcludeDifferent -IncludeEqual).InputObject
    foreach ($ConfigName in $ConfigNames) {
      if ($Existing | select-string $ConfigName) {
        switch ($ConfigName) {
          "KeyPassword"     {New-Variable -Name "New$ConfigName" -Value "$KeyPasswordPlainText"}
          "RemotePassword"  {New-Variable -Name "New$ConfigName" -Value "$RemotePasswordPlainText"}
          "Password"        {New-Variable -Name "New$ConfigName" -Value "$PasswordPlainText"}
          default           {New-Variable -Name "New$ConfigName" -Value (Get-Variable -Name $ConfigName).Value}
        }
      }
      else {New-Variable -Name "New$ConfigName" -Value $SourceConfig.$ConfigName}
    }
    
    # Discovering what parameters were used in relevant parameter set
    $CommandName = $PSCmdlet.MyInvocation.InvocationName
    $ParameterList = Get-Command -Name $CommandName
    $PossibleParams = ($ParameterList.Parameters.Values | where {($_.ParameterSets.Keys -like "$SourceType")}).Name
    
    # Create splat of appropriate source config items, and for Invoke-RestMethod
    foreach ($ParamUsed in $PSBoundParameters.Keys) {
      if (($ParamUsed | Select-String $PossibleParams) -and $ParamUsed -notlike "$SourceType") {
        if ((Compare-Object $ParamUsed $ConfigNames | where {$_.SideIndicator -eq '<='})) {
          New-Variable -Name "New$ParamUsed" -Value (Get-Variable -Name "$ParamUsed").Value
        }
      }
    }

    foreach ($ConfigSetting in (Get-Variable -Name "New*" -Scope Local).Name) {
      # Property names in JSON have first letter lowercase; converting first
      $SplatName = $ConfigSetting -replace 'new',''
      $SplatName = $SplatName -replace $SplatName.Substring(0,1),$SplatName.Substring(0,1).ToLower()
      $SourceSplat += @{"$SplatName"=((Get-Variable -Name "$ConfigSetting").Value)}
    }
    $Props = @{'source'=$SourceSplat}
    $ModifiedSourceConfig = New-Object -TypeName PSObject -Property $Props | ConvertTo-Json
    Remove-Variable "Props","SourceSplat","New*" -Scope Local
    
    $RESTSplat = @{'Uri'="$TargetSourceURI"
                   'Method'="Put"
                   'ContentType'="application/json"
                   'Body'="$ModifiedSourceConfig"
                   'Headers'=$ETAGHash
                   'Credential'=$Credential}
             
    Write-Verbose "Invoking REST method for modified $SourceType source, $($SourceConfig.Name)..."
    $Output = Invoke-RestMethod @RestSplat
    $Collector = Get-SumoCollector -Credential $Credential | where {$_.ID -eq $CollectorID}
    $Output.source | Add-Member -MemberType NoteProperty -Name collectorName -Value $Collector.Name
    $Output.source | Add-Member -MemberType NoteProperty -Name collectorID -Value $CollectorID
    $Output.source
  }
}

#function Test-SumoRemoteWinLogSourceConfiguration {
#	$remoteKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($hive, "")
#	$ref = $remoteKey.OpenSubKey($registryKey);
#	if (!$ref) {
#		$false
#	} else {
#		$ref.Close()
#		$true
#	}
#}
#}
#
#function Set-SumoRemoteWinLogSourceConfiguration {
#
#}