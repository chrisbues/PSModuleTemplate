$script:moduleName = 'Module'

# Add a TrimDay method to DateTime
Update-TypeData -TypeName System.DateTime -MemberName TrimDay -MemberType ScriptMethod -Value { [datetime]($this.ticks - ($this.ticks % ((New-TimeSpan -Days 1).ticks)))} -Force

## Required Modules
# Import Module Config
try {
    $script:moduleConfig = Import-PowerShellDataFile -Path "$PSScriptRoot\conf\conf.psd1"
}
catch {
    throwUser "Error loading module configuration file."
}

$publicFilter = [scriptblock]::create($moduleConfig.imports.Where( {$_.edition -eq $psedition }).public)
$privateFilter = [scriptblock]::create($moduleConfig.imports.Where( {$_.edition -eq $psedition }).private)

#Get public and private function definition files.
$Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue | Where-Object $publicFilter)
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue  | Where-Object $privateFilter)

#Dot source the files

Foreach($import in @($Public + $Private))
{
    Try
    {
        Write-Verbose "Importing $($Import.FullName)"
        . $import.fullname
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($import.fullname): $_" -ErrorAction Stop
    }
}

# Missing moduless
$hasErrors = $false

# Missing Modules
$missingModules = [System.Collections.Generic.List[psobject]]::new()


# Attempt to load modules
foreach ($module in $moduleConfig.psmodules.where({ $_.($psedition) -eq $true } )) {
    Write-Information "Loading module $($module.name)"

    $installedModule = Get-Module -ListAvailable -Name $module.name
    if ($null -eq $installedModule) {
        write-warning "Module $($module.name) is not installed."

        # Add to list of missing modules
        $missingModules.Add($module)


}
    else {
    # Get the latest installed version if more than one installed
    if ($installedModule.count -gt 1) {
        $latestVersion = ($installedModule | select-object version | Sort-Object)[-1]
        $installedModule = $installedModule.where( { $_.version -eq $latestVersion.version } )
    }

    # load the module
    try {
        Write-Verbose "Loading $($module.name) $($installedModule.version)"
        Import-module $installedModule -disablenamechecking -force
    }
    catch {
        write-error "Error loading $($module.name)"
        $hasErrors = $true
    }
    }
}

# Install missing modules
if ($missingModules.count -gt 0) {
    # Prompt to install missing modules

    $title = "Missing Modules"
    $message = "Do you want to install the missing modules?"

    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
        "Install the missing modules."

    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
        "Do not install the missing modules."

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

    $choice = $host.ui.PromptForChoice($title, $message, $options, 0)

    switch ($choice)
        {
            0 {
                # Selected Yes
                # Set PS Repo Trust
                try {
                    Write-Information "Setting PSGallery trust."
                    if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
                        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -Force
                    }
                }
                catch {
                    throwUser "Error setting PSGallery trust. Try running 'Set-psrepository -Name PSGallery -InstallationPolicy Trusted -Force' and attempt to reload this module."
                }

                # Install modules
                foreach ($missingModule in $missingModules) {
                    # install the module
                    try {
                        Write-Information "Installing $($missingModule.name)"
                        Install-Module -Name $missingModule.name -Force -Scope CurrentUser -AllowClobber
                        Import-module -name $missingModule.name -disablenamechecking -force
                    }
                    catch {
                        Write-warning "Error installing & importing $($missingModule.name). Try running 'Install-Module -Name $($missingModule.name) -Force -scope CurrentUser' and attempt to relaod this module."
                        $hasErrors = $true
                    }

                }
            }
            1 {
                # Selected No
                Write-Warning "Missing modules were not installed. This will cause errors."
                $hasErrors = $true
            }
        }
}

# Throw if we have any errors.
if ($true -eq $hasErrors) {
    throwUser "Supporting modules are not installed or did not install/load properly."
}
else {
    Write-Information "Module loaded successfully."
}

Export-ModuleMember -Function $Public.Basename