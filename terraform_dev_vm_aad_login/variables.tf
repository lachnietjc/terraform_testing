variable "vm_name" {
  description = "name of virtual machine"
  type        = string
  default     = "new-spark-test2"
}

variable "location" {
  description = "location of deployment"
  type        = string
  default     = "eastus"
}

variable "ud" {
  description = "user data script"
  type        = string
  default     = "startup_docker_nlp.sh"
}

variable "user" {
  description = "My Username for organization"
  type        = string
  default     = "lachniej"
}

variable "env" {
  description = "environment"
  type        = string
  default     = "dev"
}

variable "as_email" {
  description = "auto shutdown notification email"
  type        = string
  default     = "emailt address to send auto shutdown notification"
}

