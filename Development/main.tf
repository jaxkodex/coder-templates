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

variable "docker_socket" {
  default     = ""
  description = "(Optional) Docker socket URI"
  type        = string
}

provider "docker" {
  host = var.docker_socket != "" ? var.docker_socket : null
}

data "coder_provisioner" "me" {}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

# GitHub authentication - requires Coder deployment to have GitHub OAuth configured
# See: https://coder.com/docs/admin/external-auth
data "coder_external_auth" "github" {
  id = "github"
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

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

# Inject GitHub token as environment variable
resource "coder_env" "github_token" {
  agent_id = coder_agent.main.id
  name     = "GITHUB_TOKEN"
  value    = data.coder_external_auth.github.access_token
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
    #!/bin/bash
    set -e

    # Configure Git to use GitHub token for authentication
    if [ -n "$GITHUB_TOKEN" ]; then
      echo "Configuring Git with GitHub credentials..."
      git config --global credential.helper store
      echo "https://${data.coder_external_auth.github.access_token}@github.com" > ~/.git-credentials
      chmod 600 ~/.git-credentials

      # Set Git user info from Coder workspace owner
      git config --global user.name "${data.coder_workspace_owner.me.full_name != "" ? data.coder_workspace_owner.me.full_name : data.coder_workspace_owner.me.name}"
      git config --global user.email "${data.coder_workspace_owner.me.email}"

      echo "Git configured successfully with GitHub authentication"
    else
      echo "Warning: GITHUB_TOKEN not available. GitHub authentication not configured."
    fi

    # Run additional programs at workspace startup
  EOF
  run_on_start       = true
  start_blocks_login = true
}

# Build Docker image from Dockerfile
resource "docker_image" "coder_image" {
  name = "coder-${data.coder_workspace.me.id}"
  build {
    context    = "${path.module}"
    dockerfile = "Dockerfile"
    tag        = ["coder-${data.coder_workspace.me.id}:latest"]
  }
  triggers = {
    dockerfile_hash = filemd5("${path.module}/Dockerfile")
  }
}

# Persistent volume for user home directory
resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle {
    ignore_changes = all
  }
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

# Docker container for the workspace
resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.coder_image.name
  name  = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"

  hostname   = data.coder_workspace.me.name
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }

  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}
