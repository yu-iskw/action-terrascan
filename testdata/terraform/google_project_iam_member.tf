resource "google_project_iam_member" "violated_resource" {
  role   = "roles/owner"
  member = "user:test@example.com"
}

resource "google_project_iam_member" "non_violated_resource" {
  role   = "roles/bigquery.dataViewer"
  member = "user:test@example.com"
}
