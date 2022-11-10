terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.94.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "this" {
  name     = "this"
  location = "westeurope"
}

resource "azurerm_storage_account" "this" {
  name                = "storagearmanto"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
  allow_blob_public_access = true
 }
 resource "azurerm_storage_account" "alone" {
  name                = "alone"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
  allow_blob_public_access = true
 }
 
resource "azurerm_storage_data_lake_gen2_filesystem" "fs" {
  name               = "synapse"
  storage_account_id = azurerm_storage_account.this.id
  }

resource "azurerm_synapse_workspace" "synapse" {
  name                                 = "synapsearmanto19"
  resource_group_name                  = azurerm_resource_group.this.name
  location                             = azurerm_resource_group.this.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.fs.id
  sql_administrator_login              = "adminuser"
  sql_administrator_login_password     = "password1234!"
  managed_virtual_network_enabled      = true
  managed_resource_group_name          = "this-mng-synapse"
  public_network_access_enabled = true


 aad_admin {
    login     = "AzureAD Admin"
    object_id = var.object_id
    tenant_id = var.tenant_id
    }

    tags = {
    enviroment = "development"
    source     = "terraform"
    }
  }


resource "azurerm_synapse_firewall_rule" "this" {
  name = "AllowAll"
  synapse_workspace_id = azurerm_synapse_workspace.synapse.id
  start_ip_address = "108.142.221.96"
  end_ip_address = "108.142.221.96"
}

resource "azurerm_synapse_managed_private_endpoint" "this" {
  name                 = "this-endpoint"
  synapse_workspace_id = azurerm_synapse_workspace.synapse.id
  target_resource_id   = azurerm_storage_account.alone.id
  subresource_name    = "Blob"
  }
resource "azurerm_public_ip" "this" {
  name                = "acceptanceTestPublicIp1"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  ip_version = "IPv4"
  sku = "basic"
  sku_tier = "Regional"
  

  tags = {
    environment = "Production"
  }
}



resource "azurerm_virtual_network" "this" {
  name                = "this-network"
  address_space       = ["10.0.0.0/18"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_subnet" "this" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.2.0/24"]
}
resource "azurerm_network_security_group" "this" {
  name                = "acceptanceTestSecurityGroup1"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "92.110.67.155"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "this" {
  name                = "this-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  enable_ip_forwarding = true

  
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"

    
  }
}

resource "azurerm_windows_virtual_machine" "this" {
  name                = "armanto-machine"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = "Standard_D2s_v3"
  admin_username      = "adminuser"
  admin_password      = "Password1234!"
  network_interface_ids = [
    azurerm_network_interface.this.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}
resource "azurerm_private_endpoint" "this" {
  name                = "vm-to-storage-alone"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.this.id
  private_service_connection {
    name                           = "this-privateserviceconnection"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.alone.id
    subresource_names = ["blob"]
    }
  }
