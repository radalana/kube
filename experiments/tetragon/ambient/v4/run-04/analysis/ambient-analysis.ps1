<#
Initial summary of policy matches in the final Tetragon ambient run.

For each cluster node, the script:
1. reads the recorded JSON event stream;
2. selects process_kprobe events with a non-empty policy_name;
3. counts raw policy records for each policy;
4. collects unique Tetragon exec_id values;
5. stores the node-level summary in $results.
Output:
The resulting node-level summary is stored in policy-counts-by-node.csv

RawRecords and UniqueExecIDs are descriptive values only.
They are not interpreted directly as detection occurrences.
#>

$ambient = ".\experiments\tetragon\ambient\v4\run-04\evidence"

$nodes = @{
    master  = "$ambient\master.json"
    worker1 = "$ambient\worker1.json"
    worker2 = "$ambient\worker2.json"
}
$results = @()
$policyEvents = @()
foreach ($node in $nodes.Keys) {

    Write-Host "`nProcessing $node ..."

    $stats = @{}

    Get-Content $nodes[$node] | ForEach-Object {

        if ([string]::IsNullOrWhiteSpace($_)) {
            return
        }

        try {
            $event = $_ | ConvertFrom-Json
        }
        catch {
            Write-Warning "Invalid JSON line on $node"
            return
        }

        $pk = $event.process_kprobe # Get the process_kprobe object from the event

        if ($null -eq $pk) { # Skip the event if it is not a process_kprobe event
            return
        }

        $policy = $pk.policy_name # Get the policy name, e.g. falco-ref-private-key-search

        if ([string]::IsNullOrWhiteSpace($policy)) { # Skip the event if policy_name is empty
            return
        }

        if (-not $stats.ContainsKey($policy)) {  # If this policy has not been seen yet on this hashtable
        # e.x falco-ref-private-key-search еще не встречалась, то создать ей значение чтобы было
        # [falco-ref-memfd-exec-stage: [number of raw records: exec_id]] то есть считали по exec id
            $stats[$policy] = @{
                RawRecords = 0
                ExecIDs    = [System.Collections.Generic.HashSet[string]]::new() #создай set 
            }
        }

        $stats[$policy].RawRecords++  #сразу увеличить счетчик

        $execId = $pk.process.exec_id
        $policyEvents += [PSCustomObject]@{ #to save individual all policy_events individually
            Node     = $node
            Time     = $event.time
            Policy   = $policy
            PID      = $pk.process.pid
            ExecID   = $execId
            Binary   = $pk.process.binary
            Function = $pk.function_name
}
        

        if (-not [string]::IsNullOrWhiteSpace($execId)) { #если не пустой еxecid до добавить его 
            [void]$stats[$policy].ExecIDs.Add($execId)
        }
    } # закончились events в ноде 

    foreach ($policy in $stats.Keys) { # еще в цикле по нодами

        $results += [PSCustomObject]@{
            Node          = $node
            Policy        = $policy
            RawRecords    = $stats[$policy].RawRecords
            UniqueExecIDs = $stats[$policy].ExecIDs.Count
        }
    }
}

$results |
    Sort-Object Policy, Node |
    Format-Table -AutoSize

# Group raw events by exec_id for each policy: repeat after that for each policy, so how many events belongs to one exec_id$policyEvents |

#select all raw events with "falco-ref-sensitive-read-untrusted"
sensitive = Where-Object {
    $_.Policy -eq "falco-ref-sensitive-read-untrusted"
}

$sensitive |
Group-Object Policy, ExecID |
Sort-Object Name |
Select-Object `
    @{Name='RawRecords'; Expression={$_.Count}},
    @{Name='Policy';     Expression={$_.Group[0].Policy}},
    @{Name='ExecID';     Expression={$_.Group[0].ExecID}} |
Format-Table -AutoSize

# save to file
$sensitiveByExec = $sensitive |
    Group-Object Policy, ExecID |
    Sort-Object Name |
    Select-Object `
        @{Name='RawRecords'; Expression={$_.Count}},
        @{Name='Policy';     Expression={$_.Group[0].Policy}},
        @{Name='ExecID';     Expression={$_.Group[0].ExecID}}

$sensitiveByExec |
Format-Table -AutoSize

#$sensitiveByExec |
#Export-Csv `
#    ".\experiments\tetragon\ambient\v4\run-04\analysis\sensitive-read-by-execid.csv" `
#    -NoTypeInformation

## falco-ref-memfd-exec-stage
$memfd = $policyEvents |
Where-Object {
    $_.Policy -eq "falco-ref-memfd-exec-stage"
}

$memfdByExec = $memfd |
Group-Object Policy, ExecID |
Sort-Object Name |
Select-Object `
    @{Name='RawRecords'; Expression={$_.Count}},
    @{Name='Policy';     Expression={$_.Group[0].Policy}},
    @{Name='ExecID';     Expression={$_.Group[0].ExecID}}

$memfdByExec |
Format-Table -AutoSize
##output in experiments\tetragon\ambient\v4\run-04\analysis\memfd-by-execid.csv

#Select all private-key search
 
$prkey = $policyEvents |
Where-Object {
$_,Policy -eq "falco-ref-private-key-search"
}

$prkeyByExec= $prkey | 
Group-Object Policy, ExecID |
Sort-Object Name |
Select-Object `
    @{Name='RawRecords'; Expression={$_.Count}},
    @{Name='Policy';     Expression={$_.Group[0].Policy}},
    @{Name='ExecID';     Expression={$_.Group[0].ExecID}}
prkeyByExec |
>> Format-Table -AutoSize
#output in experiments\tetragon\ambient\v4\run-04\analysis\private-key-search.csv



$targetExecID = "bWFzdGVyOjI4NDg2Mzc2NDM2MDcyNTM6MzQ1MjgzMA=="

foreach ($node in $nodes.Keys) {

    Get-Content $nodes[$node] | ForEach-Object {

        if ([string]::IsNullOrWhiteSpace($_)) {
            return
        }

        try {
            $event = $_ | ConvertFrom-Json
        }
        catch {
            return
        }

        $pk = $event.process_kprobe

        if (
            $null -ne $pk -and
            $pk.policy_name -eq "falco-ref-sensitive-read-untrusted" -and
            $pk.process.exec_id -eq $targetExecID
        ) {

            [PSCustomObject]@{
                Node     = $node
                Time     = $event.time
                PID      = $pk.process.pid
                Binary   = $pk.process.binary
                Function = $pk.function_name
                Args     = ($pk.args | ConvertTo-Json -Compress -Depth 10)
            }
        }
    }
}