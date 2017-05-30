
# New-PSATAppDeployment
What is New-PSATAppDeployment?
The New-PSATAppDeployment function is an aid to deploying SCCM applications packaged using the PowerShell Application Deployment Toolkit (PSAT).

Before getting into how the function works, the PSAT application needs some additional configuration. A prerequisite is to have PSExec.exe from the PSTools toolkit installed on the target machines, I normally deploy this separately into the C:\Windows directory.

By default, the toolkit only displays dialogue and progress windows when the SCCM application is configured to install only when a user is logged on. In order to enable applications packaged with the PSAT to be deployed whether or not a user is logged on some extra files are required in the root folder of the application,  ServiceUI.exe from the MDT toolkit, install.cmd and uninstall.cmd - the contents of which are shown below.


Install.cmd
psexec.exe -si -accepteula %~dp0serviceui %~dp0Deploy-Application.exe


Uninstall.cmd
psexec.exe -si -accepteula %~dp0serviceui %~dp0Deploy-Application.exe -DeploymentType Uninstall


Prior to running the New-PSATAppDeployment function your target application folder strucure should look like this:

AppDeployToolkit                  - folder containing the toolkit scripts
Files                             - folder containing the application install media
SupportFiles                      - folder containing any additional files required to install the application     
Deploy-Application.exe                                                                 
Deploy-Application.exe.config                                                           
Deploy-Application.ps1                                                                 
Install.cmd                                                                             
ServiceUI.exe                                                                           
Uninstall.cmd                   


# What does New-PSATAppDeployment do?
Running the New-PSATAppDeployment function will create install and uninstall collections, an application and deployment type, apply an icon to the application if one is found, distribute the content to all distribution points, create a required install deployment and an uninstall deployment.

When the -ADGroup switch is used, an active directory group will be created along with a query rule in the install collection to include this AD group as a member of the collection. An include rule is added to the uninstall collection to include the limiting collection as a member, an exclude rule is also added to exclude members of the install collection from the uninstall collection. (Useful for licensed applications, they will be in the uninstall collection unless they are explicitly added to the install collection.)


# Example use
New-PSATAppDeployment -ApplicationName '<name>' -Manufacturer '<manufacturer>' -SourcePath '\\SCCM01\Software\ApplicationName' -DetectionMethod '<{MSIProductCode>}'

More detailed help and further examples can be found by running Get-Help New-PSATAppDeployment -Full

Currently the detection method used with the function has to be a msi product code, adding additional parameter sets to handle file or registry detection methods is in the pipeline.
