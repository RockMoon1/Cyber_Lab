# Cyber_Lab

A self-hosted **SOC / purple-team learning lab**. Spin up a vulnerable Windows
environment in VirtualBox, attack it with an AI pentester (**Shannon**) and
**Atomic Red Team** (by Red Canary), and watch the telemetry land in a free,
open-source SIEM (**Wazuh**) so you can practice detection and analysis end to end.

> Replaces the old Splunk-based build — Wazuh is fully free with no paywall.

## Why this exists

I've built this lab three times and lost it each time. This repo is the durable
copy: the orchestration, configs, and runbooks live here in git so the lab is
reproducible from scratch.

## Architecture

```
                 ┌──────────────────────────────┐
                 │   Host (Windows 11 + Docker)  │
                 │                               │
   attack  ┌─────┴─────┐   logs    ┌─────────────┴───────────┐
  ┌────────►  Shannon  │           │   Wazuh SIEM (Docker)    │
  │        │ (AI pentest)│         │  manager + indexer + UI  │
  │        └─────┬─────┘           └─────────────┬───────────┘
  │              │ attacks                       ▲ agent telemetry
  │        ┌─────▼──────────────────────────┐    │
  └────────┤  Windows victim VM (VirtualBox)│────┘
  Atomic   │  + Sysmon + Wazuh agent        │
  Red Team └────────────────────────────────┘
```

## Components

| Layer        | Tool                              | Location                     |
|--------------|-----------------------------------|------------------------------|
| SIEM         | Wazuh (single-node, Docker)       | [`siem/`](siem/)             |
| Attacker (AI)| Shannon                           | `shannon/` *(not in git)*    |
| Attack TTPs  | Atomic Red Team (Red Canary)      | runs on the victim VM        |
| Target app   | OWASP Juice Shop                  | `juice-shop/` *(not in git)* |
| Victim host  | Windows VM                        | VirtualBox                   |
| Docs/runbooks| Setup + attack→detect workflow    | [`docs/`](docs/)             |

## Repo layout

```
A_LAB/
├── siem/          # Wazuh docker-compose + config (the SIEM)
├── docs/          # VirtualBox VM setup, agent install, attack/detect runbooks
├── shannon/       # AI pentester (gitignored — third-party, pulled separately)
└── juice-shop/    # vulnerable target app (gitignored — third-party)
```

## Quick start

1. **SIEM** — `cd siem && docker compose up -d` then open `https://localhost:443`.
2. **Victim VM** — follow [`docs/01-virtualbox-windows-vm.md`](docs/01-virtualbox-windows-vm.md).
3. **Agent** — enroll the VM with Sysmon + Wazuh agent per [`docs/02-windows-agent-sysmon.md`](docs/02-windows-agent-sysmon.md).
4. **Attack** — run Atomic tests / Shannon per [`docs/03-attack-detect-workflow.md`](docs/03-attack-detect-workflow.md).
5. **Analyze** — hunt the resulting alerts in the Wazuh dashboard.

## Security note

This lab intentionally runs **vulnerable software and attack tooling**. Keep the
victim VM on a **host-only / NAT network**, never expose it to the internet, and
treat snapshots as disposable. Never commit `.env`, API keys, or credentials —
this is a public repo and `.gitignore` is configured defensively.
