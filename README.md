# devops-e2e-node

A Node.js/Express application with a full end-to-end DevOps pipeline: GitHub Actions CI/CD, Terraform-provisioned AWS infrastructure, and Ansible-based deployment.

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Node.js | 20+ | `brew install node` |
| Terraform | >= 1.7.0 | `brew install hashicorp/tap/terraform` |
| Ansible | any recent | `pip install ansible` |
| AWS CLI | v2 | [docs](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) |
| jq | any | `brew install jq` |

AWS credentials must be configured (`aws configure` or environment variables).

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
| `GET /` | Service identity |
| `GET /health` | Liveness check |
| `GET /ready` | Readiness check |
| `GET /metrics` | Prometheus metrics |
| `GET /error` | Simulated 500 (monitoring tests) |

```bash
npm run lint     # run ESLint
npm test         # run Jest test suite
```

---

## 2. Provision Infrastructure (Terraform)

Infrastructure lives in AWS (us-east-1 by default): VPC, ALB, and 2× EC2 t3.micro instances. State is stored in S3.

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

---

## 3. Build the App Archive

The deploy archive excludes `node_modules` — Ansible installs production deps on the server.

```bash
# run from repo root
tar --exclude=node_modules -czf app.tar.gz -C app .
```

---

## 4. Generate Ansible Inventory

The inventory is built dynamically from Terraform outputs:

```bash
# run from repo root
./scripts/build_inventory.sh
# writes ansible/inventory.ini
```

---

## 5. Deploy with Ansible

```bash
cd ansible
ansible-playbook playbook.yml --private-key ~/.ssh/id_ed25519
```

The playbook (serial=1, one host at a time):
1. Installs Node.js and npm via `dnf`
2. Creates a dedicated system user (`devops-e2e-node`)
3. Extracts the archive to `/opt/devops-e2e-node`
4. Installs production dependencies
5. Registers and starts a systemd service on port 3000

---

## 6. Smoke Test

```bash
APP_URL=$(cd terraform && terraform output -raw application_url)
curl -fsS "$APP_URL/health"
```

---

## 7. Tear Down Infrastructure

**Via GitHub Actions (recommended):** trigger the `Terraform Destroy (Manual)` workflow and type `DESTROY` in the confirmation prompt.

**Locally:**

```bash
cd terraform
terraform destroy -auto-approve \
  -var="public_key=$(cat ~/.ssh/id_ed25519.pub)" \
  -var="admin_cidr=$(curl -s https://checkip.amazonaws.com)/32"
```

---

## CI/CD Pipeline

Pushing to `main` triggers the GitHub Actions pipeline automatically:

```
push to main
  └── ci job: lint + test
        └── deploy job (on success)
              ├── terraform init + apply
              ├── build app archive
              ├── generate ansible inventory
              ├── ansible deploy (rolling, 1 host at a time)
              └── smoke test (/health)
```

**Required GitHub secrets** (in the `dev` environment):

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS credentials |
| `AWS_SECRET_ACCESS_KEY` | AWS credentials |
| `SSH_PUBLIC_KEY` | Public key content for EC2 key pair |
| `SSH_PRIVATE_KEY` | Private key for Ansible SSH access |
