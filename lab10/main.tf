
variable "credentials_file" { 
  default = "/home/con5523/Secrets/cis91-361901-cca95acde3c2.json" 
}

variable "project" {
  default = "cis91-361901"
}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-c"
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

resource "google_compute_network" "vpc_network" {
  name = "cis91-network"
}

resource "google_compute_instance" "vm_instance" {
  name         = "cis91"
  machine_type = "e2-micro"

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
    source = google_compute_disk.lab09.self_link
    device_name = "lab09"
  }

  service_account {
    email  = google_service_account.lab08-service-account.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_firewall" "default-firewall" {
  name = "default-firewall"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports = ["22", "80", "3000", "5000"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_service_account" "lab08-service-account" {
  account_id   = "lab08-service-account"
  display_name = "lab08-service-account"
  description = "Service account for lab 08"
}

resource "google_project_iam_member" "project_member" {
  role = "roles/compute.viewer"
  member = "serviceAccount:${google_service_account.lab08-service-account.email}"
}

resource "google_compute_disk" "lab09" {
  name  = "lab09"
  type  = "pd-ssd"
  size = "100"
}

resource "google_storage_bucket" "test-bucket" {
  name          = "connors-cis91-test-bucket"
  location      = "US-CENTRAL1"
  force_destroy = true
}

resource "google_storage_bucket_iam_binding" "binding" {
  bucket = google_storage_bucket.test-bucket.name
  role = "roles/storage.admin"
  members = [
    "serviceAccount:lab08-service-account@cis91-361901.iam.gserviceaccount.com",
  ]
}

output "external-ip" {
  value = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}
