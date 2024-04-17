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
    ports    = ["5000", "8080", "8081"]
  }

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-traffic"]

}

output "control_node_external_ip" {
  value = google_compute_instance.control_node.network_interface[0].access_config[0].nat_ip
}



resource "google_compute_instance" "control_node" {
  name         = "control-node"
  machine_type = "e2-medium"
  zone         = "europe-west1-b"
  tags         = ["allow-traffic"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 10
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

resource "google_compute_instance" "worker_node" {
  name         = "worker-node"
  machine_type = "e2-standard-4"
  zone         = "europe-west1-b"
  tags         = ["allow-traffic"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP
    }
  }

  depends_on = [google_compute_instance.control_node]
  metadata_startup_script = templatefile("${path.module}/worker-node-startup.sh", {
    CONTROL_NODE_EXTERNAL_IP = google_compute_instance.control_node.network_interface[0].access_config[0].nat_ip
  })

  scheduling {
    preemptible       = true
    automatic_restart = false
  }
}
