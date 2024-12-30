# Especificamos el proveedor y los credenciales de acceso
provider "aws" {
  access_key = "xxxxxxxxxxxxxxxxxxxxxxxxxxx"
  secret_key = "xxxxxxxxxxxxxxxxxxxxxxxxxxx"
  region = var.aws_region
}

# Crea una VPC definiendo el CIDR para aislar nuestro proyecto
resource "aws_vpc" "vpc_doscapas" {
  cidr_block = "10.0.0.0/16"
}

# Creamos una 'internet gateway' para otorgar a nuestra subred acceso desde el mundo exterior
resource "aws_internet_gateway" "ig_doscapas" {
  vpc_id = aws_vpc.vpc_doscapas.id
}

# Asignamos el 'Internet Gateway' a nuestra VPC
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.vpc_doscapas.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig_doscapas.id
}

# Creamos una subred dentro del CIDR previo para nuestra máquinas
resource "aws_subnet" "subnet_doscapas" {
  vpc_id                  = aws_vpc.vpc_doscapas.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Especificamos al VPC reglas de firewall con acceso al puerto 22 (adminitracion maquinas)
# y acceso al puerto 80 para el balanceador.
resource "aws_security_group" "sg_doscapas" {
  name        = "sg_doscapas"
  description = "Security Group para el VPC"
  vpc_id      = aws_vpc.vpc_doscapas.id

  # Permite entrada tcp/22 desde cualquier lado
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permite entrada tcp/80 desde rango 10.0.0.0/16
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Permite entrada tcp/5432 desde rango 10.0.0.0/16
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Permite la salida a todos los destinos
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creamos un Security Group (Reglas Firewall) para el balanceador
# Este SOLO permitirá el acceso 80.
resource "aws_security_group" "elb" {
  name        = "arquitectura_2_capas_elb"
  description = "Balanceador de carga externo"
  vpc_id      = aws_vpc.vpc_doscapas.id

  # Acceso tcp/80 sin restricción
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Salida del balanceador sin restricción
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "web" {
  name = "doscapas-elb"

  subnets         = [aws_subnet.subnet_doscapas.id]
  security_groups = [aws_security_group.elb.id]
  instances       = [aws_instance.web.id, aws_instance.postgres.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

resource "aws_key_pair" "auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "web" {
  tags = { Name = "daiiti-web" }
  # El bloque "connection" explica al provisionador cómo comunicarse
  # con el recurso (para instalar paquetes
  connection {
    type = "ssh"
    user = "ubuntu"
    host = self.public_ip
    private_key = file(var.private_key_path) # Conexión a través de clave SSH privada
  }

# Especifica el tamaño de la VM especificado por variable
  instance_type = var.aws_instance_type

# Selecciona el AMI correcto basado en la región que hemos especificado en la variable.
  ami = var.aws_amis[var.aws_region]

  # ID Nombre de la clave SSH 
  key_name = aws_key_pair.auth.id

  # Nombre del security group que permite acceso HTTP y SSH a la máquina
  vpc_security_group_ids = [aws_security_group.sg_doscapas.id]

  # Esta VM la vamos a crear dentro de la misma subred que nuestro ELB.
  # En un entorno de producción es mejor separar las máquinas (Backend)
  # de los frontales (Balanceador de carga)
  subnet_id = aws_subnet.subnet_doscapas.id

  provisioner "file" {
    source      = var.php_script_path # Ruta local al archivo PHP
    destination = "/home/ubuntu/script.php"  # Ruta remota donde se copiará
  }

  # Ejecutamos un provisionador remoto una vez la VM esté lista.
  # En este caso, instalamos NGINX y modificamos el fichero por defecto.
  # NGINX estará disponible por el puerto 80.
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y update",
      "sudo apt-get -y install apache2",
      "sudo apt-get -y install php libapache2-mod-php php-pgsql",
      
      "echo 'export POSTGRES_HOST=${aws_instance.postgres.private_ip}' | sudo tee -a /etc/apache2/envvars",
      "echo 'POSTGRES_HOST=${aws_instance.postgres.private_ip}' | sudo tee -a /etc/environment",
      "source /etc/environment",

      "sudo rm /var/www/html/*",
      "sudo mv /home/ubuntu/script.php /var/www/html/index.php",
      "sudo chown www-data:www-data /var/www/html/index.php",
      "sudo chmod 644 /var/www/html/index.php",

      "sudo systemctl restart apache2"
    ]
  }
}

resource "aws_instance" "postgres" {
  tags = { Name = "daiiti-postgres" }
  # El bloque "connection" explica al provisionador cómo comunicarse
  # con el recurso (para instalar paquetes
  connection {
    type = "ssh"
    user = "ubuntu"
    host = self.public_ip
    private_key = file(var.private_key_path) # Conexión a través de clave SSH privada
  }

# Especifica el tamaño de la VM especificado por variable
  instance_type = var.aws_instance_type

# Selecciona el AMI correcto basado en la región que hemos especificado en la variable.
  ami = var.aws_amis[var.aws_region]

  # ID Nombre de la clave SSH 
  key_name = aws_key_pair.auth.id

  # Nombre del security group que permite acceso HTTP y SSH a la máquina
  vpc_security_group_ids = [aws_security_group.sg_doscapas.id]

  # Esta VM la vamos a crear dentro de la misma subred que nuestro ELB.
  # En un entorno de producción es mejor separar las máquinas (Backend)
  # de los frontales (Balanceador de carga)
  subnet_id = aws_subnet.subnet_doscapas.id

  provisioner "file" {
    source      = "test_results.csv" 
    destination = "/tmp/test_results.csv" 
  }

  provisioner "file" {
    source      = var.dbconfig_script_path  
    destination = "/tmp/dbconfig.sql" 
  }

  # Ejecutamos un provisionador remoto una vez la VM esté lista.
  # En este caso, instalamos NGINX y modificamos el fichero por defecto.
  # NGINX estará disponible por el puerto 80.
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y postgresql postgresql-contrib",
      "sudo systemctl start postgresql",
      "sudo systemctl enable postgresql",

      "sudo chown ubuntu:ubuntu /tmp/test_results.csv",
      "sudo chmod 644 /tmp/test_results.csv",
      "sudo chown ubuntu:ubuntu /tmp/dbconfig.sql",
      "sudo chmod 644 /tmp/dbconfig.sql",
      "sudo -u postgres psql -f /tmp/dbconfig.sql",

      "echo \"listen_addresses = '*'\" | sudo tee -a /etc/postgresql/16/main/postgresql.conf",
      "echo \"host\tuser_db\t\tmy_user\t\t10.0.0.0/16\t\tmd5\" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf",

      "sudo systemctl restart postgresql"
    ]
  }
}