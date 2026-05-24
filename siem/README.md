# Wazuh SIEM (single-node)

The analyst SIEM for the lab — free and open-source, replacing the old Splunk
build. Three containers: **manager** (agent + ruleset), **indexer**
(OpenSearch-based storage), **dashboard** (the web UI you analyze in).

Pinned to **Wazuh 4.14.5**. Files vendored from the official
[wazuh/wazuh-docker](https://github.com/wazuh/wazuh-docker/tree/v4.14.5/single-node).

## Prerequisites

- Docker Desktop running (WSL2 backend on Windows).
- The indexer needs `vm.max_map_count >= 262144`. On Docker Desktop/WSL2:
  ```powershell
  wsl -d docker-desktop sysctl -w vm.max_map_count=262144
  ```
  (Re-apply after a full Docker restart, or set it persistently in `.wslconfig`.)

## Bring it up

```powershell
cd B:\A_LAB\siem

# 1. Generate the TLS certs (one time). Creates config/wazuh_indexer_ssl_certs/.
docker compose -f generate-indexer-certs.yml run --rm generator

# 2. Start the stack.
docker compose up -d

# 3. Watch it become healthy (indexer takes ~1-2 min on first boot).
docker compose ps
```

Open the dashboard at **https://localhost** (port 443, self-signed cert — accept
the browser warning).

## Default credentials  ⚠️ CHANGE THESE

These are the **public Wazuh demo defaults** shipped in the compose file. Fine for
an isolated lab, but change them before doing anything real:

| What            | User           | Password           |
|-----------------|----------------|--------------------|
| Dashboard login | `admin`        | `SecretPassword`   |
| Wazuh API       | `wazuh-wui`    | `MyS3cr37P450r.*-` |
| Indexer server  | `kibanaserver` | `kibanaserver`     |

To change the indexer/admin password you must re-hash it in
`config/wazuh_indexer/internal_users.yml` and update the env vars in
`docker-compose.yml`. See the
[Wazuh docs on changing passwords](https://documentation.wazuh.com/current/deployment-options/docker/docker-installation.html).

## Stop / reset

```powershell
docker compose down          # stop, keep data
docker compose down -v       # stop and WIPE all indexed data + volumes
```

## What gets logged here

Windows victim VM → Wazuh agent (+ Sysmon) → manager → indexer → dashboard.
You'll hunt Atomic Red Team / Shannon activity as alerts in the dashboard.
See [`../docs/03-attack-detect-workflow.md`](../docs/03-attack-detect-workflow.md).
