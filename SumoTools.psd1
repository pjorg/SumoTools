#
# Module manifest for module 'SumoTools'
#
# Generated by: Derek Ardolf
#
# Generated on: 02/27/2015
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'SumoTools.psm1'

# Version number of this module.
ModuleVersion = '0.9'

# ID used to uniquely identify this module
GUID = 'fbdf89a0-dbfb-494d-946d-2399bf0a2336'

# Author of this module
Author = 'Derek Ardolf'

# Company or vendor of this module
CompanyName = 'https://github.com/ScriptAutomate'

# Copyright statement for this module
Copyright = '(c) 2015 Derek Ardolf. All rights reserved.'

# Description of the functionality provided by this module
Description = 'PowerShell functions running against the Sumo Logic API. Requires version 3.0 of PowerShell as data is returned in JSON format, and the module uses the ConvertFrom-Json function. All commands have been tested on PowerShell 4.0, but should work on v3.0+'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '4.0'

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module
FunctionsToExport = '*'

# Cmdlets to export from this module
# CmdletsToExport = '*'

# Variables to export from this module
# VariablesToExport = '*'

# Aliases to export from this module
# AliasesToExport = '*'

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
FileList = @('SumoTools.psm1','SumoTools.psd1')

# Private data to pass to the module specified in RootModule/ModuleToProcess
# PrivateData = ''

# HelpInfo URI of this module
# HelpInfoURI = '' #<--- Future GitHub URI path for updatable help!!

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}