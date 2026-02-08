terraform {
  backend "s3" {
    bucket = "terraform-state-selfhealing-1770562384"
    key    = "env/dev/terraform.tfstate"
    region = "eu-south-1"
  }
}
