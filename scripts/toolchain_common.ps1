function Get-VivadoPreflightVersion([string]$Text,[string]$Part) {
  # Vivado echoes Tcl source; only standalone output lines are evidence.
  if ($Text -notmatch ('(?m)^TOOLCHAIN_PART_PASS '+[regex]::Escape($Part)+'\r?$') -or
      $Text -notmatch '(?m)^TOOLCHAIN_VIVADO_VERSION (\d{4}\.\d+(?:\.\d+)?)\r?$') { throw 'TOOL_PREFLIGHT: missing actual Vivado version/part output' }
  return $Matches[1]
}

function Initialize-Toolchain([string]$ConfigPath = '') {
  $root = Split-Path $PSScriptRoot -Parent
  if (!$ConfigPath) { $ConfigPath = Join-Path $root 'config/toolchain.psd1' }
  $config = Import-PowerShellDataFile -LiteralPath $ConfigPath
  $local = Join-Path $root 'toolchain.local.psd1'
  if (Test-Path -LiteralPath $local) {
    $overrides = Import-PowerShellDataFile -LiteralPath $local
    foreach ($key in $overrides.Keys) {
      if ($key -notin @('QuestaBin','VivadoBat','Part')) { throw "TOOL_CONFIG: unknown key $key" }
      $config[$key] = $overrides[$key]
    }
  }
  foreach ($pair in @(@('QuestaBin','APB_UART_QUESTA_BIN'),@('VivadoBat','APB_UART_VIVADO_BAT'),@('Part','APB_UART_PART'))) {
    $value = [Environment]::GetEnvironmentVariable($pair[1])
    if ($value) { $config[$pair[0]] = $value }
  }
  if ($config.Part -notmatch '^[a-zA-Z0-9_-]+$') { throw 'TOOL_CONFIG: invalid FPGA part' }
  if ($config.QuestaBin) {
    if (!(Test-Path -LiteralPath $config.QuestaBin -PathType Container)) { throw 'TOOL_CONFIG: QuestaBin does not exist' }
    $bin = (Resolve-Path -LiteralPath $config.QuestaBin).Path
    $env:PATH = $bin + [IO.Path]::PathSeparator + $env:PATH
    $env:APB_UART_QUESTA_BIN = $bin
  }
  if (!$config.VivadoBat) {
    $command = Get-Command vivado.bat -ErrorAction SilentlyContinue
    if ($command) { $config.VivadoBat = $command.Source }
  }
  $env:APB_UART_VIVADO_BAT = $config.VivadoBat
  $env:APB_UART_PART = $config.Part
  [pscustomobject]@{ questaBin=$config.QuestaBin; vivadoBat=$config.VivadoBat; part=$config.Part }
}
