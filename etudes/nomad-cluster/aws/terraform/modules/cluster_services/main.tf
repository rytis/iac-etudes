provider "nomad" {
  address = var.nomad_address
}

resource "nomad_job" "test" {
  jobspec = <<EOT

job "sleep_job" {
  group "sleepers" {
    task "sleeper" {
      driver = "exec"
      config {
        command = "sleep"
        args = ["infinity"]
      }
    }
  }
}

EOT
}

