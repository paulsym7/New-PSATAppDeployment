function New-PSATAppDeployment {
<#
.Synopsis
   Use this function to create an application deployment within SCCM for an application the uses the PowerShell Application Deployment Toolkit. The function will create an Active Directory group, an application and deployment type, install and uninstall collections and install and uninstall deployments.
.DESCRIPTION
   Use this function to create an application deployment within SCCM for an application the uses the PowerShell Application Deployment Toolkit. The function will create an Active Directory group, an application and deployment type, install and uninstall collections and install and uninstall deployments.
   Members of the active directory group will be added to the install collection by a query rule which the function generates.
   The uninstall collection will have its limiting collection included by an include collection rule and the install collection will be excluded from collection membership by an exclude collection rule.
   The application has a deployment type added that ensures the install and uninstall scripts run as 32-bit applications, sets the deployment type to run whether or not the user is logged on, extends the maximum allowed runtime to allow time for the PSAT dialogues to timeout and adds a dependency for the PSExec application.
.PARAMETER ApplicationName
   The name of the application to be be deployed
.PARAMETER Manufacturer
   The vendor of the application
.PARAMETER Version
   The version of the application being deployed. If no value is specified version 1.0 will be used
.PARAMETER SourcePath
   The full UNC path to the folder containing the install files e.g. \\SCCM\Content\Applications\MyApp
.PARAMETER DetectionMethod
   The MSI product code of the application being deployed (including the {} curly braces)
.PARAMETER MaxRuntime
The maximum allowed runtime in minutes for the SCCM application, default is 180 minutes
.EXAMPLE
   Create-CMAppDeployment -ApplicationName 'Visio Standard' -Manufacturer Microsoft -Version '2013' -SourcePath '\\SCCM01\Software\Microsoft\Visio2013' -DetectionMethod '{90150000-0053-0000-0000-0000000FF1CE}' -Verbose

   This example will create an Active Directory group, an application and deployment type, install and uninstall collections, install and uninstall deployments for Microsoft Visio Standard 2013
.EXAMPLE
   Create-CMAppDeployment -ApplicationName Photoshop -Manufacturer Adobe -Version 'CC 2015' -SourcePath '\\SCCM01\Software\Adobe\AdobePhotoshopCC2015' -DetectionMethod '{1BBD1E71-DBEA-42FF-A7B9-DCE3C1DB2209}' -MaxRuntime 240

   This example will create an Active Directory group, an application and deployment type, install and uninstall collections, install and uninstall deployments for Adobe Photoshop CC 2015 and sets the maximum allowed runtime in minutes for the SCCM application to 4 hours
#>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,
                   HelpMessage='Enter the name of the application')]
        [string]$ApplicationName,

        [Parameter(Mandatory=$true,
                   HelpMessage='Enter the manufacturer of the application')]
        [string]$Manufacturer,

        [string]$Version = '1.0',

        [Parameter(Mandatory=$true,
                   HelpMessage='Enter the full UNC path to the folder containing the install files')]
        [ValidateScript({
            If(Test-Path FileSystem::$_ -PathType Container){
                $True
            }
            Else{
                Throw "$_ cannot be found, verify the path is correct"
            }
        })]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true,
                   HelpMessage='Enter the MSI product code of the application, including the {} curly braces')]
        [string]$DetectionMethod,

        [int]$MaxRuntime = 180
    )

    BEGIN{
        $location = Get-Location
        # Import ConfigurationManager module
        If(-not(Get-PSProvider -PSProvider CMSite)){
            $modulepath = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\ConfigMgr10\Setup').'UI Installation Directory' + 'bin'
            $SiteServerName = (Get-ItemProperty HKLM:\SOFTWARE\Wow6432Node\Microsoft\ConfigMgr10\AdminUI\Connection -Name Server).Server  
            $ProviderLocation = Get-CimInstance -ComputerName $SiteServerName -Namespace root\sms SMS_ProviderLocation -filter "ProviderForLocalSite='True'" 
            $SiteCode = $ProviderLocation.SiteCode 
            Import-Module $modulepath\ConfigurationManager.psd1
        }

        Set-Location $SiteCode":"
        $Domain = (Get-ADDomain).NetBIOSName
        $LimitingCollection = 'SMS00001' # or use (Get-CMDeviceCollection -Name '<Your limiting collection>').CollectionId to use a different collection
        $ADGroupOU = 'OU=SCCM Groups,DC=contoso,DC=com' # use the distinguished name of OU where the AD group that will be used for the install collection query rule resides
        $iconpath = '\\SCCM\Software\Icons'

    }

    PROCESS{
        # Does the application, collections or AD group already exist?
        $FullName = "$Manufacturer $ApplicationName $Version"
        $AppInstall = "Install $fullname"
        $UninstallCollection = "Uninstall $fullname"
        $ok = $true
        # Check for AD group
        If(Get-ADGroup -Filter {Name -like $AppInstall}){
            Write-Warning "The active directory group $AppInstall already exists"
            $ok = $false
        }
        # Check for application
        If(Get-CMApplication -Name $AppInstall){
            Write-Warning "The application name $AppInstall is already in use"
            $ok = $false
        }
        # Check for device collections
        If(Get-CMDeviceCollection -Name $AppInstall){
            Write-Warning "The device colletion $AppInstall already exists"
            $ok = $false
        }
        If(Get-CMDeviceCollection -Name $UninstallCollection){
            Write-Warning "The device colletion $UninstallCollection already exists"
            $ok = $false
        }
        # If ok is true the ad group, application and collection names are not already in use
        If($ok){
            Write-Verbose "The AD Group name will be $AppInstall`nThe SCCM Application name will be $FullName`nThe SCCM Install collection name will be $AppInstall`nThe SCCM Uninstall collection name will be $UninstallCollection"
            # Create AD group
            New-ADGroup -Name $AppInstall -Path $ADGroupOU -DisplayName $AppInstall -Description "Used to install $FullName via SCCM" -GroupScope Global
            Write-Verbose "Created an active directory group named $AppInstall"
            # Create device collections, install collection has a refresh schedule of 4 hours, uninstall collection has a refresh schedule of 1 day
            $installschedule = New-CMSchedule -RecurInterval Hours -RecurCount 4 -Start (get-date -format o)
            New-CMDeviceCollection -LimitingCollectionId $LimitingCollection -Name $AppInstallName -Comment "Members of this collection get the $FullName software installed" -RefreshSchedule $installschedule | Out-Null
            Write-Verbose "Created an install collection named $AppInstallName"
            $uninstallschedule = New-CMSchedule -RecurInterval Day -RecurCount 1 -Start (get-date -format o)
            New-CMDeviceCollection -LimitingCollectionId $LimitingCollection -Name $UninstallCollection -Comment "Members of this collection get the $FullName software removed" -RefreshSchedule $uninstallschedule | Out-Null
            Write-Verbose "Created an uninstall collection named $UninstallCollection"
            # Add the limiting collection as a member of the uninstall collection
            Add-CMDeviceCollectionIncludeMembershipRule -CollectionName $UninstallCollection -IncludeCollectionId $LimitingCollection
            Write-Verbose "Created an include rule to include the <limiting collection name> as members of the $UninstallCollection collection"
            # Add a query rule to include the ad group as members of the install colleciton
            Add-CMDeviceCollectionQueryMembershipRule -CollectionName $AppInstall -QueryExpression "select *  from  SMS_R_System where SMS_R_System.SecurityGroupName = `"$domain\\$AppInstall`"" -RuleName 'Include AD group members'
            Write-Verbose "Created a query rule to include members of the $AppInstall as members of the collection"
            # Exclude the install collection from the uninstall collection
            Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $UninstallCollection -ExcludeCollectionName $AppInstall
            Write-Verbose "Created an exclude rule to exclude members of the $AppInstall collection from the $UninstallCollection collection"
            # Move the collections to the manufacturer subfolder
            $colfolders = (Get-ChildItem $SiteCode':\DeviceCollection\applications').name
            If($colfolders -contains $Manufacturer){
                $colfolderpath = $SiteCode + ":\DeviceCollection\applications\$Manufacturer"
            }
            Else{
                $colfolderpath = $SiteCode + ':\DeviceCollection'
            }
            Move-CMObject -FolderPath $colfolderpath -InputObject (Get-CMDeviceCollection -Name $AppInstall)
            Move-CMObject -FolderPath $colfolderpath -InputObject (Get-CMDeviceCollection -Name $UninstallCollection)
            Write-Verbose "Moved the $AppInstall and $UninstallCollection collections into the $colfolderpath folder"
            # Create new application and add an icon if one exists in the $iconfile path
            if((Get-ChildItem -path FileSystem::$iconpath).name -contains "$ApplicationName.ico"){
                New-CMApplication -Name $FullName -AutoInstall $true -Publisher $Manufacturer -SoftwareVersion $Version -IconLocationFile "$iconpath\$ApplicationName.ico" -LocalizedName $FullName | Out-Null
            }
            else{
                New-CMApplication -Name $FullName -AutoInstall $true -Publisher $Manufacturer -SoftwareVersion $Version -LocalizedName $FullName | Out-Null
            }
            Write-Verbose "Created an application named $FullName"
            $appfolders = (Get-ChildItem -Path $SiteCode':\application').name
            If($appfolders -contains $Manufacturer){
                $appfolderpath = $SiteCode + ":\application\$Manufacturer"
            }
            Else{
                $appfolderpath = $SiteCode + ':\application'
            }
            Move-CMObject -FolderPath $appfolderpath -inputobject (Get-CMApplication -Name $AppInstall)
            Write-Verbose "Moved the $AppInstall application into the $appfolderpath folder"
            # Create a deployment type
            Add-CMScriptDeploymentType -ApplicationName $FullName -DeploymentTypeName "PSAT - $FullName" -InstallCommand 'Install.cmd' -UninstallCommand 'Uninstall.cmd' -Force32Bit -LogonRequirementType WhetherOrNotUserLoggedOn `
            -MaximumRuntimeMins 180 -InstallationBehaviorType InstallForSystem -ContentLocation $SourcePath -ProductCode $detectionmethod | Out-null
            Write-Verbose "Created a deployment type named 'PSAT - $AppInstall' for the $AppInstall application"
            # Add dependency for PSExec
            Add-CMDeploymentTypeDependency -InputObject (Get-CMDeploymentType -ApplicationName $FullName | New-CMDeploymentTypeDependencyGroup -GroupName 'PSExec') -DeploymentTypeDependency (Get-CMDeploymentType -ApplicationName PSExec) -IsAutoInstall $true
            # Distribute content
            Start-CMContentDistribution -ApplicationName $FullName -DistributionPointGroupName 'All Distribution Points'
            Write-Verbose "Distributing the $FullName application to the 'All Distribution Points' distribution point group"
            # Create deployments
            New-CMApplicationDeployment -Name $FullName -DeployAction Install -DeployPurpose Required -UserNotification DisplaySoftwareCenterOnly -CollectionName $AppInstall -AvailableDateTime (Get-Date -Format g) -OverrideServiceWindow $true | out-null
            Write-Verbose "Created a required install deployment for $FullName"
            New-CMApplicationDeployment -Name $FullName -DeployAction Uninstall -DeployPurpose Required -UserNotification HideAll -CollectionName $UninstallCollection -AvailableDateTime (Get-Date -Format g) -OverrideServiceWindow $true | out-null
            Write-Verbose "Created a required uninstall deployment for $FullName"
        }
        Else{
            Write-Warning "One or more AD group, application or collection names are already in use. Please ensure application names and version are unique before trying again"
        }
    }

    END{
        Set-Location $location
    }
}
