$ErrorActionPreference='SilentlyContinue'

Remove-Item $PSScriptRoot\openPeersList_temp.txt
Copy-Item $PSScriptRoot\openPeersList.txt $PSScriptRoot\openPeersList_temp.txt

$list = Get-Content $PSScriptRoot\openPeersList_temp.txt
$i = 1

$newList = @()
"* Getting all peers from $($list.Count) nodes..."

foreach($node in $list -replace "http://",""){
	$i++
	$path = $PSScriptRoot
	$scriptBlock = {
		(Invoke-RestMethod -TimeoutSec 10 http://$Using:node/peers -ErrorAction SilentlyContinue | select -ExpandProperty data) `
	-replace "http://","" `
	-replace "tcp://","" `
	-replace "8800","8008" `
	-replace "8801","8009" | Out-File -Append $Using:path\peersList_temp.txt
	}
	Start-Job -ScriptBlock $scriptBlock -Name "node-$($i)" | Out-Null
}

$completed = $false
while($completed -eq $false) {
	$running = (Get-Job -State Running).Count
	$total = (Get-Job).Count
	$completedCount = (Get-Job -State Completed).Count
	$failedCount = (Get-Job -State Failed).Count

	Write-Progress -Activity "$completedCount of $total jobs complete..." -PercentComplete ($completedCount / $total * 100)
	Start-Sleep 1
	if (($completedCount + $failedCount) -eq $total) {
		$completed = $true
		Write-Progress -Activity "$completedCount of $total jobs complete..." -Completed
		Get-Job | Remove-Job
	}
}

$tempList = Get-Content $PSScriptRoot\peersList_temp.txt
"  - Found $($tempList.Count) nodes in peers lists -- Deduplicating..."
$templist = $tempList | sort | unique
$i = 1
"  - Checking $($templist.Count) nodes to see if the API port is open..."

foreach ($node in $tempList) {
	$i++
	$path = $PSScriptRoot
	$result = ""
	$scriptBlock = {
		try {
			irm -TimeoutSec 5 "http://$Using:node/blocks?limit=1"
			"http://$Using:node" | Out-File -Append $Using:path\openPeersList_temp.txt
		}
		catch {
			"http://$Using:node" | Out-File -Append $Using:path\closedPeersList_temp.txt
		}
	}
	Start-Job -ScriptBlock $scriptBlock -Name "node-$($i)" | Out-Null
}

$completed = $false
while($completed -eq $false) {
	$running = (Get-Job -State Running).Count
	$total = (Get-Job).Count
	$completedCount = (Get-Job -State Completed).Count
	$failedCount = (Get-Job -State Failed).Count

	Write-Progress -Activity "$completedCount of $total jobs complete..." -PercentComplete ($completedCount / $total * 100)
	Start-Sleep 1
	if (($completedCount + $failedCount) -eq $total) {
		$completed = $true
		Write-Progress -Activity "$completedCount of $total jobs complete..." -Completed
		Get-Job | Remove-Job
	}
}

"* Sorting and removing duplicates..."
$uniqueOpenPeers = Get-Content $PSScriptRoot\openPeersList_temp.txt | sort | unique
$uniqueOpenPeers | Out-File $PSScriptRoot\openPeersList.txt
"  - Found $($uniqueOpenPeers.count) unique open peers"

$uniqueClosedPeers = Get-Content $PSScriptRoot\closedPeersList_temp.txt | sort | unique
$uniqueClosedPeers | Out-File $PSScriptRoot\closedPeersList.txt
"  - Found $($uniqueClosedPeers.count) unique closed peers"

"* Cleaning up temp files..."
Remove-Item $PSScriptRoot\openPeersList_temp.txt
Remove-Item $PSScriptRoot\closedPeersList_temp.txt
Remove-Item $PSScriptRoot\peersList_temp.txt

"* All done!"