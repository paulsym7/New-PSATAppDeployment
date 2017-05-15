# New-PSATAppDeployment
New-PSATAppDeployment function and associated files

What is New-PSATAppDeployment?
The New-PSATAppDeployment function is an aid to deploying SCCM applications packaged using the PowerShell Application Deployment Toolkit. It makes use PSExec.exe from the PSTools toolkit and ServiceUI.exe from the MDT toolkit. 
The function makes a couple of assumptions about the structure of the SCCM applications and collections folders. It will look to create applications underneath a folder named after the vendor of the application otherwise it will be created in the root folder. Similarly with collections, the function will look for an Applications\vendor folder to put the install and uninstall collections in. If one cannot be found the collections will be created in the root folder.
