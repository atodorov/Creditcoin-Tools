$ErrorActionPreference= 'silentlycontinue'
$nodes = "creditcoin-node.gluwa.com:8008","creditcoin-gateway.gluwa.com:8008","aurora:8008","node-000.creditcoin.org:8008","node-001.creditcoin.org:8008","node-002.creditcoin.org:8008","node-003.creditcoin.org:8008","node-004.creditcoin.org:8008","node-005.creditcoin.org:8008"

$list = @()
$i = 1

"[Round 1]"
foreach($node in $nodes){
	" - Checking node $i of $($nodes.Count) [$node]..."
	$list += (Invoke-RestMethod -TimeoutSec 5 http://$node/peers -ErrorAction SilentlyContinue | select -ExpandProperty data) `
		-replace "http://","" `
		-replace "tcp://","" `
		-replace "8800","8008" `
		-replace "8801","8009"
	$list = $list -replace ":8008",":8008`n" -replace ":8009",":8009`n" -replace " ","" -Split "`n" | ? {$_ -ne ""} | sort | unique
	$i++
}

$newList = @()
$i = 1

"[Round 2]"
foreach($node in $list){
	" - Checking node $i of $($list.Count) [$node]..."
	$newList += (Invoke-RestMethod -TimeoutSec 5 http://$node/peers -ErrorAction SilentlyContinue | select -ExpandProperty data) `
		-replace "http://","" `
		-replace "tcp://","" `
		-replace "8800","8008" `
		-replace "8801","8009"
	$newList = $newList | sort | unique
	$i++
}

$diffList = @()
$diffList = Compare-Object -ReferenceObject $list -DifferenceObject $newList | Where SideIndicator -eq "=>" | Select -ExpandProperty InputObject
$diffList = $diffList -replace ":8008",":8008`n" -replace ":8009",":8009`n" -replace " ","" -Split "`n" | ? {$_ -ne ""} | sort | unique

$list += $diffList
$list += $nodes
$list = $list -replace ":8008",":8008`n" -replace ":8009",":8009`n" -replace " ","" -Split "`n" | ? {$_ -ne ""} | sort | unique
$round = 3

while ($diffList.count -gt 0) {
	"[Round $($round)]"
	$round++
	$newList = @()
	$i = 1
	foreach($node in $diffList){
		" - Checking node $i of $($diffList.Count) [$node]..."
		$newList += (Invoke-RestMethod -TimeoutSec 5 http://$node/peers -ErrorAction SilentlyContinue | select -ExpandProperty data) `
			-replace "http://","" `
			-replace "tcp://","" `
			-replace "8800","8008" `
			-replace "8801","8009"
		$newList = $newList -replace ":8008",":8008`n" -replace ":8009",":8009`n" -replace " ","" -Split "`n" | ? {$_ -ne ""} | sort | unique
		$i++
	}
	$diffList = @()
	
	if($newList) {
		$diffList = Compare-Object -ReferenceObject $list -DifferenceObject $newList | Where SideIndicator -eq "=>" | Select -ExpandProperty InputObject
		$diffList = $diffList -replace ":8008",":8008`n" -replace ":8009",":8009`n" -replace " ","" -Split "`n" | ? {$_ -ne ""}
	} else {
		$diffList = @()
	}
	$list += $diffList
	$list += $nodes
	$list += $newList
	$list = $list -replace ":8008",":8008`n" -replace ":8009",":8009`n" -replace " ","" -Split "`n" | ? {$_ -ne ""} | sort | unique
}

$newList = @()
$i = 1

"[Final Round]"
foreach($node in $list){
	" - Checking node $i of $($list.Count) [$node]..."
	$newList += (Invoke-RestMethod -TimeoutSec 5 http://$node/peers -ErrorAction SilentlyContinue | select -ExpandProperty data) `
		-replace "http://","" `
		-replace "tcp://","" `
		-replace "8800","8008" `
		-replace "8801","8009"
	$newList = $newList | sort | unique
	$i++
}

$diffList = @()
$diffList = Compare-Object -ReferenceObject $list -DifferenceObject $newList | Where SideIndicator -eq "=>" | Select -ExpandProperty InputObject
$diffList = $diffList -replace ":8008",":8008`n" -replace ":8009",":8009`n" -replace " ","" -Split "`n" | ? {$_ -ne ""}
$list += $diffList
$list = $list -replace ":8008",":8008`n" -replace ":8009",":8009`n" -replace " ","" -Split "`n" | ? {$_ -ne ""} | sort | unique

"[Done Gathering Nodes]"

"[Checking Node Port Status]"
$openList = @()
$closedList = @()
$i = 1

foreach ($node in $list) {
	" - Testing node $i of $($list.Count) [$node]..."
	$result = ""
	try {
		$result = irm -TimeoutSec 5 "http://$node/blocks?limit=1"
		
		$openList += "http://$node"
	}
	catch {
		$closedList += "http://$node"
	}
	$i++
}

$openList | sort | unique | Out-File $PSScriptRoot\openPeersList.txt
$closedList | sort | unique | Out-File $PSScriptRoot\closedPeersList.txt
"[Done Checking Node Port Status]"