# Partial backend configuration. Supply values at init time:
#   terraform init -backend-config=backend.hcl
# See backend.hcl.example and scripts/bootstrap-backend.sh
terraform {
  backend "azurerm" {}
}
