# 🏗️ NPS Reporting Migration — On-Prem ➔ AWS

**Company:** Protean eGov Technologies Limited
**Project Lead:** Digambar Rajaram (Assistant Manager — DevOps)
**Duration:** ~6–9 months
**Goal:** Seamless migration of NPS Reporting applications from on-prem datacenter to AWS Cloud using Terraform, Jenkins, Docker, Helm, Ansible, and Kubernetes (EKS).

---

## 👈 Overview

The **NPS Reporting Migration** modernizes legacy on-prem applications to AWS Cloud.
Core goals:

* Reduce downtime and manual deployments.
* Enable DR automation and compliance.
* Improve observability and performance.
* Achieve infrastructure as code (IaC) and full CI/CD automation.

---

## 🧱 Architecture

```
[Users]
   ↓
[Route53 + WAF]
   ↓
[ALB]
   ↓
[EKS Cluster]
   ├── Reporting App (Docker + Helm)
   ├── Prometheus + Grafana
   └── IAM Roles (IRSA)
→ [RDS Postgres]
→ [S3 Buckets]
→ [Terraform + Jenkins + Ansible]
```

**Security Layer:** AWS WAF, IAM least privilege, KMS, VPC isolation, SSM for secrets.
**DR:** Cross-region failover automated via Ansible.
**Monitoring:** Prometheus (metrics), Grafana (dashboards), CloudWatch (logs).

---

## 📂 Repository Structure

```
nps-reporting-migration/
├── terraform/
├── app/
├── helm/
├── jenkins/
├── ansible/
├── db-migration/
├── monitoring/
├── security/
├── scripts/
└── README.md
```

---

## ⚙️ Prerequisites

| Tool               | Version | Purpose                         |
| ------------------ | ------- | ------------------------------- |
| Terraform          | ≥ 1.5   | Infra provisioning              |
| AWS CLI            | ≥ 2.0   | Authentication & CLI automation |
| Docker             | ≥ 24    | Image build & test              |
| Helm               | ≥ 3     | K8s deployments                 |
| kubectl            | ≥ 1.25  | EKS cluster access              |
| Jenkins            | ≥ 2.4   | CI/CD pipeline                  |
| Ansible            | ≥ 2.16  | DR automation                   |
| Python             | ≥ 3.10  | App & testing                   |
| Prometheus/Grafana | Latest  | Monitoring stack                |

---

## 👷️ Infrastructure (Terraform)

### Directory: `terraform/`

Builds:

* Multi-AZ VPC
* EKS cluster (worker nodes + Fargate)
* RDS (Postgres)
* IAM roles (IRSA)
* S3 buckets (reports + backups)

```bash
cd terraform/envs/dev
terraform init
terraform plan -var-file=tfvars.example
terraform apply -auto-approve -var-file=tfvars.example
```

Backend: **S3** + **DynamoDB**.
Outputs: EKS name, RDS endpoint, S3 buckets.

---

## 💠 Application (Docker)

```bash
docker build -f app/Dockerfile -t nps-reporting:dev .
docker run --rm -p 8080:8080 nps-reporting:dev
curl -s http://localhost:8080/health
```

Shortcut:

```bash
./scripts/local_smoke_test.sh
```

---

## ☁️ Image Push (ECR)

```bash
./scripts/ecr_push.sh
```

This:

* Builds Docker image
* Logs into ECR
* Pushes tagged image (`<git-sha>`)

---

## 🚀 Deployment (Helm + EKS)

```bash
aws eks update-kubeconfig --name nps-cluster --region ap-south-1
helm upgrade --install reporting-dev helm/reporting \
  -n nps-dev --create-namespace \
  -f helm/reporting/values.yaml -f helm/reporting/values-dev.yaml \
  --set image.repository=123456789012.dkr.ecr.ap-south-1.amazonaws.com/reporting \
  --set image.tag=$(git rev-parse --short HEAD)
```

---

## 🤖 CI/CD (Jenkins)

Jenkins pipeline stages:

1. Checkout
2. Build & Unit Test
3. Security Scan (Trivy placeholder)
4. Push to ECR
5. Helm deploy to selected environment
6. Rollback on failure

Runs on agent with Docker, AWS CLI, kubectl, helm.

---

## 🗾 Database Migration

### Directory: `db-migration/`

Scripts for logical replication + snapshot-based migration from on-prem PostgreSQL ➔ AWS RDS.

1. **01_prepare_source.sql** — Enable logical replication.
2. **02_snapshot.sh** — Create logical dump or RDS snapshot.
3. **03_logical_replication.sql** — Create publication/subscription.
4. **04_cutover_check.sql** — Validate replication lag and row parity.

---

## 🔀 Disaster Recovery (Ansible)

### Directory: `ansible/`

* `roles/dr-failover` ➔ promotes RDS replica, updates Route53, scales EKS
* `roles/security-remediate` ➔ fixes VAPT findings
* `dr/failover.yml` ➔ main DR playbook
* `dr/validate.yml` ➔ post-failover validation

```bash
ansible-playbook -i ansible/inventory/stage ansible/dr/failover.yml
ansible-playbook -i ansible/inventory/stage ansible/dr/validate.yml
```

Creates DR audit logs in `ansible/dr_runs/`.

---

## 📊 Monitoring & Dashboards

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring/kube-prometheus-stack-values.yaml
```

Import Grafana dashboard from:
`monitoring/grafana-dashboards/reporting-overview.json`

---

## 🔐 Security (WAF + SSM)

### `security/waf.tf`

* Creates AWS WAFv2 WebACL (regional)
* Adds managed rule set + rate-based rule + ALB association

### `security/ssm-parameters.md`

Guidelines for secure config in AWS SSM Parameter Store.

```bash
aws ssm put-parameter \
  --name "/nps-reporting/prod/db/password" \
  --value "SuperSecret" \
  --type SecureString \
  --key-id alias/nps-reporting-kms
```

---

## 🔄 End-to-End Workflow

```mermaid
graph TD
A[Terraform: Infra Provision] --> B[Docker Build & Test]
B --> C[Push to ECR]
C --> D[Deploy to EKS via Helm]
D --> E[Ansible DR Automation]
E --> F[Prometheus + Grafana Monitoring]
F --> G[Security (WAF, SSM, IAM)]
```

---

## 🚀 Quick Start

```bash
# 1. Provision Infrastructure
cd terraform/envs/dev && terraform apply -auto-approve

# 2. Build and test app locally
./scripts/local_smoke_test.sh

# 3. Push image to ECR
./scripts/ecr_push.sh

# 4. Deploy to dev EKS namespace
helm upgrade --install reporting-dev helm/reporting \
  -n nps-dev -f helm/reporting/values.yaml -f helm/reporting/values-dev.yaml

# 5. Validate pods
kubectl get pods -n nps-dev

# 6. Run DR test
ansible-playbook -i ansible/inventory/stage ansible/dr/failover.yml

# 7. View metrics
tkubectl port-forward svc/grafana -n monitoring 3000:80
```

---

## 👥 Contacts

| Area               | Owner                |
| ------------------ | -------------------- |
| Infrastructure     | **Digambar Rajaram** |
| CI/CD (Jenkins)    | DevOps Team          |
| Database Migration | DBA + DevOps         |
| DR Automation      | Digambar & Ops Team  |
| Security & VAPT    | InfoSec              |
| Monitoring         | DevOps Team          |

---

## ✅ Achievements

| Metric            | Improvement                           |
| ----------------- | ------------------------------------- |
| Deployment time   | ↓ 40% faster                          |
| DR recovery (RTO) | ↓ From hours → < 1 hour               |
| Compliance        | ✅ Cleared VAPT remediation            |
| Monitoring        | 📊 Unified Prometheus + Grafana       |
| Cost Optimization | 💰 Automated S3 lifecycle & snapshots |

---

**✔️ The NPS Reporting Migration stack delivers full automation — Infra ➔ App ➔ DR ➔ Monitoring ➔ Security — version-controlled, auditable, and repeatable.**
