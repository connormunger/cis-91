# Project setup requirements

variable "credentials_file" { 
  default = "/home/con5523/Secrets/cis91-361901-cca95acde3c2.json" 
}

variable "project" {
  default = "cis91-361901"
}

variable "region" {
  default = "us-west1"
}

variable "zone" {
  default = "us-west1-b"
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.5.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)
  region  = var.region
  zone    = var.zone 
  project = var.project
}

# Network configuration below

resource "google_compute_network" "vpc_network" {
  name = "dokuwiki-network"
}

resource "google_compute_firewall" "default_firewall" {
  name = "dokuwiki-firewall"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports = ["22", "80"]
  }
  source_ranges = ["0.0.0.0/0"]
}

# Virtual Machines

resource "google_compute_instance" "vm_instance" {
  name         = "dokuwiki"
  machine_type = "e2-micro"
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }

  attached_disk {
    source = google_compute_disk.data-disk.self_link
    device_name = "data"
  }

  service_account {
    email  = google_service_account.dokuwiki-service-account.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_disk" "data-disk" {
  name  = "data"
  type  = "pd-ssd"
  size = "100"
}

#Service Account
resource "google_service_account" "dokuwiki-service-account" {
  account_id   = "dokuwiki-service-account"
  display_name = "dokiwiki-service-account"
  description = "Service account for dokuwiki"
}

resource "google_project_iam_member" "project_member" {
  role = "roles/compute.viewer"
  member = "serviceAccount:${google_service_account.dokuwiki-service-account.email}"
}

#Storage Bucket
resource "google_storage_bucket" "dokuwiki-backup-bucket" {
  name          = "dokuwiki-backup-storage-bucket-connor-cis91"
  location      = "US-CENTRAL1"
  force_destroy = true

  lifecycle_rule {
    condition {
	age = 180
    }
    action {
      type = "Delete"
    }
   } 
}

resource "google_storage_bucket_iam_binding" "binding" {
  bucket = google_storage_bucket.dokuwiki-backup-bucket.name
  role = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:dokuwiki-service-account@cis91-361901.iam.gserviceaccount.com",
  ]
}

# Output for SSH
output "external-ip" {
  value = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}
