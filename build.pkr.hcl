packer {
  required_plugins {
    docker = {
      version = ">= 0.0.7"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "nginx" {
  image  = "nginx:latest"
  commit = true
  changes = [
    "EXPOSE 80",
    "CMD [\"nginx\", \"-g\", \"daemon off;\"]"
  ]
}

build {
  name = "mon-build-custom"
  sources = [
    "source.docker.nginx"
  ]

  # C'est ici que Packer prend votre fichier local pour le mettre dans l'image
  provisioner "file" {
    source      = "index.html"
    destination = "/usr/share/nginx/html/index.html"
  }

  # Tag de l'image finale pour qu'on la retrouve facilement
  post-processors {
    post-processor "docker-tag" {
      repository = "nginx-custom"
      tags       = ["latest"]
    }
  }
}