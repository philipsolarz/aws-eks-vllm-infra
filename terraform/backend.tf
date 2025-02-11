terraform {
  backend "s3" {
    bucket         = "terraform-state"
    key            = "environments/dev/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
