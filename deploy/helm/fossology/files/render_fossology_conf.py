#
# SPDX-FileCopyrightText: © Fossology contributors
#
# SPDX-License-Identifier: GPL-2.0-only
#
#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Optional


def log(message: str) -> None:
    print(f"[config-sync] {message}", flush=True)


def read_service_account_file(path: str) -> str:
    return Path(path).read_text(encoding="utf-8").strip()


def fetch_ready_worker_pods(namespace: str, label_selector: str) -> list[str]:
    api_host = os.environ.get("KUBERNETES_SERVICE_HOST", "kubernetes.default.svc")
    api_port = os.environ.get("KUBERNETES_SERVICE_PORT", "443")
    token = read_service_account_file(
        "/var/run/secrets/kubernetes.io/serviceaccount/token"
    )
    ca_cert = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    encoded_selector = urllib.parse.quote(label_selector, safe="")
    url = (
        f"https://{api_host}:{api_port}/api/v1/namespaces/{namespace}/pods"
        f"?labelSelector={encoded_selector}"
    )

    request = urllib.request.Request(
        url,
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
    )
    context = None
    if Path(ca_cert).exists():
        import ssl

        context = ssl.create_default_context(cafile=ca_cert)

    with urllib.request.urlopen(request, context=context, timeout=10) as response:
        payload = json.load(response)

    ready_pods = []
    for item in payload.get("items", []):
        if item.get("status", {}).get("phase") != "Running":
            continue
        conditions = item.get("status", {}).get("conditions", [])
        if not any(
            condition.get("type") == "Ready" and condition.get("status") == "True"
            for condition in conditions
        ):
            continue
        ready_pods.append(item["metadata"]["name"])
    return sorted(ready_pods)


def render_hosts_block(
    pod_names: list[str],
    namespace: str,
    headless_service: str,
    worker_conf_dir: str,
    max_agents: int,
) -> str:
    lines = []
    for pod_name in pod_names:
        fqdn = f"{pod_name}.{headless_service}.{namespace}.svc.cluster.local"
        lines.append(f"{pod_name} = {fqdn} {worker_conf_dir} {max_agents}")
    return "\n".join(lines)


def write_if_changed(path: Path, content: str) -> bool:
    if path.exists() and path.read_text(encoding="utf-8") == content:
        path.chmod(0o644)
        return False

    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w", delete=False, dir=str(path.parent), encoding="utf-8"
    ) as handle:
        handle.write(content)
        temp_name = handle.name

    os.replace(temp_name, path)
    path.chmod(0o644)
    return True


def render_config(template_path: Path, hosts_block: str, scheduler_host: str) -> str:
    template = template_path.read_text(encoding="utf-8")
    return (
        template.replace("__HOSTS__", hosts_block)
        .replace("__SCHEDULER_HOST__", scheduler_host)
    )


def maybe_signal_scheduler(command: Optional[str]) -> None:
    if not command:
        return
    result = subprocess.run(
        command, shell=True, text=True, capture_output=True, check=False
    )
    if result.returncode == 0:
        log(f"reloaded scheduler with: {command}")
    else:
        log(
            "scheduler reload command failed "
            f"(exit={result.returncode}): {result.stderr.strip() or result.stdout.strip()}"
        )


def run_once(args: argparse.Namespace) -> int:
    deadline = time.time() + args.timeout_seconds
    while True:
        ready_pods = fetch_ready_worker_pods(args.namespace, args.label_selector)
        if len(ready_pods) >= args.min_ready_workers:
            break
        if args.mode == "once" and time.time() >= deadline:
            log(
                f"timed out waiting for {args.min_ready_workers} ready workers; "
                f"currently ready: {ready_pods}"
            )
            return 1
        log(
            f"waiting for ready workers: need {args.min_ready_workers}, "
            f"currently have {len(ready_pods)} ({', '.join(ready_pods) or 'none'})"
        )
        time.sleep(args.poll_interval_seconds)

    hosts_block = render_hosts_block(
        ready_pods,
        args.namespace,
        args.headless_service,
        args.worker_conf_dir,
        args.max_agents_per_worker,
    )
    content = render_config(args.template, hosts_block, args.scheduler_host)
    changed = write_if_changed(args.output, content)
    rendered_hosts = ", ".join(ready_pods)
    if changed:
        log(
            f"rendered {args.output} with {len(ready_pods)} ready worker(s): "
            f"{rendered_hosts}"
        )
    else:
        log(
            f"configuration already up to date for {len(ready_pods)} ready "
            f"worker(s): {rendered_hosts}"
        )
    if changed:
        maybe_signal_scheduler(args.signal_command)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--namespace", required=True)
    parser.add_argument("--label-selector", default="app=fossology-worker")
    parser.add_argument("--headless-service", default="fossology-workers")
    parser.add_argument("--worker-conf-dir", default="/usr/local/etc/fossology")
    parser.add_argument("--max-agents-per-worker", type=int, default=2)
    parser.add_argument("--min-ready-workers", type=int, default=1)
    parser.add_argument("--poll-interval-seconds", type=int, default=5)
    parser.add_argument("--timeout-seconds", type=int, default=300)
    parser.add_argument("--scheduler-host", required=True)
    parser.add_argument("--signal-command")
    parser.add_argument("--mode", choices=("once", "loop"), default="once")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if args.mode == "once":
        return run_once(args)

    while True:
        status = run_once(args)
        if status != 0:
            return status
        time.sleep(args.poll_interval_seconds)


if __name__ == "__main__":
    sys.exit(main())
