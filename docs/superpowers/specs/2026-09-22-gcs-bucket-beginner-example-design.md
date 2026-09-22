# GCS Bucket Beginner Example — Design

## Goal

A newbie who stumbles on this repo should be able to read it top to bottom
and come away understanding core Terraform concepts (providers, resources,
variables, outputs, state) *and* a few GCP Cloud Storage best practices
(uniform bucket-level access, public access prevention, versioning,
lifecycle rules, least-privilege IAM). The repo must also be a genuinely
runnable example, not just illustrative snippets.

## Current state

`main.tf`, `outputs.tf`, `provider.tf`, `variables.tf` all exist but are
empty (0 bytes). `README.md` already describes what they're *supposed* to
contain, written ahead of the code. There is no `.gitignore` and no
`terraform.tfvars` template.

## Files

### `provider.tf`
- `terraform { required_version, required_providers { google } }` pinning
  the `hashicorp/google` provider to a `~>` minor version constraint.
- `provider "google" { project = var.project_id, region = var.region }`.
- Comment explaining providers are plugins that translate HCL into API
  calls for a specific platform.

### `variables.tf`
Each variable has a `description`; validated ones get a `validation`
block with a clear `error_message`.

- `project_id` (string, required, no default) — validated non-empty.
- `bucket_name` (string, required) — validated against GCS naming rules
  (lowercase, no underscores at start, length) at a basic level.
- `region` (string, default `"US"`) — GCS bucket location.
- `storage_class` (string, default `"STANDARD"`) — validated against the
  real GCS class list: `STANDARD`, `NEARLINE`, `COLDLINE`, `ARCHIVE`.
- `environment` (string, default `"dev"`) — validated to
  `dev`/`staging`/`prod`.
- `versioning_enabled` (bool, default `true`).
- `noncurrent_version_age_days` (number, default `30`) — used by the
  lifecycle rule to delete noncurrent object versions after N days.
- `labels` (map(string), default `{}`).
- `iam_bindings` (list(object({ role = string, member = string })),
  default `[]`) — drives the `for_each` IAM resource.

### `main.tf`
- `google_storage_bucket "this"`:
  - `name`, `location = var.region`, `storage_class`, `labels`.
  - `uniform_bucket_level_access = true`.
  - `public_access_prevention = "enforced"`.
  - `versioning { enabled = var.versioning_enabled }` — live block.
  - `lifecycle_rule { condition { days_since_noncurrent_time =
    var.noncurrent_version_age_days }, action { type = "Delete" } }` —
    live block, gated conceptually on versioning (documented in a
    comment, not enforced in HCL — keeping it simple).
  - Commented-out CMEK block (`encryption { default_kms_key_name = ... }`)
    — kept as a stub per existing README promise.
  - Commented-out CORS block — kept as a stub per existing README promise.
- `google_storage_bucket_iam_member "this"`:
  - `for_each = { for b in var.iam_bindings : "${b.role}-${b.member}" => b }`
  - `bucket = google_storage_bucket.this.name`, `role = each.value.role`,
    `member = each.value.member`.

### `outputs.tf`
- `bucket_name`, `bucket_url`, `bucket_self_link`, `bucket_id` — each with
  a `description` explaining a realistic reason you'd want it (e.g.
  referencing the bucket from another Terraform config or a CI script).

### `terraform.tfvars.example`
Copyable template with placeholder values and inline `#` comments for
every variable above, including a commented-out example `iam_bindings`
entry.

### `.gitignore`
Standard Terraform ignore list: `.terraform/`, `*.tfstate`,
`*.tfstate.*`, `crash.log`, `*.tfvars` (with `!terraform.tfvars.example`
negation so the template itself stays tracked), `.terraform.lock.hcl`
left tracked (that file *should* be committed — noted in README, not
ignored).

### `README.md`
Restructured, keeping the existing tone/voice but adding:
1. A short "Terraform 101" section near the top: what a provider,
   resource, variable, output, and state file are, in plain language,
   before diving into this repo's specific files.
2. Updated file-by-file walkthrough matching the real file contents
   above (replacing the current pre-written description).
3. A paragraph on why `.gitignore` matters here specifically: state
   files can contain resource IDs and sometimes sensitive values, and
   real `.tfvars` files often hold project-specific data that shouldn't
   be committed — that's why `terraform.tfvars.example` is tracked but
   `terraform.tfvars` is not.
4. Updated "Steps to create resources" section: copy
   `terraform.tfvars.example` to `terraform.tfvars`, fill in real
   values, then `terraform init/plan/apply` (existing steps, adjusted).

## Testing / validation

No live GCP project is assumed. Verification is:
- `terraform fmt -check` — formatting.
- `terraform init` (no backend, local only) then `terraform validate` —
  confirms HCL is syntactically and internally valid.
- `terraform plan -var-file=terraform.tfvars.example` is expected to
  fail at the API-auth/project stage (no real credentials/project) —
  that failure mode will be noted, not worked around.

## Out of scope

- Modules, multiple environments/workspaces, remote state backend
  configuration, CI/CD, CMEK/CORS as *live* (non-commented) config.
