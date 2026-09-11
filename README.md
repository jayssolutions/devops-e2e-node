# devops-e2e-node

A Node.js/Express application with a full end-to-end DevOps pipeline: GitHub Actions CI/CD, Terraform-provisioned AWS infrastructure, and Ansible-based deployment.

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Node.js | 20+ | `brew install node` |
| Terraform | 1.10.5 | `brew install hashicorp/tap/terraform` |
| Ansible | any recent | `pip install ansible` |
| Python | 3.11+ | `brew install python` |
| AWS CLI | v2 | [docs](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) |
| jq | any | `brew install jq` |

AWS credentials must be configured (`aws configure` or environment variables).

---

## Project Structure

```
.
├── app/                        # Node.js/Express application
│   ├── src/
│   │   ├── app.js              # Express routes and Prometheus metrics
│   │   └── server.js           # HTTP server entry point
│   └── test/
├── ansible/                    # Deployment automation
│   ├── playbook.yml
│   ├── ansible.cfg
│   ├── requirements.yml
│   └── templates/
│       └── app.service.j2      # systemd service template
├── terraform/                  # AWS infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── backend.tf              # S3 remote state (jays-devops-tf-state-bucket)
│   └── modules/
│       ├── network/            # VPC, subnets
│       ├── alb/                # Application Load Balancer
│       ├── compute/            # EC2 instances
│       └── s3_backend/         # Terraform state bucket
├── scripts/
│   └── build_inventory.sh      # Generates ansible/inventory.ini from Terraform output
├── monitoring/
│   ├── prometheus.yml
│   └── alerts.yml
├── logging/
│   ├── filebeat.yml
│   └── logstash.conf
└── .github/workflows/
    ├── ci-cd.yml               # Main CI/CD pipeline
    └── terraform-destroy.yml   # Manual teardown workflow
```

---

## 1. Run the App Locally

```bash
cd app
npm install
npm start        # listens on http://localhost:3000
```

**Endpoints:**

| Endpoint | Description |
|---|---|
| `GET /` | Service identity (name, status, hostname) |
| `GET /health` | Liveness check → `{ status: "healthy" }` |
| `GET /ready` | Readiness check → `{ status: "ready" }` |
| `GET /metrics` | Prometheus metrics (default + HTTP duration histogram) |
| `GET /error` | Simulated 500 (for monitoring/alerting tests) |

```bash
npm run lint     # run ESLint
npm test         # run Jest test suite
```

---

## 2. Provision Infrastructure (Terraform)

Infrastructure lives in AWS `us-east-1`: VPC (`10.30.0.0/16`), ALB, and 2× EC2 `t3.micro` instances. State is stored in S3 (`jays-devops-tf-state-bucket`).

```bash
cd terraform

# First time only — initialise the backend
terraform init -reconfigure

# Review the plan
terraform plan \
  -var="public_key=$(cat ~/.ssh/id_ed25519.pub)" \
  -var="admin_cidr=$(curl -s https://checkip.amazonaws.com)/32"

# Apply
terraform apply -auto-approve \
  -var="public_key=$(cat ~/.ssh/id_ed25519.pub)" \
  -var="admin_cidr=$(curl -s https://checkip.amazonaws.com)/32"
```

`admin_cidr` restricts SSH access to your current public IP. After apply, the ALB DNS name is printed as `application_url`.

To customise variables, copy the example file:

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars as needed
terraform apply -auto-approve
```

**Key outputs:**

| Output | Description |
|---|---|
| `application_url` | ALB HTTP URL |
| `instance_public_ips` | EC2 instance IPs (used to build Ansible inventory) |

---

## 3. Build the App Archive

The deploy archive excludes `node_modules` — Ansible installs production deps on the server.

```bash
# run from repo root
tar --exclude=node_modules -czf app.tar.gz -C app .
```

---

## 4. Generate Ansible Inventory

The inventory is built dynamically from Terraform outputs using `jq`:

```bash
# run from repo root
./scripts/build_inventory.sh
# writes ansible/inventory.ini in [app] group with ansible_user=ec2-user
```

---

## 5. Deploy with Ansible

```bash
cd ansible
ansible-playbook playbook.yml --private-key ~/.ssh/id_ed25519
```

The playbook runs **serial=1** (one host at a time, rolling deploy):

1. Installs Node.js, npm, and tar via `dnf`
2. Creates a dedicated system user (`devops-e2e-node`, no login shell)
3. Creates `/opt/devops-e2e-node` owned by that user
4. Copies and extracts the app archive
5. Installs production dependencies (`npm install --production`)
6. Deploys and enables a systemd service on port 3000
7. Restarts the service on any config change (handler)

Set `APP_ARCHIVE` env var to override the archive path (default: `../app.tar.gz`).

---

## 6. Accessing the Application

Once deployed, the app is served through the **Application Load Balancer** — not directly via EC2 IPs.

**Current deployment (dev):**

| Resource | Value |
|---|---|
| ALB URL | `http://devops-e2e-node-alb-1068120643.us-east-1.elb.amazonaws.com` |
| EC2 Instance 1 | `3.219.215.232` (not directly accessible on port 3000) |
| EC2 Instance 2 | `100.62.115.7` (not directly accessible on port 3000) |

**Test the endpoints:**

```bash
BASE=http://devops-e2e-node-alb-1068120643.us-east-1.elb.amazonaws.com

curl $BASE/          # service identity
curl $BASE/health    # liveness check → { "status": "healthy" }
curl $BASE/ready     # readiness check → { "status": "ready" }
curl $BASE/metrics   # Prometheus metrics
```

**Traffic flow:**

```
Browser / curl
      │
      ▼
ALB :80  (devops-e2e-node-alb-1068120643.us-east-1.elb.amazonaws.com)
      │
      ├──▶ EC2 3.219.215.232 :3000
      └──▶ EC2 100.62.115.7  :3000
```

EC2 instances are reachable on port 22 (SSH) only from the GitHub Actions runner IP during deployment. Port 3000 is not open to the internet — all app traffic must go via the ALB.

To get the URL programmatically after a fresh `terraform apply`:

```bash
cd terraform && terraform output -raw application_url
```

---

## 7. Smoke Test

```bash
APP_URL=$(cd terraform && terraform output -raw application_url)
curl -fsS "$APP_URL/health"
```

---

## 7. Tear Down Infrastructure

**Via GitHub Actions (recommended):** trigger the `Terraform Destroy (Manual)` workflow, select the `dev` environment, and type `DESTROY` in the confirmation prompt.

**Locally:**

```bash
cd terraform
terraform destroy -auto-approve \
  -var="public_key=$(cat ~/.ssh/id_ed25519.pub)" \
  -var="admin_cidr=$(curl -s https://checkip.amazonaws.com)/32"
```

---

## CI/CD Pipeline

Pushing to `main` triggers the GitHub Actions pipeline automatically. Pull requests only run the `ci` job.

```
push to main
  └── ci job (ubuntu-latest)
        ├── npm install
        ├── npm run lint
        └── npm test
              └── deploy job (on success, main branch only, environment: dev)
                    ├── Terraform init + validate + plan + apply
                    ├── Build app archive (tar, excludes node_modules)
                    ├── Write SSH private key (via env var, validated with ssh-keygen)
                    ├── Build Ansible inventory (from terraform output)
                    ├── Wait for SSH availability on all EC2 instances (up to 2 min)
                    ├── Ansible rolling deploy (serial=1)
                    └── Smoke test: poll /health up to 12× (10 s intervals)
```

**Required GitHub secrets** (set in the `dev` environment):

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS credentials |
| `AWS_SECRET_ACCESS_KEY` | AWS credentials |
| `SSH_PUBLIC_KEY` | ED25519 public key content (for EC2 key pair via Terraform) |
| `SSH_PRIVATE_KEY` | ED25519 private key (full PEM with `-----BEGIN/END OPENSSH PRIVATE KEY-----` headers and a trailing newline) |

> **SSH_PRIVATE_KEY format:** Copy the key directly from `cat ~/.ssh/id_ed25519` — it must contain real newlines, not escaped `\n`. The pipeline validates the key with `ssh-keygen -y` and will fail fast if the format is wrong.
 
## Known issues / assumptions 
- Prometheus alerts are visible in the UI only; no Alertmanager/notification channel (Slack, email, PagerDuty) is wired up yet.
- App instances sit in public subnets with public IPs (needed for the current SSH-based Ansible deploy); a private-subnet + bastion/SSM design would reduce exposure but adds setup complexity.
- Single environment (`dev`), single region (`us-east-1` by default).
- `ansible/inventory.ini` is generated at deploy time and isn't committed.


# DevOps Exercise - Technical Notes & Key Observations

During the execution of this DevOps exercise, several technical challenges and configuration hurdles were identified and resolved. Below is a summary of the key observations, root cause analyses, and solutions implemented.

---

## 🛠️ Key Observations & Technical Findings

### 1. Terraform State Management & Remote Backend Migration
* **Issue:** The Terraform state file (`terraform.tfstate`) was initially tracked at the repository level. Storing state locally led to state drift and conflicts during infrastructure provisioning across runs.
* **Root Cause:** Lack of centralized, remote state management and state locking.
* **Solution:** 
  * Implemented an S3 remote backend module (`s3Backend`) for secure state storage.
  * Configured native S3 state locking using `use_lockfile = true` available in **Terraform v1.10.0+**, eliminating the need for a separate DynamoDB locking table.

```hcl
terraform {
  backend "s3" {
    bucket       = "my-devops-tfstate-bucket"
    key          = "infrastructure/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true # Native S3 locking feature (Terraform v1.10.0+)
  }
}
```

---

### 2. Ansible Inventory Configuration
* **Issue:** Playbook execution failed during initial provisioning runs.
* **Root Cause:** Syntax typo present within the `inventory.ini` file preventing Ansible from parsing host groups correctly.
* **Solution:** Corrected host definitions and IP declarations in `inventory.ini` to restore smooth playbook execution.

---

### 3. SSH Authentication Failure (EC2 & Ansible)
* **Issue:** Ansible playbooks repeatedly failed to connect to provisioning target EC2 instances over SSH (`Host Unreachable` / `Permission Denied`).
* **Root Cause:** Investigation revealed that the private key file lacked a trailing newline character (`\n`), causing OpenSSH and Ansible's SSH wrapper to misinterpret the key format.
* **Solution:** Reformatted the private key file to ensure proper ASCII formatting and trailing newline structure, restoring SSH connectivity.

```bash
# Verify and fix missing newline in private key
echo "" >> ~/.ssh/devops_ec2_key.pem
chmod 400 ~/.ssh/devops_ec2_key.pem
```

---

### 4. Application Verification & Load Balancer Routing
* **Observation:** Application endpoint verification and functional testing must target the Elastic Load Balancer (ELB) URL rather than individual backend EC2 instance IPs.
* **Impact:** Ensures end-to-end traffic routing, health checks, and listener rules are validated through the ingress path.

---

### 5. Elastic Stack (ELK) Deployment Constraints
* **Issue:** Unable to successfully bring up the ELK stack (Elasticsearch, Logstash, Kibana).
* **Root Cause:** Elasticsearch and Kibana memory requirements exceeded available RAM limits on AWS Free Tier instance types (`t2.micro` / `t3.micro`).
* **Resolution:** ELK stack deployment was paused due to AWS Free Tier compute limits. For production/further testing, instances should be upgraded to at least `t3.medium` with sufficient swap space configured.

---

## 📌 Summary Checklist

- [x] Remote S3 backend configured with native S3 locking (`use_lockfile = true`)
- [x] Fixed syntax errors in `inventory.ini`
- [x] Resolved SSH key formatting issue for EC2 connectivity
- [x] Application validated via ELB DNS Endpoint
- [ ] *ELK Stack provisioned (Deferred - requires higher tier instances)*