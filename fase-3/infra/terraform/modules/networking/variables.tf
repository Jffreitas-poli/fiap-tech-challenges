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
}

variable "azs" {
  description = "Availability Zones usadas pelas subnets."
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets publicas (uma por AZ, mesma ordem de azs)."
  type        = list(string)
  default     = ["10.20.0.0/20", "10.20.16.0/20"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas (uma por AZ, mesma ordem de azs)."
  type        = list(string)
  default     = ["10.20.128.0/20", "10.20.144.0/20"]
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
