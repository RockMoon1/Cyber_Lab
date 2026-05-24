# 00 — Troubleshooting

## Docker Desktop crash loop: "initializing Inference manager" (Windows)

**Symptom.** Docker Desktop won't start. On launch it shows:

> An unexpected error occurred — Docker Desktop encountered an unexpected error and needs to close.
> ```
> starting services: initializing Inference manager: listening on
> unix://<HOME>\AppData\Local\Docker\run\dockerInference: remove ...\dockerInference:
> The file cannot be accessed by the system.
> (listener: The filename, directory name, or volume label syntax is incorrect.)
> ```

It then relaunches the backend and crashes again, in a loop (`backend process
exited`, `running backend: exit status 0xffffffff`).

**Cause.** Docker's **Model Runner / Inference manager** tries to bind a unix-socket
at a Windows path (`unix://C:\...`), which is invalid on Windows. The leftover
`dockerInference` entry becomes a corrupt reparse point that **no** file tool can
delete (`Remove-Item`, `del`, `fsutil reparsepoint delete`, and `\\?\` paths all fail
with "the file cannot be accessed by the system"). Every launch re-creates and
re-trips on it. Seen on Docker Desktop **4.73.0**.

**What does NOT fix it:**
- Deleting `...\AppData\Local\Docker\run\dockerInference` — undeletable.
- Renaming the `run` dir — Docker just recreates the same broken socket.
- Setting `EnableDockerAI: false` in `settings-store.json` — that's **Gordon**, a
  *different* feature. Also, Docker rewrites/removes `settings-store.json` on crash.

**The fix — force-disable inference via Settings Management (applied before
services init):** create `C:\ProgramData\Docker\admin-settings.json`:

```json
{
  "configurationFileVersion": 2,
  "enableInference": { "locked": true, "value": false },
  "enableDockerAI":  { "locked": true, "value": false }
}
```

Then fully stop Docker and relaunch:

```powershell
Get-Process | Where-Object { $_.Name -match 'docker' } | Stop-Process -Force
Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe' -WorkingDirectory 'C:\Program Files\Docker\Docker'
```

Docker now skips the Inference manager and the engine starts normally. To re-enable
Model Runner later, edit `value` to `true` (or delete the file). If it still loops,
fall back to a clean reinstall (`winget uninstall Docker.DockerDesktop` →
delete `%AppData%\Docker` and `%LocalAppData%\Docker` → `winget install Docker.DockerDesktop`).

---

## Wazuh indexer won't start / dashboard says "indexer not ready"

- Ensure `vm.max_map_count >= 262144` in the Docker WSL VM:
  `wsl -d docker-desktop sysctl -w vm.max_map_count=262144`
- The indexer needs ~1–2 min after `docker compose up` before the dashboard can log
  in. Check health: `docker exec siem-wazuh.indexer-1 curl -sk -u admin:SecretPassword https://localhost:9200/_cluster/health`
  — wait for `"status":"green"` (or `yellow`).
