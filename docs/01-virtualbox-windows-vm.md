# 01 — VirtualBox Windows victim VM

The detonation host. We attack it and watch the telemetry land in Wazuh. Treat it
as **disposable** — snapshot before each exercise and roll back after.

## 1. Get a Windows image

Free, legal options:
- **Windows 11/10 Enterprise eval** — 90-day, from the
  [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise).
- **Pre-built dev VM** — Microsoft's
  [Windows 11 dev VM](https://developer.microsoft.com/windows/downloads/virtual-machines/)
  ships as a ready-to-import VirtualBox appliance (expires periodically).

## 2. Create the VM

Windows 11 has **hard minimums** the installer enforces — don't go below these:

| Resource | Win11 hard minimum | Use this (realistic) |
|----------|--------------------|----------------------|
| RAM      | 4 GB               | **8 GB (8192 MB)** — 4 GB is miserable once Sysmon + the agent run |
| CPU      | 2 cores            | **4 vCPUs** |
| Disk     | **64 GB**          | **80 GB+** dynamically allocated |
| Firmware | UEFI + Secure Boot | **Enable EFI** (wizard checkbox) |
| Security | **TPM 2.0**        | Settings → System → set TPM to v2.0 |

Without TPM 2.0 + Secure Boot + EFI, Win11 setup fails with "This PC can't run
Windows 11." Other notes:
- Graphics: **VBoxSVGA** controller, video memory **128 MB** (VBoxVGA can black-screen Win11).
- Enable the I/O APIC; nested VT-x not needed.
- Install VirtualBox **Guest Additions** after Windows boots (shared clipboard, better video).

> Host has Docker/WSL2 (Hyper-V) running? VirtualBox and Hyper-V contend for VT-x,
> which can cause slow or black-screen VMs. If that happens, see
> [`00-troubleshooting.md`](00-troubleshooting.md).

## 3. Networking — keep it contained

The VM must reach the Wazuh manager on your host **but never the public internet**
during exercises. Use a **Host-Only adapter**:

1. VirtualBox → Tools → Network → **Host-only Networks** → Create
   (gives you e.g. `192.168.56.1/24` on the host).
2. VM → Settings → Network → Adapter 1 → **Host-only Adapter** → select that network.
3. (Optional) Adapter 2 → **NAT**, kept **disabled** except when you need to install
   software/agents, then disable it again before detonating malware-like payloads.

Your host's host-only IP (e.g. `192.168.56.1`) is the address the Wazuh **agent**
will report to. Confirm it on the host:

```powershell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.56.*' }
```

> Wazuh manager ports must be reachable from the VM: **1514/tcp** (agent comms) and
> **1515/tcp** (enrollment). The Docker compose already publishes these on the host.

## 4. Snapshot strategy

```
Base          → clean Windows, Guest Additions installed
+ Tooling     → Sysmon + Wazuh agent + Atomic Red Team installed (see doc 02)
Ready-to-test ← roll back HERE before every exercise
```

Take the **Ready-to-test** snapshot once the agent is reporting green in Wazuh.
After each attack run, restore to it so detections start from a known-clean state.

## 5. Harden against escape (lab hygiene)

- Disable shared folders and drag-and-drop during detonation.
- Never log into personal accounts inside the VM.
- The VM and the Juice Shop / attack tooling all stay on the isolated network.

Next: [02 — Windows agent + Sysmon](02-windows-agent-sysmon.md).
