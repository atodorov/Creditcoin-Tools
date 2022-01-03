Write-Host ""
Write-Host "$(Get-Date)"

$csvFile = "$PSScriptRoot\nodeDetails.csv"

if (Test-Path $csvFile) {
	$oldData = Import-Csv $csvFile
	$haveOldData = $true
}

Get-Job | Remove-Job -Force

$allNodes = Get-Content "$PSScriptRoot\openPeersList.txt"
$octets = $allNodes -replace "http://","" -replace ":8008","" | Select-String -Pattern "^[0-9]{1,3}" -AllMatches | % {$_.Matches} | % {$_.Value } | unique

$nodes = @()

foreach ($octet in $octets){
	$regex = "^http://$octet"
	$nodes += $allNodes -match "^http://$($octet)" | Select -First 2
}

# Add Gluwa nodes
$nodes += "http://creditcoin-gateway.gluwa.com:8008",
           "http://creditcoin-node.gluwa.com:8008",
           "http://node-000.creditcoin.org:8008",
           "http://node-001.creditcoin.org:8008",
           "http://node-002.creditcoin.org:8008",
           "http://node-003.creditcoin.org:8008",
           "http://node-004.creditcoin.org:8008",
           "http://node-005.creditcoin.org:8008"
		   

# Discover external, non-Gluwa nodes, for a more-complete reference
$external_nodes = @()
foreach ($node in $nodes) {
	$nodeParts = $node -replace "http://","" -split ":"

	if ((Test-Connection -IPv4 $nodeParts[0] -TCPPort $nodeParts[1] -TimeoutSeconds 2) -eq $false) {
		Write-Warning "Node $($nodeParts[0]) is unreachable"
		continue
	}

	# Get peers info
	try {
		$peers = Invoke-RestMethod -TimeoutSec 10 -Uri "$node/peers" -ErrorAction SilentlyContinue

		foreach($peer in $peers.data) {
			$peer = $peer -Replace "tcp://","http://" -Replace ":8800",":8008"
			If (($peer -In $nodes) -Or ($peer -In $external_nodes)) {
				# skip
			} Else {
				$external_nodes += $peer
			}
		}
	}
	catch {
		continue
	}
}
Write-Warning "EXTERNAL PEERS: $external_nodes"
$nodes += $external_nodes

$nodes = $nodes | where {$_ -notmatch "149."} | sort | unique
$nodes = $nodes | where {$_ -notmatch "40.118.206.48"} | sort | unique

foreach ($node in $nodes) {
	$nodeBad = $false
	$nodeParts = $node -replace "http://","" -split ":"
	
	if ((Test-Connection -IPv4 $nodeParts[0] -TCPPort $nodeParts[1] -TimeoutSeconds 2) -eq $false) {
		$nodeBad = $true
		Write-Warning "Node $($nodeParts[0]) is unreachable"
	}
	else {
		$i++
		$scriptBlock = {
				$peers = ""
				$tip = ""
				$peersCount = "???"
				$peersOpen = $null
				$peersClosed = $null
				$diff = $null
				$consensus = $null
				$blockID = ""
				
				# Get block info
				try {
					$data = Invoke-RestMethod -TimeoutSec 20 "$Using:node/blocks?limit=1" -ErrorAction SilentlyContinue
					
					$cParts = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($data.data.header.consensus)) -split ":"
					$diff = $cParts[1]
					$tip = $data.data.header.block_num
					$consensus = $cParts[0]
					$timestamp = $cParts[3]
					$timestamp = (([System.DateTimeOffset]::FromUnixTimeSeconds($timestamp)).DateTime).ToString("u")
					$blockID = $data.data.header_signature
					$blockID = $blockID.Substring(0,5) + "..." + $blockID.Substring(123,5)
					
					if ($tip -eq "") { $tip = "Timed Out" }
					if ($diff -eq "") { $diff = "N/A" }
				}
				catch {
					$message = "Blockchain on " + ($Using:node -Replace "http://","" -Replace ":[0-9]{1,6}","") + " is not ready"
					Write-Warning $message
					break
				}
				
				try {
					$housekeepingState = irm "$Using:node/state/8a1a049000000000000000000000000000000000000000000000000000000000000000" -ErrorAction SilentlyContinue
					$housekeeping = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($housekeepingState.data))
				}
				catch {
					$housekeeping = "Unknown"
				}
				
				# Get peers info
				try {
					$peers = Invoke-RestMethod -TimeoutSec 10 "$Using:node/peers" -ErrorAction SilentlyContinue
					$peersCount = $peers.data.count

					foreach($peer in $peers.data) {
						$state = $null
						$peerSplit = $peer -Replace "tcp://","" -Split ":"
						if (($peerSplit[1] -eq $null) -OR ($peerSplit[1] -eq ""))
						{
							$port = 8800
						}
						else
						{
							$port = $peerSplit[1]
						}
						$state = Test-Connection -TcpPort $port -IPv4 $peerSplit[0] -TimeoutSeconds 2 -ErrorAction SilentlyContinue
						if ($state -eq $true) {
							$peersOpen++
						}
						else {
							$peersClosed++
						}
					}
				}
				catch {
					$message = "Validator on " + ($Using:node -Replace "http://","" -Replace ":[0-9]{1,6}","") + " is not ready"
					Write-Warning $message
					$peersOpen = "???"
					$peersClosed = "???"
				}
				
				if($peersOpen -eq $null) { $peersOpen = 0 }
				if($peersClosed -eq $null){ $peersClosed = 0 }

				
				$hash = @{
					Node = $Using:node -Replace "http://","" -Replace ":[0-9]{1,6}",""
					Peers = $peersCount
					Open = $peersOpen
					Closed = $peersClosed
					Tip = $tip
					BlockID = $blockID
					Timestamp = $timestamp
					Housekeeping = $housekeeping
					Consensus = $consensus
					Difficulty = $diff
				}
				$object = New-Object PSObject -Property $hash
				$object
		}
		Start-Job -ScriptBlock $scriptBlock -Name $peer | Out-Null
	}
}

$progress = "..."
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
	}
}

$jobs = Get-Job
$allNodes = @()

foreach ($job in $jobs) {
	$allNodes += Receive-Job -Id $job.Id -Keep
}

Get-Job | Remove-Job

$allNodesWithchange = @()

foreach ($node in $allNodes) {
	$oldBlock = $oldData | where Node -eq ($node.Node -Replace "http://","" -Replace ":[0-9]{1,6}","") | select -ExpandProperty Tip
	$newBlock = $node.Tip
	if ($oldBlock -eq "Timed Out" -OR $newBlock -eq "Timed Out" -OR $oldBlock -eq $null) {
		$change = "*"
	}
	else {
		$change = '{0:N0}' -f ($newBlock - $oldBlock)
		$change = $change -as [int]
		if($change -eq "*") {
			$change = "*"
		}
		elseif($change -gt 0) {
			$change = "$($change)"
		}
		elseif($change -lt 0) {
			$change = "$($change)"
		}
		else {
			$change = "-"
		}
	}
	
	$hash = @{
		Node = $node.Node -Replace "http://","" -Replace ":[0-9]{1,6}",""
		Peers = $node.Peers
		Open = $node.Open
		Closed = $node.Closed		
		Tip = $node.Tip
		BlockID = $node.BlockID
		Timestamp = $node.Timestamp
		Housekeeping = $node.Housekeeping
		Consensus = $node.Consensus
		Difficulty = $node.Difficulty
		Change = $change
	}
	$object = New-Object PSObject -Property $hash
	$allNodesWithchange += $object
}

$allNodesWithchange | Sort-Object -Descending { [int]$_.Tip } | Format-Table Node,Peers,Open,Closed,Tip,BlockID,Timestamp,Housekeeping,Difficulty,Consensus,Change
$allNodesWithchange | Export-Csv $csvFile

Write-Host ("*"*75)
