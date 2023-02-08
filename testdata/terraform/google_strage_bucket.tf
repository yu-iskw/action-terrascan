resource "google_storage_bucket" "failed_bucket" {
  name = "failed-bucket"
}


resource "google_project_iam_member" "failed_iam" {
  role   = "roles/owner"
  member = "user:test@test.com"
}
