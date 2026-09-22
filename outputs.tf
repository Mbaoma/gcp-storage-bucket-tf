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
