# FOSSology Helm Chart

This chart packages the Phase 1 Kubernetes PoC for FOSSology.

## What It Deploys

- A web Deployment for Apache, PHP, and the REST UI
- A scheduler sidecar in the same pod so the runtime config can be reloaded in place
- A worker StatefulSet that exposes SSH for remote agent execution
- A PostgreSQL StatefulSet when `database.internal.enabled=true`
- Runtime config files rendered from ready worker pods at startup and during steady state

## Runtime Config Flow

The web pod uses a small sequence of runtime helpers mounted from the chart ConfigMap:

1. `wait-for-db.sh` blocks until PostgreSQL is reachable.
2. `init-config-runtime.sh` copies the image defaults into a writable `emptyDir`.
3. `run-render-fossology-conf.sh` renders `fossology.conf` from the live ready worker set.
4. `start-scheduler.sh` prints the active `[HOSTS]` block, configures SSH, and starts `fo_scheduler`.
5. The `config-sync` sidecar re-renders the file and sends `SIGHUP` to `fo_scheduler` when workers change.

## Important Values

| Key | Purpose |
| --- | --- |
| `workers.replicas` | Number of SSH-reachable worker pods |
| `workers.maxAgentsPerWorker` | Advertised scheduler capacity for each worker |
| `workers.minReadyStartup` | Minimum ready workers required before the first config render succeeds |
| `workers.minReadySync` | Minimum ready workers preserved during steady-state config refresh |
| `web.startupProbe` | Startup window for the Apache/PHP UI before liveness enforcement begins |
| `scheduler.startupProbe` | Startup window for `fo_scheduler` before liveness enforcement begins |
| `runtimeConfig.startupPollIntervalSeconds` | Fast poll loop used only during pod startup |
| `runtimeConfig.pollIntervalSeconds` | Steady-state config reconciliation interval |
| `ssh.privateSecretName` | Secret containing the scheduler private key |
| `ssh.publicSecretName` | Secret mounted into workers as `authorized_keys` |

## Useful Commands

```bash
helm lint deploy/helm/fossology -f deploy/helm/fossology/values.yaml
helm template fossology deploy/helm/fossology -n fossology -f deploy/helm/fossology/values.yaml
```

If you use the PoC helper scripts from the repo root, `make lint-phase1` and `make render-phase1` wrap the same checks.
