# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

provider "azurerm" {
  features {}

  skip_provider_registration = true
}

## Tenant Id
data "azurerm_client_config" "current" {}

## Client Id
data "azurerm_subscription" "current" {}


# Create a resource group if it doesn't exist
data "azurerm_resource_group" "myterraformgroup" {
  name = "your resource group"
}

# Create virtual network
data "azurerm_virtual_network" "myterraformnetwork" {
  name                = "your virtual network"
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name

}

# Create subnet
data "azurerm_subnet" "myterraformsubnet" {
  name                = "subnet for vpn gateway"
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name

  virtual_network_name = data.azurerm_virtual_network.myterraformnetwork.name
}
# Data template Bash bootstrapping file
data "template_file" "ud" {
  template = file(var.ud)
}

data "azurerm_network_security_group" "myterraformnsg" {
  name                = "your networks security group"
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
  name                = "myPublicIP"
  location            = "eastus"
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name
  allocation_method   = "Dynamic"

  tags = {
    environment = var.env
    owner       = var.user

  }
}

output "public_ip_address" {
  value = azurerm_public_ip.myterraformpublicip.*.ip_address
}

output "vm_id" {
  value = azurerm_linux_virtual_machine.myterraformvm.virtual_machine_id
}

# output "principal_id_maybe" {
#   value = azurerm_user_assigned_identity.example.principal_id
# }

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
  name                = "myNIC"
  location            = "East US"
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = data.azurerm_subnet.myterraformsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
  }

  tags = {
    environment = var.env
    owner       = var.user
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.myterraformnic.id
  network_security_group_id = data.azurerm_network_security_group.myterraformnsg.id
}


# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = data.azurerm_resource_group.myterraformgroup.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = data.azurerm_resource_group.myterraformgroup.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = var.env
    owner       = var.user
  }
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
output "tls_private_key" {
  value     = tls_private_key.example_ssh.private_key_pem
  sensitive = true
}

# # Create user assigned Identity to get principal_id
# resource "azurerm_user_assigned_identity" "example" {
#   resource_group_name = data.azurerm_resource_group.myterraformgroup.name
#   location            = var.location

#   name = var.vm_name
# }

# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterraformvm" {
  name                  = var.vm_name
  location              = "eastus"
  resource_group_name   = data.azurerm_resource_group.myterraformgroup.name
  network_interface_ids = [azurerm_network_interface.myterraformnic.id]
  size                  = "Standard_D2s_v3"
  custom_data           = base64encode(data.template_file.ud.rendered)


  identity {
    type         = "SystemAssigned"
    ##identity_ids = [azurerm_user_assigned_identity.example.id]
  }

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  computer_name                   = "myvm"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.example_ssh.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
  }

  tags = {
    environment = var.env
    owner       = var.user
  }
}

## Auto-Shutdown VM 
resource "azurerm_dev_test_global_vm_shutdown_schedule" "sixpm" {
  virtual_machine_id = azurerm_linux_virtual_machine.myterraformvm.id
  location           = "eastus"
  enabled            = true

  daily_recurrence_time = "1800"
  timezone              = "Eastern Standard Time"

  notification_settings {
    enabled         = true
    time_in_minutes = "60"
    email           = var.as_email
  }
}

## Assign AAD permissions to Data Analytics Group
data "azurerm_role_definition" "AdminLogin" {
  name = "Virtual Machine Administrator Login"
}

data "azuread_group" "read_group" {
  display_name = "your security group to have login access"
}

resource "azurerm_role_assignment" "example" {
  scope              = azurerm_linux_virtual_machine.myterraformvm.id
  role_definition_id = "${data.azurerm_resource_group.myterraformgroup.id}${data.azurerm_role_definition.AdminLogin.id}"
  principal_id       = data.azuread_group.hbb-da-sg.id
}

resource "azurerm_virtual_machine_extension" "aad" {
  name                       = "aad-${azurerm_linux_virtual_machine.myterraformvm.name}"
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADSSHLoginForLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_linux_virtual_machine.myterraformvm.id


  tags = {
    environment = var.env
    owner       = var.user
  }

}

## Create Key Vault access policy and assign Analytics Group Permissions to the key vault

data "azurerm_key_vault" "KeyVaultDev" {
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name
  name                = "your keyvault name"
}


output "var2" {
  value = join("",azurerm_linux_virtual_machine.myterraformvm.identity.*.principal_id)
}

resource "azurerm_key_vault_access_policy" "vm_policy" {
  key_vault_id = data.azurerm_key_vault.hbbDAKeyVaultDev.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = join("",azurerm_linux_virtual_machine.myterraformvm.identity.*.principal_id)

  key_permissions = [
    "Get",
  ]

  secret_permissions = [
    "Get",
  ]
}