# =============================================================================
# Laboratorio 02 - Fundamentos de DevOps y SRE (UNAL 2026-01)
# Paso 1: Calentamiento con Proveedor Local (hashicorp/local)
# Costo: $0.00 (Sin nube ni contenedores)
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.0"
    }
  }
}

# Recurso declarativo: archivo de texto en el sistema de archivos local
resource "local_file" "hola_mundo" {
  filename        = "${path.module}/hola-mundo.txt"
  file_permission = "0644"
  content         = <<-EOT
    ¡Hola Mundo desde Terraform!
    Curso: Fundamentos de DevOps y SRE - Universidad Nacional de Colombia
    Laboratorio 02: Infraestructura como Código (IaC) 100% Local

    Este archivo fue aprovisionado declarativamente usando el proveedor hashicorp/local.
    Revisa el archivo terraform.tfstate para observar cómo Terraform registra su estado.
  EOT
}

output "archivo_creado" {
  description = "Ruta del archivo gestionado por Terraform"
  value       = local_file.hola_mundo.filename
}

output "contenido_sha256" {
  description = "Hash SHA-256 del contenido para control de cambios e idempotencia"
  value       = local_file.hola_mundo.content_sha256
}
