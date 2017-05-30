# New-PSATAppDeployment
New-PSATAppDeployment function and associated files

What is New-PSATAppDeployment?
The New-PSATAppDeployment function is an aid to deploying SCCM applications packaged using the PowerShell Application Deployment Toolkit (PSAT).
Before getting into how the function works, the PSAT application needs some additional configuration. By default, the toolkit will only work with SCCM if the application is configured to install only when a user is logged on. In order to enable applications packaged with the PSAT to be deployed whether or not a user is logged on some extra files are required in the root folder of the application, PSExec.exe from the PSTools toolkit, ServiceUI.exe from the MDT toolkit, install.cmd and uninstall.cmd - the contents of which are shown below.

Install.cmd
psexec.exe -si -accepteula %~dp0serviceui %~dp0Deploy-Application.exe

Uninstall.cmd
psexec.exe -si -accepteula %~dp0serviceui %~dp0Deploy-Application.exe -DeploymentType Uninstall

Prior to running the New-PSATAppDeployment function your target application folder strucure should look like this:
Mode                LastWriteTime         Length Name                                                                                   
----                -------------         ------ ----                                                                                   
d-----       15/05/2017     21:34                AppDeployToolkit                                                                       
d-----       13/02/2017     03:37                Files                                                                                   
d-----       13/02/2017     03:37                SupportFiles                                                                           
-a----       19/12/2016     01:29         314880 Deploy-Application.exe                                                                 
-a----       19/12/2016     01:29            190 Deploy-Application.exe.config                                                           
-a----       13/02/2017     03:36           8970 Deploy-Application.ps1                                                                 
-a----       15/05/2017     21:39             69 Install.cmd                                                                             
-a----       28/06/2016     11:44         339096 PsExec.exe                                                                             
-a----       19/10/2015     09:37          70936 ServiceUI.exe                                                                           
-a----       15/05/2017     21:39             95 Uninstall.cmd                   

Applications and collections will be created in the root folder of the relevant area. The New-PSATAppDeployment function contains commented out sections on how these can be moved to other folders underneath the root.

