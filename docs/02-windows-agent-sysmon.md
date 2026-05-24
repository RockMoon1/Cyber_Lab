# 02 — Sysmon + Wazuh agent on the victim VM

This is what turns the Windows VM into a sensor. **Sysmon** produces rich
process/network/registry telemetry; the **Wazuh agent** ships it to the manager.
Run these inside the VM (temporarily enable the NAT adapter to download, then
disable it again).

## 1. Install Sysmon (with a good config)

Sysmon's default config is noisy/empty — use a community ruleset.

```powershell
# Download Sysmon
Invoke-WebRequest https://download.sysinternals.com/files/Sysmon.zip -OutFile $env:TEMP\Sysmon.zip
Expand-Archive $env:TEMP\Sysmon.zip -DestinationPath $env:TEMP\Sysmon -Force

# SwiftOnSecurity config (well-tuned starting point)
Invoke-WebRequest https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml -OutFile $env:TEMP\sysmonconfig.xml

# Install as a service
& $env:TEMP\Sysmon\Sysmon64.exe -accepteula -i $env:TEMP\sysmonconfig.xml
```

Verify events are flowing: Event Viewer →
`Applications and Services Logs → Microsoft → Windows → Sysmon → Operational`.

## 2. Install the Wazuh agent

Point it at your host's **host-only IP** (the `WAZUH_MANAGER` value from doc 01,
e.g. `192.168.56.1`):

```powershell
$manager = "192.168.56.1"   # <-- your host's host-only IP
Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.5-1.msi -OutFile $env:TEMP\wazuh-agent.msi
msiexec.exe /i $env:TEMP\wazuh-agent.msi /q WAZUH_MANAGER=$manager WAZUH_AGENT_NAME=win-victim WAZUH_REGISTRATION_SERVER=$manager
NET START WazuhSvc
```

## 3. Tell the agent to read the Sysmon channel

Edit `C:\Program Files (x86)\ossec-agent\ossec.conf` and add inside `<ossec_config>`:

```xml
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

Then restart the agent:

```powershell
Restart-Service WazuhSvc
```

## 4. Confirm enrollment in Wazuh

In the dashboard (**https://localhost**) → **Agents** → you should see `win-victim`
as **Active**. If it's stuck "Never connected":

- From the VM: `Test-NetConnection 192.168.56.1 -Port 1514` must succeed.
- Check the host firewall isn't blocking 1514/1515 inbound from the host-only subnet.
- Agent logs: `C:\Program Files (x86)\ossec-agent\ossec.log`.

## 5. (Recommended) Install Atomic Red Team for doc 03

Atomic Red Team is already present on the host at
`C:\Users\lpell\Documents\WindowsPowerShell\Modules\Invoke-AtomicRedTeam`. To set it
up **inside the VM**:

```powershell
IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
Install-AtomicRedTeam -getAtomics
Import-Module "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" -Force
```

Once the agent is green and Atomics are installed, **take the "Ready-to-test"
snapshot** (doc 01, step 4).

Next: [03 — Attack → detect workflow](03-attack-detect-workflow.md).
