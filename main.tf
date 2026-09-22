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
