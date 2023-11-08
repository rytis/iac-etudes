resource "nomad_job" "test" {

  jobspec = <<EOT

job "sleep_job" {

  group "sleepers" {

    volume "nomad_data" {
      type = "csi"
      read_only = false
      source = "nomad-data-volume"
      attachment_mode = "file-system"
      access_mode = "multi-node-multi-writer"
    }

    task "sleeper" {
      driver = "exec"
      volume_mount {
        volume = "nomad_data"
        destination = "/nomad-data"
        read_only = false
      }
      config {
        command = "bash"
        args = ["-c", "while true; do ls -l /; sleep 1; done"]
      }
    }

  }
}

EOT
}

resource "nomad_job" "efs_plugin" {
  jobspec = file("${path.module}/efs_csi_jobspec.hcl")
}

# data "nomad_plugin" "efs" {
#   plugin_id        = "aws-efs0"
#   wait_for_healthy = true
# }

resource "nomad_csi_volume_registration" "nomad_data" {
  #   depends_on = [data.nomad_plugin.efs]

  plugin_id   = "aws-efs0"
  volume_id   = "nomad-data-volume"
  name        = "nomad-data-name"
  external_id = var.efs_volume.id

  capability {
    access_mode     = "multi-node-multi-writer"
    attachment_mode = "file-system"
  }

  mount_options {
    mount_flags = ["iam"]
  }
}
