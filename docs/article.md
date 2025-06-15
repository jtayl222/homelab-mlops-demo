---

From CI/CD to Continuous ML - Bridging DevOps and MLOps in a K3s Homelab
How I implemented an interview‑ready MLOps platform on K3s using open‑source projects such as Prometheus, MLflow, and Argo Workflows - and what it means for technical leaders who already know DevOps.

---

Table of Contents
Executive Summary
Why MLOps Diverges from DevOps
Toolchain Deep Dive
Reference Architecture Walk‑Through
Implementation Journey - Lessons from the Homelab
Operational Payoffs & ROI
Adoption Roadmap for Engineering Teams
FAQ for DevOps‑Seasoned Managers
Resources & Next Steps

---

1 Executive Summary
If you speak fluent CI/CD, containers, and GitOps, you are ≈ 80 % of the way toward MLOps. The final 20 % - data lineage, model governance, and statistical‑drift monitoring - is where many teams stall.
This article shows how those missing capabilities map to familiar DevOps primitives and walks through a reference implementation that spins up in < 1 hour on a five‑node Kubernetes cluster. Feel free to cherry‑pick concepts into your own cloud estate.

---

2 Why MLOps Diverges from DevOps
2.1 The Determinism Gap
Software artifacts are deterministic; a given commit + build script yields the same binary forever. Models are probabilistic. A re‑run tomorrow on new data can (and should) change model weights. That creates new surfaces to automate: dataset snapshots, feature drift detection, and lineage reporting for auditors.
2.2 Changing Definition of "Done"

 For traditional DevOps, done means a service responds to health probes. For MLOps, done means the model maintains business KPIs (precision, recall, RMSE) in production. Continuous monitoring therefore extends beyond p95 latency into data science metrics.
2.3 Expanded Blast Radius
 A bad code deploy might crash a microservice; a bad model can deny loans to thousands of qualified applicants or approve fraudulent transactions. Governance must incorporate human‑in‑the‑loop approvals, bias testing, and rollback strategies triggered by statistical drift - not just HTTP 5xx alarms.

---

3 Toolchain Deep Dive
Below is both a quick‑glance table and narrative rationale for each component.
3.1 Tool Quick Reference - What Each Component Adds
Tool Role in the Stack Why It Matters Git / GitHub Version control for code & manifests Single source of truth driving infra and ML pipelines MLflow Model Registry Tracks experiments & model stages Gives lineage, lifecycle states, and API‑driven promotions DVC / LakeFS Data version control Reproduce training with exact data snapshot; links to Git commits Kaniko Rootless container builds in K8s Builds images without Docker daemon; secure & scalable Conda‑pack / Micromamba Package environments for training jobs Pin exact Python libs → reproducible model artifacts Argo Workflows Orchestrates ML DAGs Native K8s CRDs, conditional logic, artifact passing Seldon Core / KServe Model serving layer Auto‑scales REST/GRPC endpoints; supports canary & shadow tests Prometheus Metrics collection Scrapes cluster + model KPIs; forms drift/SLA alerts Grafana Dashboards & alerting UI Unifies ops + data‑science metrics for one‑pane observability MinIO (S3 API) Artifact & data storage Cloud‑agnostic object store for large binaries and parquet Traefik Ingress controller Secure, LetsEncrypt‑enabled routes to UIs and model endpoints K3s Lightweight Kubernetes distro Full K8s API on resource‑constrained homelab hardware
3.2 Narrative Rationale
Git + DVC/LakeFS → Apply Git‑like semantics to data so every experiment is reproducible. Think "git checkout" but for terabytes.
MLflow → Combines experiment tracking with a governable registry. Promotions from Staging to Production can be tied to pull‑request approvals.
Argo Workflows → Replaces ad‑hoc bash scripts. Each node in the DAG becomes a Kubernetes pod, inheriting RBAC and resource quotas.
Kaniko → Builds Docker/OCI images inside the cluster, eliminating the need for privileged Docker‑in‑Docker runners.
Seldon Core → Wraps your model in a microservice with an envoy‑sidecar that emits Prometheus metrics - latency and prediction distributions.
Prometheus + Grafana → Extends SRE playbooks (RED, USE) with ML metrics (precision, drift). Same alertmanager pipeline → no new pager duty routing.

---

4 Reference Architecture Walk‑Through
 ┌────────────┐       Git Push        ┌───────────────┐
 │  Developer │ ────────────────────► │   GitHub CI   │
 └────────────┘                       └───────────────┘
         ▲                                   │
         │                                   ▼  GitOps Sync
 ┌────────────┐                       ┌───────────────┐
 │   Argo CD  │ ◄──────────────────── │  Git Repos    │
 └────────────┘                       └──────┬────────┘
                                             │
                                   ┌─────────▼─────────┐
                                   │  Argo Workflows   │
                                   └─────────┬─────────┘
            ┌─────────── Train Job (GPU) ─────────┐
            │                                     │
       ┌────▼────┐                          ┌─────▼──────┐
       │  DVC    │                          │  MLflow    │
       └────┬────┘                          └─────┬──────┘
            │                                     │
            │         Kaniko Build                │
            │────────────────────────────────────►│
            │                                     │  Image URL + Model URI
            │                                     ▼
       ┌────▼────┐                          ┌─────┴──────┐
       │  MinIO  │                          │  Seldon    │
       └────┬────┘                          └────────────┘
            │                                     ▲
            ▼                                     │
       ┌─────────┐            Metrics            ┌───────────┐
       │ Grafana │ ◄─────────────────────────── ►│Prometheus │
       └─────────┘                               └───────────┘
All components run on a five‑node Intel NUC homelab using K3s with NFS‑backed persistent volumes.
4.1 Control Plane
Argo CD continuously applies kube‑manifests from infra and ml‑app repos.
SealedSecrets are decrypted by the controller at runtime, so no plaintext creds live in Git.

4.2 Pipeline Flow
Pre‑Commit Hook: pre‑commit run --all-files enforces yamllint, ansible‑lint.
GitHub Action lints again and builds docs with MkDocs.
Argo Workflows picks up a manifest change, executes an Iris training DAG.
MLflow logs metrics, artifacts; top performer auto‑promotes to Staging.
Kaniko wraps the model + requirements into an OCI image, pushes to GHCR.
Seldon deploys the new image behind an envoy sidecar.
Prometheus scrapes /metrics; Alertmanager triggers rollback if precision < 0.80.

---

5 Implementation Journey - Lessons from the Homelab
Week Focus Win Pain Point 1 Baseline K3s + NFS HA control plane on 5 NUCs BIOS quirks, USB boot loops 2 Argo CD + GitOps Zero‑ssh cluster updates Learning curve for ApplicationSets 3 MLflow + MinIO Full experiment tracking TLS cert chain for MinIO behind Traefik 4 Argo Workflows DAG End‑to‑end Iris pipeline Debugging PVC mounts inside pods 5 Seldon + Canary Live traffic split demos Envoy sidecar mis‑config on health probes 6 Observability Grafana dashboard for execs Custom Prometheus exporter for F1 score
Key Takeaways
Order matters: Install MinIO before MLflow or artifact upload 404s.
Secret hygiene: SealedSecrets + SOP keeps kubeseal out of CI runners.
YAML fatigue: Kustomize bases + overlays cut duplication by ~70 %.

---

6 Operational Payoffs & ROI
Audit‑ready lineage: Git SHA ↔ data hash ↔ model version ↔ container digest.
Change failure rate drops - canary rollout auto‑rolls back on drift, not just 5xx.
Cloud portability: MinIO + K3s runs the same on bare‑metal NUCs or EKS.
Developer empathy: Data scientists push to Git, Argo handles infra - no tickets.

A small on‑prem cluster costing < USD 1 500 now doubles as a training ground for and a live demo for interviews.

---

9 Resources
Source Code
github.com/jtayl222/k3s‑homelab
github.com/jtayl222/homelab‑mlops‑demo

Published June 2025 - feedback welcome!