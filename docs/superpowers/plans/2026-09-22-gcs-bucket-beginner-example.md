# GCS Bucket Beginner Example Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the four empty `.tf` stub files plus README into a complete, runnable, well-commented Terraform example that teaches a Terraform beginner both core Terraform concepts and GCS bucket best practices.

**Architecture:** A single-module, single-environment Terraform config (no modules, no workspaces, no remote backend — those are explicitly out of scope). Five real files (`provider.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `terraform.tfvars.example`) plus `.gitignore`, plus a rewritten `README.md`.

**Tech Stack:** Terraform >= 1.5.0, `hashicorp/google` provider `~> 5.0`. No live GCP project needed to validate this plan's work — `terraform validate` and `terraform fmt -check` are the verification tools; `terraform plan` against a fake project is expected to fail at the auth/API stage and that failure is treated as success for this plan's purposes.

**Spec:** `docs/superpowers/specs/2026-09-22-gcs-bucket-beginner-example-design.md`

## Global Constraints

- Terraform `required_version = ">= 1.5.0"`.
- Provider `hashicorp/google`, version constraint `~> 5.0`.
- Bucket resource local name is `cloudb00stabucket` (both `google_storage_bucket` and `google_storage_bucket_iam_member`) — this was an explicit choice, keep it consistent across all files/tasks.
- `uniform_bucket_level_access = true` and `public_access_prevention = "enforced"` are non-negotiable — every task that touches `main.tf` must preserve them.
- CMEK and CORS stay as commented-out stubs — never make them live.
- No modules, no workspaces, no remote state backend, no CI config — out of scope.
- No live GCP project/credentials assumed anywhere in this plan's verification steps.

---

### Task 1: Core interface — `provider.tf` + `variables.tf`

These two files define every input the rest of the config depends on, so they come first. Together they're enough for `terraform init` and `terraform validate` to succeed with zero resources.

**Files:**
- Create: `provider.tf`
- Create: `variables.tf`

**Interfaces:**
- Produces: variables `project_id` (string), `bucket_name` (string), `region` (string, default `"US"`), `storage_class` (string, default `"STANDARD"`), `environment` (string, default `"dev"`), `versioning_enabled` (bool, default `true`), `noncurrent_version_age_days` (number, default `30`), `labels` (map(string), default `{}`), `iam_bindings` (list(object({ role = string, member = string })), default `[]`). Task 2 (`main.tf`) and Task 3 (`outputs.tf`) reference these by name.

- [ ] **Step 1: Write `provider.tf`**

```hcl
# The provider block tells Terraform which platform to talk to and how.
# Terraform itself is platform-agnostic; providers are plugins that
# translate the resource blocks you write into actual API calls.
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
```

- [ ] **Step 2: Write `variables.tf`**

```hcl
variable "project_id" {
  description = "GCP project ID to create resources in."
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "bucket_name" {
  description = "Globally unique name for the GCS bucket."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9\\-_.]{2,221}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-222 lowercase alphanumeric characters, dashes, underscores, or dots, and must not start or end with a dash."
  }
}

variable "region" {
  description = "Location for the bucket. Can be a region (e.g. us-central1) or a multi-region (e.g. US)."
  type        = string
  default     = "US"
}

variable "storage_class" {
  description = "Storage class for the bucket. Affects cost and retrieval latency."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], var.storage_class)
    error_message = "storage_class must be one of: STANDARD, NEARLINE, COLDLINE, ARCHIVE."
  }
}

variable "environment" {
  description = "Deployment environment. Used for labeling."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "versioning_enabled" {
  description = "Whether to keep noncurrent versions of objects when they're overwritten or deleted."
  type        = bool
  default     = true
}

variable "noncurrent_version_age_days" {
  description = "Days to keep a noncurrent object version before it's permanently deleted. Only takes effect when versioning_enabled is true."
  type        = number
  default     = 30
}

variable "labels" {
  description = "Key-value labels applied to the bucket."
  type        = map(string)
  default     = {}
}

variable "iam_bindings" {
  description = "IAM role bindings to grant on the bucket, e.g. [{ role = \"roles/storage.objectViewer\", member = \"user:jane@example.com\" }]."
  type = list(object({
    role   = string
    member = string
  }))
  default = []
}
```

- [ ] **Step 3: Initialize and validate**

Run: `terraform init && terraform validate`
Expected: `terraform init` downloads the `hashicorp/google` provider and prints "Terraform has been successfully initialized!"; `terraform validate` prints "Success! The configuration is valid."

- [ ] **Step 4: Format check**

Run: `terraform fmt -check`
Expected: no output, exit code 0. If it exits 1, run `terraform fmt` (no `-check`) to auto-fix, then re-run `-check`.

- [ ] **Step 5: Commit**

```bash
git add provider.tf variables.tf
git commit -m "Add provider config and input variables"
```

---

### Task 2: Bucket resource — `main.tf`

**Files:**
- Create: `main.tf`

**Interfaces:**
- Consumes: all variables from Task 1 (`var.bucket_name`, `var.region`, `var.storage_class`, `var.labels`, `var.environment`, `var.versioning_enabled`, `var.noncurrent_version_age_days`, `var.iam_bindings`).
- Produces: resource `google_storage_bucket.cloudb00stabucket` and resource `google_storage_bucket_iam_member.cloudb00stabucket` (for_each map keyed by `"${role}-${member}"`). Task 3 (`outputs.tf`) references `google_storage_bucket.cloudb00stabucket.{name,url,self_link,id}`.

- [ ] **Step 1: Write `main.tf`**

```hcl
resource "google_storage_bucket" "cloudb00stabucket" {
  name          = var.bucket_name
  location      = var.region
  storage_class = var.storage_class
  labels        = merge(var.labels, { environment = var.environment })

  # GCP-recommended: disables legacy per-object ACLs, enforces IAM only.
  # Required by many enterprise org policies.
  uniform_bucket_level_access = true

  # Blocks all public access at the bucket level, regardless of IAM.
  public_access_prevention = "enforced"

  versioning {
    enabled = var.versioning_enabled
  }

  # Only meaningful when versioning is enabled: once an object is
  # overwritten or deleted, its previous ("noncurrent") version sticks
  # around until this rule deletes it.
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = var.noncurrent_version_age_days
    }
    action {
      type = "Delete"
    }
  }

  # Customer-managed encryption key (CMEK). Uncomment and set a real key
  # if you need to manage your own encryption keys instead of relying on
  # Google-managed encryption (the default).
  # encryption {
  #   default_kms_key_name = "projects/PROJECT/locations/LOCATION/keyRings/RING/cryptoKeys/KEY"
  # }

  # CORS: only needed if browsers will make cross-origin requests
  # directly to objects in this bucket (e.g. a web app fetching assets).
  # cors {
  #   origin          = ["https://example.com"]
  #   method          = ["GET", "HEAD"]
  #   response_header = ["*"]
  #   max_age_seconds = 3600
  # }
}

# for_each over a map (built from the iam_bindings list) means Terraform
# tracks each binding independently — add or remove one entry in
# iam_bindings and only that IAM binding changes, not the whole set.
resource "google_storage_bucket_iam_member" "cloudb00stabucket" {
  for_each = { for b in var.iam_bindings : "${b.role}-${b.member}" => b }

  bucket = google_storage_bucket.cloudb00stabucket.name
  role   = each.value.role
  member = each.value.member
}
```

- [ ] **Step 2: Validate**

Run: `terraform validate`
Expected: "Success! The configuration is valid."

- [ ] **Step 3: Format check**

Run: `terraform fmt -check`
Expected: no output, exit code 0 (or run `terraform fmt` then re-check).

- [ ] **Step 4: Commit**

```bash
git add main.tf
git commit -m "Add GCS bucket and IAM binding resources"
```

---

### Task 3: `outputs.tf`

**Files:**
- Create: `outputs.tf`

**Interfaces:**
- Consumes: `google_storage_bucket.cloudb00stabucket` from Task 2.
- Produces: outputs `bucket_name`, `bucket_url`, `bucket_self_link`, `bucket_id`.

- [ ] **Step 1: Write `outputs.tf`**

```hcl
output "bucket_name" {
  description = "The bucket's name. Use this to reference the bucket by name in scripts or other Terraform configs."
  value       = google_storage_bucket.cloudb00stabucket.name
}

output "bucket_url" {
  description = "The gs:// URL of the bucket, e.g. for use with gsutil or CI upload scripts."
  value       = google_storage_bucket.cloudb00stabucket.url
}

output "bucket_self_link" {
  description = "The bucket's fully qualified GCP API URI. Useful when wiring this bucket into other Terraform resources by reference."
  value       = google_storage_bucket.cloudb00stabucket.self_link
}

output "bucket_id" {
  description = "The bucket's Terraform resource ID, in the form of its name. Useful for data source lookups elsewhere."
  value       = google_storage_bucket.cloudb00stabucket.id
}
```

- [ ] **Step 2: Validate**

Run: `terraform validate`
Expected: "Success! The configuration is valid."

- [ ] **Step 3: Format check**

Run: `terraform fmt -check`
Expected: no output, exit code 0 (or run `terraform fmt` then re-check).

- [ ] **Step 4: Commit**

```bash
git add outputs.tf
git commit -m "Add outputs for bucket name, url, self_link, and id"
```

---

### Task 4: `terraform.tfvars.example` + `.gitignore`

**Files:**
- Create: `terraform.tfvars.example`
- Create: `.gitignore`

**Interfaces:**
- Consumes: variable names from Task 1 (values must match every variable defined there).
- Produces: nothing consumed by later tasks — README (Task 5) references these files by name/path only.

- [ ] **Step 1: Write `terraform.tfvars.example`**

```hcl
# Copy this file to terraform.tfvars and fill in real values.
# terraform.tfvars is gitignored — never commit real project IDs or
# bucket names you care about keeping private.

project_id  = "my-gcp-project-id"
bucket_name = "my-globally-unique-bucket-name"
region      = "US"

storage_class = "STANDARD"
environment   = "dev"

versioning_enabled          = true
noncurrent_version_age_days = 30

labels = {
  owner = "my-team"
}

# Uncomment and edit to grant IAM roles on the bucket:
# iam_bindings = [
#   {
#     role   = "roles/storage.objectViewer"
#     member = "user:jane@example.com"
#   }
# ]
```

- [ ] **Step 2: Write `.gitignore`**

```
# Terraform local state and cache
.terraform/
*.tfstate
*.tfstate.*
crash.log
crash.*.log

# Real variable values (often contain project-specific or sensitive data)
*.tfvars
*.tfvars.json
!terraform.tfvars.example

# Override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# CLI config
.terraformrc
terraform.rc
```

- [ ] **Step 3: Format check the tfvars file**

Run: `terraform fmt -check terraform.tfvars.example`
Expected: no output, exit code 0 (or run `terraform fmt terraform.tfvars.example` then re-check).

- [ ] **Step 4: Confirm gitignore excludes tfvars but not the example**

Run: `git check-ignore -v terraform.tfvars.example; echo "exit=$?"; git check-ignore -v terraform.tfvars 2>/dev/null || echo "would-be-ignored (file may not exist yet, that's fine)"`
Expected: the first command prints `exit=1` (i.e. `terraform.tfvars.example` is NOT ignored — `check-ignore` exits 1 when a path is not ignored).

- [ ] **Step 5: Commit**

```bash
git add terraform.tfvars.example .gitignore
git commit -m "Add tfvars example template and gitignore"
```

---

### Task 5: Rewrite `README.md`

**Files:**
- Modify: `README.md` (full rewrite)

**Interfaces:**
- Consumes: nothing programmatically — describes the files from Tasks 1-4.

- [ ] **Step 1: Replace `README.md` contents**

```markdown
# gcp-storage-bucket-tf

This repo walks you through an introduction to Terraform by creating a Storage Bucket on Google Cloud Platform.

## Terraform 101

If you've never used Terraform before, here's the vocabulary you need for this repo:

- **Provider** — a plugin that lets Terraform talk to a specific platform (AWS, GCP, Azure, etc.). This repo uses the `google` provider, configured in `provider.tf`.
- **Resource** — a piece of infrastructure Terraform manages for you: a bucket, a VM, a database. Each resource block in `main.tf` maps to one real object in GCP.
- **Variable** — an input to your configuration, like a function parameter. Defined in `variables.tf`, values supplied via a `.tfvars` file or the CLI.
- **Output** — a value your configuration exposes after `apply`, like a return value. Defined in `outputs.tf`.
- **State** — Terraform's record of what it created and with what settings, stored in `terraform.tfstate` after your first `apply`. Terraform diffs your `.tf` files against state to figure out what changed.

With those five ideas, you can read any Terraform repo, including this one.

## Files and what they contain

- **provider.tf** — pins the required Terraform and provider versions, and configures the `google` provider with your project and region.

- **variables.tf** — every input this config accepts. Notable choices:
  - `storage_class` and `environment` have `validation` blocks, so `terraform plan` catches a typo like `"Standard"` (wrong case) before it ever reaches the GCP API.
  - `iam_bindings` is a list of `{ role, member }` objects, which drives a `for_each` in `main.tf` — see below.

- **main.tf** — the core config. Notable choices:
  - `uniform_bucket_level_access = true` — disables legacy per-object ACLs, enforces IAM only. This is the GCP-recommended setting and required in many enterprise org policies.
  - `public_access_prevention = "enforced"` — blocks all public access at the bucket level, regardless of IAM.
  - `versioning` and a `lifecycle_rule` are live: object versioning is on by default, and noncurrent versions are deleted after `var.noncurrent_version_age_days` (default 30) so your bucket doesn't grow forever.
  - IAM uses `for_each` over a map built from `var.iam_bindings`, so you can add or remove a grant by editing one list entry — Terraform figures out the diff instead of you rewriting the resource block.
  - The CMEK encryption and CORS blocks are in there as commented-out stubs — read them to see what enabling customer-managed encryption or cross-origin access would look like, uncomment when you need them.

- **outputs.tf** — the bucket's name, `gs://` URL, self-link, and ID, each with a description of when you'd actually use it (e.g. wiring this bucket into another Terraform config, or a CI script that needs the `gs://` URL).

- **terraform.tfvars.example** — a copyable template for the values this config needs. Copy it to `terraform.tfvars` and fill in your own project and bucket name.

## Why the .gitignore

Two things in a Terraform working directory should never be committed:

- **`terraform.tfstate`** (and `.terraform/`, its local cache) — state can contain resource IDs and, depending on the resource, sensitive attribute values. If you're working solo with local state, keeping it out of git is still the safe default; in a team, you'd use a remote backend instead (out of scope for this beginner repo).
- **`terraform.tfvars`** — your real values. `terraform.tfvars.example` is the tracked template; your actual `terraform.tfvars` usually has a real project ID and possibly other values you don't want in your commit history.

That's why `.gitignore` excludes `*.tfvars` but explicitly un-ignores `terraform.tfvars.example`.

## Steps to create resources

```bash
# Authenticate
gcloud auth application-default login

# Copy the example vars file and fill in your project_id and bucket_name
cp terraform.tfvars.example terraform.tfvars

# Then:
terraform init
terraform plan
terraform apply
```
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "Rewrite README with Terraform 101 section and updated file walkthrough"
```

---

### Task 6: Final validation pass

**Files:**
- None created/modified unless `fmt` finds drift.

**Interfaces:**
- Consumes: the complete config from Tasks 1-4.

- [ ] **Step 1: Recursive format check**

Run: `terraform fmt -check -recursive`
Expected: no output, exit code 0. If it fails, run `terraform fmt -recursive`, review the diff, and commit the formatting fix separately (`git commit -am "Fix terraform fmt formatting"`).

- [ ] **Step 2: Validate**

Run: `terraform validate`
Expected: "Success! The configuration is valid."

- [ ] **Step 3: Attempt a plan against the example vars (expected to fail on auth/project, not on config)**

Run: `terraform plan -var-file=terraform.tfvars.example`
Expected: Terraform fails with a GCP API/auth error (e.g. "project my-gcp-project-id not found" or a credentials error) — NOT a Terraform syntax or type error. This confirms the config itself is structurally sound; a real run requires `gcloud auth application-default login` and a real project as the README describes.

- [ ] **Step 4: Confirm no state or real tfvars got committed**

Run: `git status --short`
Expected: clean working tree (or only intentional untracked files); specifically confirm `terraform.tfstate`, `.terraform/`, and `terraform.tfvars` (if it exists locally) do NOT appear as tracked/staged.
