# EKS Observability Demo

> **TL;DR** – This repository bootstraps an AWS CodeBuild project (via GitHub Actions) that in turn provisions an EKS cluster with a fully‑remote Terraform backend (S3+DynamoDB) and deploys basic cost/observability add‑ons (Kubecost, optional Prometheus Stack). The whole process is *click‑once*: run the **Bootstrap AWS CodeBuild** workflow and watch CodeBuild do the rest.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Repository layout](#repository-layout)
3. [Prerequisites](#prerequisites)
4. [Secrets & environment variables](#secrets--environment-variables)
5. [Bootstrap phase](#bootstrap-phase)
6. [Remote backend](#remote-backend)
7. [EKS deployment phase](#eks-deployment-phase)
8. [Post‑deploy add‑ons](#post-deploy-add-ons)
9. [Using the cluster](#using-the-cluster)
10. [Troubleshooting](#troubleshooting)
11. [Cleanup / teardown](#cleanup--teardown)

---

## Architecture

Local Git repo -> GitHub Actions -> Bootstrap workflow (CI) -> AWS CodeBuild (CD)

Bootstrap workflow (CI)
* Creates CodeBuild project
* Creates S3 + DynamoDB (remote TF backend)
* Stores GH_PAT in SecretsMgr

AWS CodeBuild (CD)
buildspec.yml steps:
1.Init TF with remote
2.Apply EKS, VPC, etc.
3.aws eks update‑kubeconfig
4.deploy.sh (Helm add‑ons)


---

## Repository layout

| Path                              | Purpose                                                                                                                                                       |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.github/workflows/bootstrap.yml` | GitHub Actions workflow that **bootstraps** the AWS CodeBuild project and backend.                                                                            |
| `bootstrap/*`                     | Terraform that creates:<br>• the CodeBuild project/role<br>• the S3 bucket + DynamoDB lock table (random name)<br>• stores your GitHub PAT in Secrets Manager |
| `terraform/`                      | Terraform that deploys the VPC, EKS cluster, node group, IAM, etc. (remote backend configured in `backend.tf`).                                               |
| `scripts/deploy.sh`               | Helm script that installs Kubecost (Prometheus stack commented out – enable if desired).                                                                      |
| `buildspec.yml`                   | CodeBuild instruction file (installs TF/kubectl/Helm, then runs the EKS stack and add‑ons).                                                                   |

---

## Prerequisites

* **AWS Account** with Administrator (or least privileges to create EKS, IAM, S3, DynamoDB, CodeBuild, Secrets Manager, VPC, CloudWatch).
* **GitHub Secrets** (in the repo → *Settings → Secrets & variables → Actions*):

  * `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` – credentials that GitHub Actions uses for bootstrapping.
  * `GH_PAT` – *classic* personal access token with at least **repo** scope so CodeBuild can pull the source.
* Terraform file‑backend **not required** locally – everything is remote.

---

## Secrets & environment variables

| Name                                          | Where                                              | Used by                               | Description                                      |
| --------------------------------------------- | -------------------------------------------------- | ------------------------------------- | ------------------------------------------------ |
| `AWS_REGION`                                  | workflow & CodeBuild env                           | All                                   | Deployment region (default `us‑east‑1`).         |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | GitHub Secrets                                     | Bootstrap workflow                    | Temp creds for bootstrap.                        |
| `GH_PAT`                                      | GitHub Secrets                                     | bootstrap/`aws_secretsmanager_secret` | Stored in Secrets Manager for CodeBuild.         |
| `TF_STATE_BUCKET` / `TF_LOCK_TABLE`           | Exported from bootstrap TF outputs → CodeBuild env | CodeBuild                             | Names of the remote state bucket and lock table. |

Bootstrap exposes the bucket/table via outputs; GitHub Actions writes them into CodeBuild project environment variables so the `buildspec.yml` can feed them into `terraform init`.

---

## Bootstrap phase

1. Trigger **Actions → *Bootstrap AWS CodeBuild* → *Run workflow***.
2. Steps executed:

   * Terraform `bootstrap/` is initialised **locally in GitHub Actions**.
   * Creates **random‑named** S3 bucket (`eks‑tf‑state‑<rand>`) and DynamoDB table (`eks‑tf‑lock‑<rand>`).
   * Provisions **CodeBuild project + IAM role** with permissions for EKS, VPC, IAM, S3, etc.
   * Stores your `GH_PAT` in AWS Secrets Manager so CodeBuild can git‑clone the repo.
3. Outputs bucket & table names; workflow patches the CodeBuild env so subsequent builds get `TF_STATE_BUCKET`, `TF_LOCK_TABLE`.

You run this only once (or when you change CodeBuild infrastructure).

---

## Remote backend

`terraform/backend.tf` (inside the `terraform/` folder) contains **only** the backend block:

```hcl
terraform {
  backend "s3" {}
}
```

Backend details are injected at runtime by the `buildspec.yml`:

```bash
terraform -chdir=terraform init \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="key=eks-observability/eks.tfstate" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="dynamodb_table=$TF_LOCK_TABLE" \
  -backend-config="encrypt=true"
```

No state files land in the repo.

---

## EKS deployment phase

Every push (or manual run) of CodeBuild does:

1. **Install tooling** – Terraform 1.11+, kubectl 1.30, Helm 3.
2. **`terraform apply`** in `terraform/` – components:

   * VPC (`terraform-aws‑vpc` module)
   * EKS cluster (`terraform-aws‑eks` 20.x)
   * Single managed node group
   * OIDC provider & KMS key
   * IAM role `eks-admin-role` mapped to `system:masters` via `enable_cluster_creator_admin_permissions = true`
3. **Kubeconfig** – `aws eks update‑kubeconfig` writes `~/.kube/config` inside the CodeBuild container (not persisted) so Helm can deploy add‑ons.
4. **Add‑ons** – `scripts/deploy.sh` installs Kubecost (Prometheus optional).

Approximate total build time ± 25 minutes.

---

## Post‑deploy add‑ons

| Add‑on               | Namespace    | Access                                                                                                                                  |
| -------------------- | ------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| **Kubecost**         | `kubecost`   | Port‑forward: `kubectl port-forward -n kubecost deploy/kubecost-cost-analyzer 9090` then [http://localhost:9090](http://localhost:9090) |
| **Prometheus Stack** | `monitoring` | (uncomment in `deploy.sh`)                                                                                                              |

> **Note** – EKS 1.23+ requires the EBS‑CSI driver for PVs. Either install the managed add‑on or use Helm ([https://github.com/kubernetes-sigs/aws-ebs-csi-driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)). Kubecost will warn if missing.

---

## Using the cluster

1. **Assume the CodeBuild role locally** (or any IAM principal that you map).
2. Retrieve kubeconfig:

   ```bash
   aws eks --region us-east-1 update-kubeconfig --name my-eks-cluster
   ```
3. Verify:

   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

If you see *“You must be logged in to the server (Unauthorized)”* ensure your IAM principal is in the **EKS Access Entry** list **and** mapped in the `aws‑auth` ConfigMap. The module does this automatically when `enable_cluster_creator_admin_permissions=true`.

---

## Troubleshooting

| Symptom                                                  | Fix                                                                                                                                                              |
| -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Unauthorized** error in CodeBuild on `aws‑auth` update | Make sure the CodeBuild role ARN is passed to `cluster_security_group_additional_rules` or `enable_cluster_creator_admin_permissions=true` (already set). Retry. |
| Kubecost shows PVC errors                                | Install the EBS‑CSI driver: `eksctl create addon --name aws-ebs-csi-driver --cluster my-eks-cluster --service-account-role-arn <role>`                           |
| Stuck deleting S3 bucket                                 | State files / versions exist; empty bucket or use `aws s3 rm --recursive`.                                                                                       |

---

## Cleanup / teardown

1. **Destroy the EKS stack:**

   ```bash
   aws codebuild start-build --project-name eks-observability-demo \
     --environment-variables-override name=TF_ACTION,value=destroy \
     --buildspec-override buildspec.yml
   ```

   (or change the `terraform apply` command to `destroy` and run once).
2. **Delete CodeBuild & backend:** re‑run `bootstrap/` with `terraform destroy` *from your workstation* or delete via AWS Console.

---

## ⭐ Credits

* Modules – [https://github.com/terraform-aws-modules](https://github.com/terraform-aws-modules)
* Kubecost – [https://kubecost.com](https://kubecost.com)

Happy observability 👀🚀
