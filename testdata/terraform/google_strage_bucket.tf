resource "google_storage_bucket" "failed_bucket" {
  name = "failed-bucket"
}

resource "google_storage_bucket" "failed_bucket_02" {
  name = "failed-bucket-02"
}
