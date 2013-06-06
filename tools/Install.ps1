param($rootPath, $toolsPath, $package, $project)

"Installing PackageRestore to project [{0}]" -f $project.FullName | Write-Host

$importLabel = "PackageRestore"
# This is the label of the <SolutionDir property in packageRestore.proj
$labelLabelForSolutionDir = "PackageRestoreSolutionDir"

function GetSolutionDirFromProj{
    param($msbuildProject)

    if(!$msbuildProject){
        throw "msbuildProject is null"
    }

    $result = $null
    $solutionElement = $null
    foreach($pg in $msbuildProject.PropertyGroups){
        foreach($prop in $pg.Properties){
            if([string]::Compare("SolutionDir",$prop.Name,$true) -eq 0){
                $solutionElement = $prop
                break
            }
        }
    }

    if($solutionElement){
        $result = $solutionElement.Value
    }

    return $result
}

# we need to update the packageRestore.proj file to have the correct value for SolutionDir
function UpdatePackageRestoreSolutionDir (){
    param($pkgRestorePath, $solDirValue)
    if(!(Test-Path $pkgRestorePath)){
        throw ("pkgRestore file not found at {0}" -f $pkgRestorePath)
    }

    $solDirElement = $null
    $root = [Microsoft.Build.Construction.ProjectRootElement]::Open($pkgRestorePath)
    foreach($pg in $root.PropertyGroups){
        foreach($prop in $pg.Properties){
            if([string]::Compare($labelLabelForSolutionDir,$prop.Label,$true) -eq 0){
                $solDirElement = $prop
                break
            }
        }
    }
    
    if($solDirElement){
        $solDirElement.Value = $solDirValue

        $root.Save()

    }
}

#########################
# Start of script here
#########################

$projFile = $project.FullName

# Make sure that the project file exists
if(!(Test-Path $projFile)){
    throw ("Project file not found at [{0}]" -f $projFile)
}

# Before modifying the project save everything so that nothing is lost
$DTE.ExecuteCommand("File.SaveAll")

# TODO: Does this need to be closed?
$projectMSBuild = [Microsoft.Build.Construction.ProjectRootElement]::Open($projFile)

# now update the packageRestore.proj file with the correct path for SolutionDir
$solnDirFromProj = GetSolutionDirFromProj -msbuildProject $projectMSBuild
if($solnDirFromProj) {
    $pkgRestorePath = (Join-Path (get-item $project.FullName).Directory 'packageRestore.proj')
    UpdatePackageRestoreSolutionDir -pkgRestorePath $pkgRestorePath -solDirValue $solnDirFromProj
}
else{
    $msg = @"
    SolutionDir property not found in project [{0}].
    Have you enabled NuGet Package Restore? This is required for build server support.
    You may need to enable it and to enable it and re-install this package
"@ 
    $msg -f $project.Name | Write-Host -ForegroundColor Red
}

"    PackageRestore has been installed into project [{0}]" -f $project.FullName| Write-Host -ForegroundColor DarkGreen
"    `nFor more info how to enable PackageRestore on build servers see http://sedodream.com/2012/12/24/SlowCheetahBuildServerSupportUpdated.aspx" | Write-Host -ForegroundColor DarkGreen