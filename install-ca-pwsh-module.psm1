function install-ca-pwsh-module{
    param (
        $module_name,
        $nuget_repo_name
    )
    $guid = (new-guid).guid
    $local_tmp_dir = $env:temp + "\" + $guid
    try{
        write-host "creating temp directory " + $local_tmp_dir
        new-item -ItemType directory $local_tmp_dir
        $nugetexe = "nuget.exe"
        $flags = "install", $module_name, "-outputdirectory", $local_tmp_dir, "-source", $nuget_repo_name
        & $nugetexe @flags
    }catch{
        remove-item -Recurse -Force -Path $local_tmp_dir
        return "package download failed, cleaning up"
    }
    try{
        write-host "Registering local repository"
        register-psrepository -name $guid -SourceLocation $local_tmp_dir -PublishLocation $local_tmp_dir -InstallationPolicy Trusted
    }catch{
        remove-item -Recurse -Force -Path $local_tmp_dir
        return "Registering local repository failed, cleaning up"
    }
    try{
        write-host "checking to see if module is already installed"
        $installed_modules = Get-Module -ListAvailable | where-object {$_.name -eq $module_name}
        if($installed_modules.count -eq 0){
            write-host "Module " $module_name " not found, installing"
        }
        if($installed_modules.count -eq 1){
            $installed_version = $installed_modules.version.major.ToString() + "." + $installed_modules.version.minor.ToString() + ".0"
            write-host "Module" $module_name "found"
            write-host "version" $installed_version "installed"
            $camoduleversion = (find-module $module_name -Repository $guid).version
            if($camoduleversion -gt $installed_version){
                write-host "Module on codeartifact is newer, installing"
            }else{
                write-host "Local version is up to date, exiting"
                unregister-psrepository -name $guid
                remove-item -Recurse -Force -Path $local_tmp_dir
                return "Installing Module skipped"
            }
        }
        if($installed_modules.count -gt 1){ 
            $camoduleversion = (find-module $module_name -Repository $guid).version
            $latest_installed_module_version = ($installed_modules.version | measure -maximum).maximum
            $latest_installed_module_version = $latest_installed_module_version.major.ToString() + "." + $latest_installed_module_version.minor.ToString() + ".0"
            if($camoduleversion -gt $latest_installed_module_version){
                write-host "Module on codeartifact is newer, installing"
            }else{
                write-host "Local version is up to date, exiting"
                unregister-psrepository -name $guid
                remove-item -Recurse -Force -Path $local_tmp_dir
                return "Installing Module skipped"
            }
        }
    }catch{
        write-host "version lookup failed, cleaning up"
        unregister-psrepository -name $guid
        remove-item -Recurse -Force -Path $local_tmp_dir
        return "Installing Module failed"
    }
    try{
        write-host "installing module " + $module_name 
        install-module $module_name -Repository $guid
    }catch{
        unregister-psrepository -name $guid
        remove-item -Recurse -Force -Path $local_tmp_dir
        return "Installing Module Failed, cleaning up"
    }
    unregister-psrepository -name $guid
    remove-item -Recurse -Force -Path $local_tmp_dir
    return "Module Installed Successfully"
}
