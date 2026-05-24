<#
  Cyber_Lab — Windows victim VM provisioning
  Run in an ELEVATED PowerShell INSIDE the Windows VM, with internet (NAT) on.
  Idempotent: re-running only fixes what's missing. Safe to run repeatedly.
#>

$manager  = '192.168.56.1'                       # Wazuh manager (host-only IP)
$agentDir = 'C:\Program Files (x86)\ossec-agent'
$cfg      = Join-Path $agentDir 'ossec.conf'

Write-Host "[1/4] Wazuh agent..." -ForegroundColor Cyan
if (-not (Test-Path $agentDir)) {
    $msi = "$env:TEMP\wazuh-agent.msi"
    Invoke-WebRequest 'https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.5-1.msi' -OutFile $msi -UseBasicParsing
    Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /q WAZUH_MANAGER=$manager WAZUH_AGENT_NAME=win-victim" -Wait
}
Stop-Service WazuhSvc -ErrorAction SilentlyContinue
# point agent at the manager
(Get-Content $cfg) -replace '<address>.*?</address>', "<address>$manager</address>" | Set-Content $cfg
# enroll only if not already enrolled
$keys = Join-Path $agentDir 'client.keys'
if (-not (Test-Path $keys) -or -not (Get-Content $keys -ErrorAction SilentlyContinue)) {
    & (Join-Path $agentDir 'agent-auth.exe') -m $manager -A win-victim
}
# make sure the Sysmon channel is forwarded
if (-not (Select-String -Path $cfg -Pattern 'Sysmon/Operational' -Quiet)) {
@"

<ossec_config>
  <localfile>
    <location>Microsoft-Windows-Sysmon/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
</ossec_config>
"@ | Add-Content $cfg
}

Write-Host "[2/4] Sysmon..." -ForegroundColor Cyan
if (-not (Get-Service Sysmon64 -ErrorAction SilentlyContinue)) {
    $sd = "$env:TEMP\sysmon"; New-Item -ItemType Directory -Force $sd | Out-Null
    Invoke-WebRequest 'https://download.sysinternals.com/files/Sysmon.zip' -OutFile "$sd\Sysmon.zip" -UseBasicParsing
    Expand-Archive "$sd\Sysmon.zip" -DestinationPath $sd -Force
    Invoke-WebRequest 'https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml' -OutFile "$sd\sysmonconfig.xml" -UseBasicParsing
    & "$sd\Sysmon64.exe" -accepteula -i "$sd\sysmonconfig.xml"
}

Write-Host "[3/4] Start agent..." -ForegroundColor Cyan
Start-Service WazuhSvc

Write-Host "[4/4] Atomic Red Team..." -ForegroundColor Cyan
Add-MpPreference -ExclusionPath 'C:\AtomicRedTeam' -ErrorAction SilentlyContinue
if (-not (Test-Path 'C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1')) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
    Install-AtomicRedTeam -getAtomics -Force
}
Import-Module 'C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1' -Force

Write-Host "`n[+] Verification:" -ForegroundColor Green
Get-Service WazuhSvc, Sysmon64 | Select-Object Name, Status
if (Get-Command Invoke-AtomicTest -ErrorAction SilentlyContinue) { Write-Host "Invoke-AtomicTest: available" -ForegroundColor Green }
else { Write-Host "Invoke-AtomicTest: NOT available" -ForegroundColor Red }
Write-Host "`nNote: Invoke-AtomicTest must be re-imported in EACH new PowerShell session:" -ForegroundColor Yellow
Write-Host "  Import-Module 'C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1' -Force"
