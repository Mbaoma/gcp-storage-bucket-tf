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
