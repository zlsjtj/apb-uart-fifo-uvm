Set-StrictMode -Version Latest

function Get-CampaignSeed([int]$BaseSeed, [ValidateSet('fixed','expanded')][string]$Mode='fixed', [int]$CampaignSeed=0) {
  if ($BaseSeed -lt 1 -or $CampaignSeed -lt 0 -or ($Mode -eq 'expanded' -and $CampaignSeed -eq 0)) { throw 'SEED_CONFIG: positive campaign seed required in expanded mode' }
  $actual=[long]$BaseSeed
  if ($Mode -eq 'expanded') { $actual += $CampaignSeed }
  if ($actual -gt 2147480000) { throw 'SEED_CONFIG: seed overflow' }
  return [int]$actual
}

function Get-UvmOutcome([string]$Text, [int]$ExitCode) {
  $summary = $Text -match '(?m)^#?\s*UVM_ERROR\s*:\s*0\s*$' -and
             $Text -match '(?m)^#?\s*UVM_FATAL\s*:\s*0\s*$' -and
             $Text -match '\[TEST_DONE\]' -and $Text -match '\[SB_SUMMARY\]'
  $lines = $Text -split '\r?\n'
  $failedLines = @()
  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^#?\s*UVM_(ERROR|FATAL)\s+\S+.*\[[^\]]+\]' -or
        $lines[$i] -match '^#?\s*\*\*\s*(Error|Fatal):') {
      $record = $lines[$i]
      # Questa prints the assertion identity in its immediately following
      # Time/Scope continuation, not in a separate unrelated log message.
      if ($record -match 'Assertion error' -and $i+1 -lt $lines.Count -and
          $lines[$i+1] -match '^#?\s*Time:.*Scope:') { $record += ' ' + $lines[$i+1] }
      $failedLines += $record
    }
  }
  $toolProblem = $Text -match '(?i)license checkout failed|error loading design|failed to load|\[TIMEOUT\]|\*\* Fatal:'
  $warnings = $Text -match '(?m)^#?\s*UVM_WARNING\s*:\s*[1-9]' -or
              $Text -match '(?m)^#?\s*\*\*\s*Warning:'
  [pscustomobject]@{
    pass = ($ExitCode -eq 0 -and $summary -and !$toolProblem -and !$warnings -and $failedLines.Count -eq 0)
    complete = [bool]$summary
    toolProblem = [bool]($toolProblem -or $ExitCode -ne 0 -or $Text -notmatch '\[TEST_DONE\]')
    failureLines = $failedLines
  }
}

function Get-MutationOutcome([string]$Baseline, [int]$BaselineExit,
                             [string]$Mutant, [int]$MutantExit, [string]$Detector) {
  $base = Get-UvmOutcome $Baseline $BaselineExit
  $mut = Get-UvmOutcome $Mutant $MutantExit
  $hit = @($mut.failureLines | Where-Object { $_ -match $Detector })
  $result = if (!$base.pass) { 'INVALID_BASELINE' }
            elseif ($mut.toolProblem) { 'INVALID_RUN' }
            elseif ($hit.Count -gt 0) { 'KILLED' } else { 'SURVIVED' }
  [pscustomobject]@{ result=$result; baselinePass=$base.pass; matchedFailureLines=$hit }
}

function Get-SourceIdentity([string]$Root = (Get-Location).Path) {
  $files = @()
  foreach ($dir in @('rtl','tb','scripts','config','constraints')) {
    $p = Join-Path $Root $dir
    if (Test-Path $p) { $files += Get-ChildItem -LiteralPath $p -File -Recurse }
  }
  foreach ($f in @('filelist.f','rtl_filelist.f')) { $files += Get-Item -LiteralPath (Join-Path $Root $f) }
  $rows = @($files | Sort-Object FullName | ForEach-Object {
    [pscustomobject]@{ path=$_.FullName.Substring($Root.Length).TrimStart('\','/').Replace('\','/'); sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
  })
  $bytes = [Text.Encoding]::UTF8.GetBytes((($rows | ForEach-Object { "$($_.path) $($_.sha256)" }) -join "`n"))
  $digest = [Security.Cryptography.SHA256]::Create()
  try { $hash = [BitConverter]::ToString($digest.ComputeHash($bytes)).Replace('-','').ToLowerInvariant() }
  finally { $digest.Dispose() }
  [pscustomobject]@{ sha256=$hash; files=$rows }
}

function Assert-SourceIdentity($Expected, [string]$Root = (Get-Location).Path) {
  $actual = Get-SourceIdentity $Root
  if ($actual.sha256 -ne $Expected.sha256) { throw 'SOURCE_DRIFT: source files changed during the run' }
}

function Write-EvidenceJson([string]$Path, $Value) {
  $parent = Split-Path -Parent $Path
  New-Item -ItemType Directory -Force $parent | Out-Null
  # A new file is renamed over the target only after the complete JSON exists.
  $temp = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
  $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $temp -Encoding UTF8
  Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Assert-CoverageTotals([string]$Text) {
  $rows = @()
  foreach ($name in @('Covergroup Bins','Cover Directives','Assertions')) {
    $pattern = '(?m)^\s*' + [regex]::Escape($name) + '\s+(\d+)\s+(\d+)\s+(\d+)\s+\d+\s+([\d.]+)'
    if ($Text -notmatch $pattern) { throw "COVERAGE_MISSING: $name" }
    $active=[int]$Matches[1]; $hits=[int]$Matches[2]; $misses=[int]$Matches[3]
    if ($active -le 0 -or $hits -ne $active -or $misses -ne 0) { throw "COVERAGE_INCOMPLETE: $name $hits/$active" }
    $rows += [pscustomobject]@{ metric=$name; active=$active; hits=$hits; misses=$misses; result='PASS' }
  }
  return $rows
}
