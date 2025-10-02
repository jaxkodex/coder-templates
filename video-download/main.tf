terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

data "coder_provisioner" "me" {}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

data "coder_parameter" "volume_host_path" {
  name         = "volume_host_path"
  display_name = "Volume Host Path"
  description  = "The host path to mount as /videos in the workspace"
  type         = "string"
  default      = "/mnt/videos"
  mutable      = false
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = data.coder_provisioner.me.os

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }
}

# Use this to set environment variables in your workspace
# details: https://registry.terraform.io/providers/coder/coder/latest/docs/resources/env
resource "coder_env" "welcome_message" {
  agent_id = coder_agent.main.id
  name     = "WELCOME_MESSAGE"
  value    = "Welcome to your Coder workspace!"
}

# Adds code-server
# See all available modules at https://registry.coder.com/modules
module "code-server" {
  count  = data.coder_workspace.me.start_count
  source = "registry.coder.com/coder/code-server/coder"

  # This ensures that the latest non-breaking version of the module gets downloaded, you can also pin the module version to prevent breaking changes in production.
  version = "~> 1.0"

  agent_id = coder_agent.main.id
}

# Runs a script at workspace start/stop or on a cron schedule
# details: https://registry.terraform.io/providers/coder/coder/latest/docs/resources/script
resource "coder_script" "startup_script" {
  agent_id           = coder_agent.main.id
  display_name       = "Startup Script"
  script             = <<-EOF
    #!/bin/sh
    set -e

    # Clone or refresh youtube-dl repository
    if [ -d "$HOME/youtube-dl" ]; then
      echo "Refreshing youtube-dl repository..."
      cd "$HOME/youtube-dl" && git pull || true
    else
      echo "Cloning youtube-dl repository..."
      git clone https://github.com/ytdl-org/youtube-dl.git "$HOME/youtube-dl" || true
    fi
  EOF
  run_on_start       = true
  start_blocks_login = true
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = "jaxkodex/coder-images:ffmpeg-01102025-1"
  name  = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"

  hostname = data.coder_workspace.me.name

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]

  command = ["sh", "-c", coder_agent.main.init_script]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    host_path      = data.coder_parameter.volume_host_path.value
    container_path = "/videos"
  }
}
