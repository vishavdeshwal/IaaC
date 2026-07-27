# mydesignation (Azure)

Terraform for the **MYD mobile app** Azure workload, in subscription **MYDPremium**
(`b9db5311-2d8c-47b1-940f-49d366af9c92`), resource group `rg-myd-mobileapp-dev`,
region `southindia`.

Mirrors the AWS project layout: reusable modules in `modules/azure/`, per-project
`bootstrap/` for remote state, and `environments/{staging,preprod,prod}/`.

> All live resources already exist in Azure. `staging` **imports** them into state
> (no create/destroy). `preprod` and `prod` are empty scaffolds for net-new infra.

---

## Prerequisites

```bash
az login                                             # authenticate
az account set --subscription b9db5311-2d8c-47b1-940f-49d366af9c92
terraform -version                                   # >= 1.5.0 (import blocks)
```

Auth model: the `azurerm` provider uses your `az login` credentials (Azure CLI).
There is no `profile` concept like AWS — the subscription is pinned via
`subscription_id` in each `terraform.tfvars`.

---

## Step 1 — Bootstrap the remote-state backend (once)

Creates a Storage Account + `tfstate` container that holds every environment's
state file (the Azure equivalent of the AWS S3 state bucket).

```bash
cd projects/mydesignation/bootstrap
terraform init
terraform apply
terraform output state_storage_account_name          # e.g. mydesignationtf48213
```

Copy that storage account name into the `backend "azurerm"` block of **each**
environment `main.tf`, replacing `REPLACE_WITH_BOOTSTRAP_OUTPUT`
(staging, preprod, prod).

---

## Step 2 — Import the live staging resources

`environments/staging/` already declares every existing resource **and** an
`imports.tf` that binds each to its real Azure ID.

```bash
cd projects/mydesignation/environments/staging
terraform init
terraform plan      # MUST read: "N to import, 0 to add, 0 to destroy"
```

- ✅ **Verified plan** (run against live Azure on 2026-07-27):
  `26 to import, 0 to add, 14 to change, 0 to destroy` — where all 14 "changes"
  are **tag-only additions** (no existing attribute changes value).
- ✅ Every resource shows **"will be imported"**. In-place `tags` additions are
  expected (we standardise on `Name/Environment/Project`).
- 🚫 If you ever see **destroy/replace**, STOP and reconcile the config before applying.

```bash
terraform apply     # writes state; performs the imports + tag updates only
```

After a clean apply that reports **no changes**, you may delete `imports.tf`
(state already holds the resources). Keeping it is harmless — imports are no-ops
once in state.

---

## Step 3 — Day-2 (normal workflow)

```bash
terraform plan      # should be clean
terraform apply     # apply real changes going forward
```

Add prod/preprod resources by copying module blocks from
`environments/staging/main.tf` (these are net-new — no import blocks needed).

---

## What's imported (staging)

| # | Module | Azure resource |
|---|--------|----------------|
| 1 | `resource_group` | `rg-myd-mobileapp-dev` |
| 2 | `vnet_app` | VNet `staging-mydestination` (10.0.0.0/16) + subnet `default` |
| 3 | `vnet_production` | VNet `production-vnet` (10.1.0.0/16) + 3 subnets |
| 4 | `nsg_app` | NSG `staging-application-nsg` (SSH, 443) |
| 5 | `nsg_testing1` / `nsg_testing1_715` | NSGs `testing1-nsg`, `testing1nsg715` |
| 6 | `pip_app` / `pip_mydestination` | Public IPs `staging-application-ip`, `staging-mydestination` |
| 7 | `nic_app` | NIC `staging-application485` (+ NSG association) |
| 8 | `ssh_app` / `ssh_testing1` | SSH keys `staging-application_key`, `testing1_key` |
| 9 | `vm_app` | Linux VM `staging-application` (Standard_B2ms, OS disk inline) |
| 10 | `storage` | Account `mydesignation` + container `staging-mydesignation-bucket` + legacy queue |
| 11 | `servicebus_namespace` | Namespace `staging-mydesignation-bus` (Basic) + `webhook-app` rule |
| 12 | `servicebus_queue` | Queue `staging-mydesignation-queue` + `send-only` / `listen-only` rules |
| 13 | `role_queue_data_contributor` | Role: Storage Queue Data Contributor → VM identity |

## Notes / assumptions (review on first `plan`)

- **VM is Trusted Launch** — `secure_boot_enabled` + `vtpm_enabled` are set `true`.
  Omitting them made Terraform want to *replace* the VM; this is why they're pinned.
- **VM image drift**, `boot_diagnostics`, and `additional_capabilities` are ignored
  (`lifecycle.ignore_changes`) so an already-running VM is never churned by Azure
  defaults or new Ubuntu builds.
- **Subnet outbound access** — `default_outbound_access_enabled` is pinned to `false`
  on `default`, `private-app`, `private-db` (their real value); `public-subnet` keeps
  the provider default. Prevents a silent behavioural flip on import.
- **NIC private IP** modelled as `Dynamic` (current value `10.0.0.4`).
- **`mydesignation` allows public blob access** (`allow_nested_items_to_be_public = true`)
  because `staging-mydesignation-bucket` is public `blob`. ⚠️ Security hardening item:
  consider making the container private and setting this to `false`.
- **Leftovers** imported at your request: `production-vnet`, `staging-mydestination`
  public IP, `testing1-nsg`, `testing1nsg715`, `testing1_key` are not wired to the
  app — candidates for cleanup once confirmed unused.
- **Storage queue import ID** uses the data-plane URL
  (`https://mydesignation.queue.core.windows.net/staging-mydesignation-queue`); if your
  azurerm build rejects it, import that one resource with the RM ID form instead.

## Secrets

`terraform.tfvars` contains SSH **public** keys (safe) and the subscription ID.
The Service Bus SAS connection strings are exposed as **sensitive** outputs — read
them with `terraform output -raw servicebus_queue_connection_strings`. Do not commit
any private keys or connection strings.
