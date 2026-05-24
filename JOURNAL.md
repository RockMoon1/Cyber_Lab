# Lab Journal

A running worklog of what we built, broke, fixed, and found — newest first.
Updated automatically at the end of each session ("lets call it").

---

## 2026-05-24 — Lab rebuild + first detection

**Built / accomplished**
- Rebuilt the lab from scratch, **version-controlled in GitHub** this time (RockMoon1/Cyber_Lab).
- Replaced **Splunk → Wazuh** (free, no paywall): official single-node stack pinned to 4.14.5 in `siem/`.
- Consolidated the old `C:\Users\lpell\soc-lab` (Shannon + Juice Shop) into `B:\A_LAB`.
- Stood up the Wazuh stack (manager + indexer + dashboard) and Shannon's Temporal backend in Docker.
- Built the **Windows 11 victim VM** (`GID1`) in VirtualBox with a **caged network**: nic1 Host-Only
  (Wazuh at 192.168.56.1), nic2 NAT (toggle off to detonate); clipboard/drag-drop/shared-folders disabled.
- Installed + configured the **Wazuh agent** (enrolled as `win-victim`), **Sysmon** (SwiftOnSecurity config),
  and **Atomic Red Team**. Added idempotent `vm/provision-victim.ps1` so it's reproducible.
- Snapshots: `clean-base` and `ready-to-test`.
- **First attack → detect:** ran Atomic `T1059.001` (PowerShell execution) → Wazuh fired, incl.
  **rule 92057** (level 12, base64-encoded PowerShell) and **rule 92213** (level 15, executable dropped
  in malware-common folder), plus 92027/92032/61618. Full purple-team loop validated.

**Found / lessons**
- **Docker Desktop 4.73 crash loop** — the Inference manager (Model Runner) tried to bind a `unix://C:\...`
  socket and crashed on an undeletable corrupt reparse point. Fix: `C:\ProgramData\Docker\admin-settings.json`
  with `enableInference` locked `false`. (`EnableDockerAI` is a *different* feature — Gordon.) See `docs/00-troubleshooting.md`.
- **Win11 VM minimums** were quoted too low at first — disk min is **64 GB** (not 60), realistic is 8 GB RAM / 4 vCPU.
- **Hyper-V vs VirtualBox** — because Docker uses WSL2 (Hyper-V), VirtualBox runs in Hyper-V mode; **live/online
  snapshots and "save machine state" hang**. Always snapshot while powered off; always *power off* (never save state).
- A fresh PowerShell session must re-import the Atomic module:
  `Import-Module 'C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1' -Force`.

**Next time**
- Higher-signal techniques: `T1003` (credential dump), `T1136.001` (create account), `T1053.005` (scheduled task).
- Write a custom Wazuh rule in `local_rules.xml` for a technique that doesn't alert (detection engineering).
- Point **Shannon** at **Juice Shop** for the web/app-pentest half of the lab.
