
provider "aws" {
  region     = "us-east-1"
  
}

resource "aws_instance" "my_instance" {
  ami           = "ami-083654bd07b5da81d"
  instance_type = "t2.micro"  

  tags = {
    "Name" = "tf-instance-test"
  }
}


  
