provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "qr-platform"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}
