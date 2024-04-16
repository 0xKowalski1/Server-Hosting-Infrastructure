terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.5"
    }
  }
}

provider "google" {
  project = "server-hosting-420312"
  region  = "europe-west1"
}

resource "google_compute_firewall" "allow_traffic" {
  name    = "allow-traffic"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8080", "8081"]
  }

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }

  source_ranges = ["0.0.0.0/0"] 
  target_tags   = ["allow-traffic"]

}


resource "google_compute_instance" "vm_instance" {
  name         = "ubuntu-vm"
  machine_type = "e2-standard-4"
  zone         = "europe-west1-b"
  tags         = ["allow-traffic"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
        size = 20
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP
    }
  }

  metadata_startup_script = file("${path.module}/control-node-startup.sh")

  scheduling {
    preemptible       = true
    automatic_restart = false
  }
}

