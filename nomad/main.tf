terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.6.10"
    }
    nomad = {
      source = "hashicorp/nomad"
      version = "1.4.19"
    }
  }
}

variable "image_type" {
  description = "Which image type?"
  default     = "base"
  validation {
    condition = contains([
      "base",
      "node"
    ], var.image_type)
    error_message = "Invalid image type!"
  }
}

locals {
  username = data.coder_workspace.me.owner
}

data "coder_provisioner" "me" {
}

provider "nomad" {
  address = "http://100.72.238.121:4646"
  region  = "global"
}

data "coder_workspace" "me" {
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  login_before_ready     = false
  startup_script_timeout = 180
  startup_script         = <<-EOT
    set -e

    # install and start code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server --version 4.8.3
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
  EOT

  # These environment variables allow you to make Git commits right away after creating a
  # workspace. Note that they take precedence over configuration defined in ~/.gitconfig!
  # You can remove this block if you'd prefer to configure Git manually or using
  # dotfiles. (see docs/dotfiles.md)
  env = {
    GIT_AUTHOR_NAME     = "${data.coder_workspace.me.owner}"
    GIT_COMMITTER_NAME  = "${data.coder_workspace.me.owner}"
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace.me.owner_email}"
    GIT_COMMITTER_EMAIL = "${data.coder_workspace.me.owner_email}"
  }
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337/?folder=/home/${local.username}"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

resource "nomad_job" "app" {
  purge_on_destroy = "true"

  jobspec = <<EOT
  job "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}" {
    region = "global"
    datacenters = ["dc1"]
    type        = "service"

    meta {
      version = "1"
    }

    group "coder" {
      count = 1


      task "coder" {
        driver = "docker"
        
        config {
          image = "ghcr.io/simse/coder-nomad/${var.image_type}:latest"
          volumes = [
            "/nomad/coder-workspaces/${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}:/home/${local.username}"
          ]
          entrypoint = ["sh", "-c", "echo '${base64encode(coder_agent.main.init_script)}' | base64 -d | sh"]
          hostname = "${data.coder_workspace.me.name}"
        }

        env {
          CODER_AGENT_TOKEN = "${coder_agent.main.token}"
        }

        resources {
          cpu    = 100
          memory = 2048
        }
      }
    }
  }
  EOT

  hcl2 {
    enabled = true
  }
}