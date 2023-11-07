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

resource "nomad_job" "efs_plugin" {
  jobspec = file("${path.module}/efs_csi_jobspec.hcl")
}
