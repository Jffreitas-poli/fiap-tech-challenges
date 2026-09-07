variable "name" {
  description = "Prefixo de nomeacao dos recursos (ex.: tc)."
  type        = string
}

variable "env" {
  description = "Ambiente (lab, prod)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR da VPC."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr precisa ser um bloco CIDR IPv4 valido (ex.: 10.20.0.0/16)."
  }
}

variable "azs" {
  description = "Availability Zones usadas pelas subnets."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.azs) >= 2
    error_message = "Informe pelo menos 2 AZs para alta disponibilidade do EKS/RDS."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets publicas (uma por AZ, mesma ordem de azs)."
  type        = list(string)
  default     = ["10.20.0.0/20", "10.20.16.0/20"]

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.azs)
    error_message = "public_subnet_cidrs deve ter exatamente uma entrada por AZ em azs."
  }
  validation {
    condition     = alltrue([for c in var.public_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Todos os itens de public_subnet_cidrs devem ser CIDRs IPv4 validos."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas (uma por AZ, mesma ordem de azs)."
  type        = list(string)
  default     = ["10.20.128.0/20", "10.20.144.0/20"]

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.azs)
    error_message = "private_subnet_cidrs deve ter exatamente uma entrada por AZ em azs."
  }
  validation {
    condition     = alltrue([for c in var.private_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Todos os itens de private_subnet_cidrs devem ser CIDRs IPv4 validos."
  }
}

variable "eks_cluster_name" {
  description = "Nome do cluster EKS; usado nas tags kubernetes.io/cluster/<nome> das subnets."
  type        = string
}

variable "single_nat_gateway" {
  description = "Se true, cria um unico NAT Gateway compartilhado (mais barato)."
  type        = bool
  default     = true
}
