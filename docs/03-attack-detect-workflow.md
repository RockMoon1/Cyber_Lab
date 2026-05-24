# 03 — Attack → detect workflow

The core learning loop. You play **both sides**: launch attacks, then hunt the
telemetry they generate in Wazuh. Two attack engines:

| Engine               | Attacks what        | Telemetry you hunt                         |
|----------------------|---------------------|--------------------------------------------|
| **Atomic Red Team**  | The Windows VM (endpoint TTPs) | Sysmon / Windows events → Wazuh alerts |
| **Shannon**          | OWASP Juice Shop (web app/API) | Web exploit activity, app/access logs  |

Always: **roll the VM back to the `Ready-to-test` snapshot** before a run so you
start clean.

---

## Part A — Endpoint TTPs with Atomic Red Team (Red Canary)

Run inside the VM. Each "atomic" maps to a MITRE ATT&CK technique, so you learn
the technique *and* its detection together.

```powershell
Import-Module "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" -Force

# T1059.001 — PowerShell execution. Show details first:
Invoke-AtomicTest T1059.001 -ShowDetails

# Run it:
Invoke-AtomicTest T1059.001

# Other good starter techniques:
Invoke-AtomicTest T1136.001   # Create local account
Invoke-AtomicTest T1053.005   # Scheduled task
Invoke-AtomicTest T1003       # Credential dumping (LSASS) — high-signal

# ALWAYS clean up afterward:
Invoke-AtomicTest T1059.001 -Cleanup
```

### Hunt it in Wazuh
1. Dashboard → **Threat Hunting** / **Security events**, filter `agent.name: win-victim`.
2. Filter by the technique: search `rule.mitre.id: T1059.001`.
3. Inspect the matching Sysmon event (process creation, command line, parent process).
4. Note which Wazuh **rule.id** fired — or notice if **nothing** fired (a detection gap
   to write a custom rule for later).

---

## Part B — Web app pentest with Shannon

Shannon is a white-box AI pentester for web apps/APIs. It reads Juice Shop's source,
finds attack vectors, and runs real exploits. It lives at `B:\A_LAB\shannon`.

### 1. Start the target (Juice Shop)
```powershell
cd B:\A_LAB\juice-shop
docker build -t juice-shop .
docker run --rm -p 3000:3000 juice-shop
# Juice Shop is now at http://localhost:3000
```

### 2. Configure & run Shannon
```powershell
cd B:\A_LAB\shannon
# First time: copy .env.example to .env and add your ANTHROPIC_API_KEY etc.
# Shannon needs its Temporal backend running:
docker compose up -d            # starts shannon-temporal

# Launch a pentest against the running Juice Shop:
./shannon   # SHANNON_LOCAL=1 launcher; follow its prompts / see shannon/README.md
```
Shannon produces a report of **proven** vulnerabilities (PoC included). Compare its
findings against the [sample Juice Shop report](../shannon/sample-reports).

### Hunt it in Wazuh
If you forward Juice Shop's container logs (or run it on the monitored VM), the
exploitation traffic — injection attempts, auth bypass, suspicious requests — shows
up as web/access events. Practice spotting Shannon's attacks in the noise.

---

## The purple-team loop

```
1. Snapshot: roll VM back to Ready-to-test
2. Attack:   run an Atomic test (endpoint) and/or Shannon (web)
3. Detect:   find the resulting events in Wazuh
4. Gap?:     if nothing fired, write a custom Wazuh rule and re-test
5. Clean up: -Cleanup atomics, restore snapshot
```

Every iteration teaches one technique end-to-end: how it works, what it leaves
behind, and whether your SIEM catches it. That's the whole point of the lab.

## Hard rules

- Attack **only** the lab VM and the lab's Juice Shop — never any other system.
- Keep the network isolated (host-only). Never expose the victim VM publicly.
- Atomic tests can be destructive — always run `-Cleanup` and rely on snapshots.
