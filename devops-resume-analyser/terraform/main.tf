terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

# Configure the Docker provider for Windows
provider "docker" {
  host = "npipe:////./pipe/docker_engine"
}

# 1. Create a dedicated Docker network for the pipeline
resource "docker_network" "devops_network" {
  name = "devops_pipeline_network"
}

# 2. Create persistent volumes for SonarQube
resource "docker_volume" "sonarqube_data" {
  name = "sonarqube_data"
}
resource "docker_volume" "sonarqube_logs" {
  name = "sonarqube_logs"
}
resource "docker_volume" "sonarqube_extensions" {
  name = "sonarqube_extensions"
}

# 3. Create persistent volume for Jenkins
resource "docker_volume" "jenkins_home" {
  name = "jenkins_home"
}

# 4. Provision SonarQube Container
resource "docker_image" "sonarqube" {
  name         = "sonarqube:community"
  keep_locally = true
}

resource "docker_container" "sonarqube" {
  name  = "sonarqube"
  image = docker_image.sonarqube.image_id

  ports {
    internal = 9000
    external = 9000
  }

  volumes {
    volume_name    = docker_volume.sonarqube_data.name
    container_path = "/opt/sonarqube/data"
  }
  volumes {
    volume_name    = docker_volume.sonarqube_logs.name
    container_path = "/opt/sonarqube/logs"
  }
  volumes {
    volume_name    = docker_volume.sonarqube_extensions.name
    container_path = "/opt/sonarqube/extensions"
  }

  networks_advanced {
    name = docker_network.devops_network.name
  }
}

# 5. Provision Jenkins Container
resource "docker_image" "jenkins" {
  name         = "jenkins/jenkins:lts"
  keep_locally = true
}

resource "docker_container" "jenkins" {
  name  = "jenkins"
  image = docker_image.jenkins.image_id
  user  = "root"

  # Access Jenkins Web UI
  ports {
    internal = 8080
    external = 8081
  }
  
  # Jenkins Agent Port
  ports {
    internal = 50000
    external = 50000
  }

  volumes {
    volume_name    = docker_volume.jenkins_home.name
    container_path = "/var/jenkins_home"
  }

  # Allow Jenkins to run Docker commands (Docker-in-Docker via socket)
  # On Windows, this is necessary to allow the Jenkins container to access the host's Docker daemon
  volumes {
    host_path      = "//var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }

  networks_advanced {
    name = docker_network.devops_network.name
  }
}
