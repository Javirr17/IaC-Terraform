variable "public_key_path" {
  default = "usalkey.pub"
}

variable "private_key_path" {
  default = "usalkey.pem"
}

variable "key_name" {
  description = "Nombre clave SSH"
  default = "usalkey"
}

variable "php_script_path" {
  description = "PHP script path"
  default = "scripts/script.php"
}

variable "dbconfig_script_path" {
  description = "DB config script path"
  default = "scripts/dbconfig.sql"
}

variable "aws_region" {
  description = "Region AWS donde desplegar"
  default     = "eu-north-1"
}

variable "aws_instance_type" {
  description = "Tipo de instancia para las VM"
  default     = "t3.micro"
}

# Canonical, Ubuntu, 24.04, amd64 noble image
variable "aws_amis" {
  default = {
    eu-north-1 = "ami-075449515af5df0d1"
    us-east-1  = "ami-0e2c8caa4b6378d8c"
    us-west-1  = "ami-0657605d763ac72a8"
  }
}


