#
# localTask.ps1
#

param()
$testPathInput = Get-VstsInput -Name 'testPathInput' -Require
$timeOutIn = Get-VstsInput -Name 'timeOutIn'
$uploadArtifact = Get-VstsInput -Name 'uploadArtifact' -Require
$artifactType = Get-VstsInput -Name 'artifactType'
$reportFileName = Get-VstsInput -Name 'reportFileName'

$uftworkdir = $env:UFT_LAUNCHER
$buildNumber = $env:BUILD_BUILDNUMBER
$pipelineName = $env:BUILD_DEFINITIONNAME

Import-Module $uftworkdir\bin\PSModule.dll

#---------------------------------------------------------------------------------------------------

function UploadArtifactToAzureStorage($storageContext, $container, $testPathReportInput, $artifact) {
	#upload artifact to storage container
	Set-AzStorageBlobContent -Container "$($container)" -File $testPathReportInput -Blob $artifact -Context $storageContext
}

function ArchiveReport($artifact, $reportFile) {
	$sourceFolder = Join-Path $reportFile -ChildPath "Report"
	if (Test-Path $sourceFolder) {
		$destinationFolder = Join-Path $reportFile -ChildPath $artifact
		Compress-Archive -Path $sourceFolder -DestinationPath $destinationFolder
		return $destinationFolder
	}
	return $null
}

function UploadHtmlReport($reports, $reportFileNames) {
	$index = 0
	foreach ( $item in $reports ) {
		$testPathReportInput =  Join-Path $item -ChildPath "Report\run_results.html"
		if (Test-Path $testPathReportInput) {
			$artifact = $reportFileNames[$index]
		
			# upload resource to container
			UploadArtifactToAzureStorage $storageContext $container $testPathReportInput $artifact
		}
		$index += 1
	}
}

function UploadArchive($reports, $archiveFileNames) {
	$index = 0
	foreach ( $item in $reports ) {
		#archive report folder	
		$artifact = $archiveFileNames[$index]
		
		$destinationFolder = ArchiveReport $artifact $item
		if ($destinationFolder) {
			UploadArtifactToAzureStorage $storageContext $container $destinationFolder $artifact
		}
					
		$index += 1
	}
}

#---------------------------------------------------------------------------------------------------

# delete old "UFT Report" file and create a new one
$uftReport = Join-Path $env:UFT_LAUNCHER -ChildPath ("res\Report_" + $buildNumber + "\UFT Report")

#run status summary Report
$runSummary = Join-Path $env:UFT_LAUNCHER -ChildPath ("res\Report_" + $buildNumber + "\Run Summary")

# delete old "TestRunReturnCode" file and create a new one
$retcodefile = Join-Path $env:UFT_LAUNCHER -ChildPath ("res\Report_" + $buildNumber + "\TestRunReturnCode.txt")

# remove temporary files complited
$results = Join-Path $env:UFT_LAUNCHER -ChildPath ("res\Report_" + $buildNumber +"\*.xml")

#junit report file 
$failedTests = Join-Path $uftworkdir -ChildPath ("res\Report_" + $buildNumber + "\Failed Tests")

$reports = New-Object System.Collections.Generic.List[System.Object]
$reportFileNames = New-Object System.Collections.Generic.List[System.Object]
$archiveFileNames = New-Object System.Collections.Generic.List[System.Object]

if ($testPathInput.Contains(".mtb")) { #batch file with multiple tests
	$XMLfile = $testPathInput
	[XML]$testDetails = Get-Content $XMLfile
	foreach($test in $testDetails.Mtbx.Test) {
		$reports.Add($test.path)
	}
} else { #single test or multiline tests
	$reports = $testPathInput.split([Environment]::NewLine)
	$testPathReportInput = Join-Path $testPathInput -ChildPath "Report\run_results.html"
}

if ($reportFileName) {
	$reportFileName = $reportFileName + '_' + $buildNumber
} else {
	$reportFileName = $pipelineName + "_" + $buildNumber
}
$ind = 1
foreach ($item in $reports) {
	$artifactName = $reportFileName + "_" + $ind + ".html"
	$archiveName = $reportFileName + "_Report_" + $ind + ".zip"
	$reportFileNames.Add($artifactName)
	$archiveFileNames.Add($archiveName)
	$ind += 1
}

$archiveNamePattern = $reportFileName + "_Report"

#---------------------------------------------------------------------------------------------------
#storage variables validation

if($uploadArtifact -eq "yes") {
	# get resource group
	if ($null -eq $env:RESOURCE_GROUP) {
		Write-Error "Missing resource group."
	} else {
		$group = $env:RESOURCE_GROUP
		$resourceGroup = Get-AzResourceGroup -Name "$($group)"
		$groupName = $resourceGroup.ResourceGroupName
	}

	# get storage account
	$account = $env:STORAGE_ACCOUNT

	$storageAccounts = Get-AzStorageAccount -ResourceGroupName "$($groupName)"

	$correctAccount = 0
	foreach($item in $storageAccounts) {
		if ($item.storageaccountname -like $account) {
			$storageAccount = $item
			$correctAccount = 1
			break
		}
	}

	if ($correctAccount -eq 0) {
		if ([string]::IsNullOrEmpty($account)) {
			Write-Error "Missing storage account."
		} else {
			Write-Error ("Provided storage account {0} not found." -f $account)
		}
	} else {
		$storageContext = $storageAccount.Context
		
		#get container
		$container = $env:CONTAINER

		$storageContainer = Get-AzStorageContainer -Context $storageContext -ErrorAction Stop | where-object {$_.Name -eq $container}
		if ($storageContainer -eq $null) {
			if ([string]::IsNullOrEmpty($container)) {
				Write-Error "Missing storage container."
			} else {
				Write-Error ("Provided storage container {0} not found." -f $container)
			}
		}
	}
}

#---------------------------------------------------------------------------------------------------
#Run the tests
Invoke-FSTask $testPathInput $timeOutIn $uploadArtifact $artifactType $env:STORAGE_ACCOUNT $env:CONTAINER $reportFileName $archiveNamePattern $buildNumber -Verbose 

#---------------------------------------------------------------------------------------------------
#upload artifacts to Azure storage
if ($uploadArtifact -eq "yes") {
	if ($artifactType -eq "onlyReport") { #upload only report
		UploadHtmlReport $reports $reportFileNames
	} elseif ($artifactType -eq "onlyArchive") { #upload only archive
		UploadArchive $reports $archiveFileNames
	} else { #upload both report and archive
		UploadHtmlReport $reports $reportFileNames
		UploadArchive $reports $archiveFileNames
	}
}

#---------------------------------------------------------------------------------------------------
# uploads report files to build artifacts
# upload and display Run Summary
if (Test-Path $runSummary) {
	Write-Host "##vso[task.uploadsummary]$($runSummary)"
}

# upload and display UFT report
if (Test-Path $uftReport) {
	Write-Host "##vso[task.uploadsummary]$($uftReport)"
}

# upload and display Failed Tests
if (Test-Path $failedTests) {
	Write-Host "##vso[task.uploadsummary]$($failedTests)"
}

# read return code
if (Test-Path $retcodefile) {
	$content = Get-Content $retcodefile
	[int]$retcode = [convert]::ToInt32($content, 10)
	
	if($retcode -eq 0) {
		Write-Host "Test passed"
	}

	if ($retcode -eq -3) {
		Write-Error "Task Failed with message: Closed by user"
	} elseif ($retcode -ne 0) {
		Write-Error "Task Failed"
	}
}

