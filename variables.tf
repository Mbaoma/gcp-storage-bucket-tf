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
