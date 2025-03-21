terraform {
  required_version = "~> 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.116, < 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# tflint-ignore: terraform_module_provider_declaration, terraform_output_separate, terraform_variable_separate
provider "azurerm" {
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

module "naming" {
  suffix  = ["k8sws"]
  source  = "Azure/naming/azurerm"
  version = "~> 0.4"
}

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.3.0"

  availability_zones_filter = true
}

locals {
  base_suffix       = "k8sws-${var.owner}"
  deployment_region = "swedencentral" #temporarily pinning on single region
  tags = {
    scenario    = "Default"
    environment = "nonProd"
    purpose     = "k8s-workshop-2025"
  }
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions_by_name) - 1
  min = 0
}

resource "random_integer" "zone_index" {
  max = length(module.regions.regions_by_name[local.deployment_region].zones)
  min = 1
}

resource "azurerm_resource_group" "this_rg" {
  name     = "kubernetes-workshop-${var.owner}"
  location = "swedencentral"
  tags = local.tags

}

module "natgateway" {
  source  = "Azure/avm-res-network-natgateway/azurerm"
  version = "0.2.1"

  name                = module.naming.nat_gateway.name_unique
  enable_telemetry    = false
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name

  public_ips = {
    public_ip_1 = {
      name = "nat_gw_pip1"
    }
  }
}

module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "=0.8.1"

  resource_group_name = azurerm_resource_group.this_rg.name
  address_space       = ["192.168.0.0/16"]
  name                = module.naming.virtual_network.name_unique
  location            = azurerm_resource_group.this_rg.location

  subnets = {
    vm_subnet_1 = {
      name             = "${module.naming.subnet.name_unique}-1"
      address_prefixes = ["192.168.1.0/24"]
      nat_gateway = {
        id = module.natgateway.resource_id
      }
    }
    vm_subnet_2 = {
      name             = "${module.naming.subnet.name_unique}-2"
      address_prefixes = ["192.168.2.0/24"]
      nat_gateway = {
        id = module.natgateway.resource_id
      }
    }
    vm_subnet_3 = {
      name             = "${module.naming.subnet.name_unique}-3"
      address_prefixes = ["192.168.3.0/24"]
      nat_gateway = {
        id = module.natgateway.resource_id
      }
    }
    AzureBastionSubnet = {
      name             = "AzureBastionSubnet"
      address_prefixes = ["192.168.4.0/24"]
    }
  }
}

resource "azurerm_public_ip" "bastionpip" {
  name                = module.naming.public_ip.name_unique
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-${local.base_suffix}"
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name

  ip_configuration {
    name                 = "${module.naming.bastion_host.name_unique}-ipconf"
    subnet_id            = module.vnet.subnets["AzureBastionSubnet"].resource_id
    public_ip_address_id = azurerm_public_ip.bastionpip.id
  }

  tags = local.tags
}

data "azurerm_client_config" "current" {}

module "bastion" {
  source = "Azure/avm-res-compute-virtualmachine/azurerm"

  enable_telemetry      = false
  location              = azurerm_resource_group.this_rg.location
  resource_group_name   = azurerm_resource_group.this_rg.name
  os_type               = "Linux"
  name                  = "bastion-${local.base_suffix}" # Unique name
  sku_size              = "Standard_B2ls_v2"
  zone                  = random_integer.zone_index.result
  

  admin_username        = var.admin_username
  admin_password        = var.admin_password
  admin_ssh_keys        = [{ username = var.admin_username, public_key = var.root_ssh_public_key }]

  encryption_at_host_enabled = false

  source_image_reference = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  network_interfaces = {
    network_interface_1 = {
      name = "bastion-${module.naming.network_interface.name_unique}" # Unique NIC name
      ip_configurations = {
        ip_configuration_1 = {
          name                        = "bastion-${module.naming.network_interface.name_unique}-ipconfig1"
          private_ip_subnet_resource_id = module.vnet.subnets["vm_subnet_1"].resource_id
        }
      }
    }
  }

  tags = local.tags
}

module "etcd" {
  source = "Azure/avm-res-compute-virtualmachine/azurerm"

  count = 3 # Spawn 3 instances

  enable_telemetry      = false
  location              = azurerm_resource_group.this_rg.location
  resource_group_name   = azurerm_resource_group.this_rg.name
  os_type               = "Linux"
  name                  = "etcd-${count.index + 1}-${local.base_suffix}" # Unique name
  sku_size              = "Standard_B2ls_v2"
  zone                  = random_integer.zone_index.result
  

  admin_username        = var.admin_username
  admin_password        = var.admin_password
  admin_ssh_keys        = [{ username = var.admin_username, public_key = var.root_ssh_public_key }]

  encryption_at_host_enabled = false

  source_image_reference = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  network_interfaces = {
    network_interface_1 = {
      name = "etcd-${module.naming.network_interface.name_unique}-${count.index + 1}" # Unique NIC name
      ip_configurations = {
        ip_configuration_1 = {
          name                        = "etcd-${module.naming.network_interface.name_unique}-${count.index + 1}-ipconfig1"
          private_ip_subnet_resource_id = module.vnet.subnets["vm_subnet_1"].resource_id
        }
      }
    }
  }

  tags = local.tags
}

module "api-server" {
  source = "Azure/avm-res-compute-virtualmachine/azurerm"

  count = 3 # Spawn 3 instances

  enable_telemetry      = false
  location              = azurerm_resource_group.this_rg.location
  resource_group_name   = azurerm_resource_group.this_rg.name
  os_type               = "Linux"
  name                  = "api-server-${count.index + 1}-${local.base_suffix}" 
  sku_size              = "Standard_B2ls_v2"
  zone                  = random_integer.zone_index.result

  admin_username        = var.admin_username
  admin_password        = var.admin_password
  admin_ssh_keys        = [{ username = var.admin_username, public_key = var.root_ssh_public_key }]

  encryption_at_host_enabled = false

  source_image_reference = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  network_interfaces = {
    network_interface_1 = {
      name = "api-${module.naming.network_interface.name_unique}-${count.index + 1}"
      ip_configurations = {
        ip_configuration_1 = {
          name                        = "api-${module.naming.network_interface.name_unique}-${count.index + 1}-ipconfig1"
          private_ip_subnet_resource_id = module.vnet.subnets["vm_subnet_1"].resource_id
        }
      }
    }
  }

  tags = local.tags
}

module "worker" {
  source = "Azure/avm-res-compute-virtualmachine/azurerm"

  count = 3 # Spawn 3 instances

  enable_telemetry      = false
  location              = azurerm_resource_group.this_rg.location
  resource_group_name   = azurerm_resource_group.this_rg.name
  os_type               = "Linux"
  name                  = "worker-${count.index + 1}-${local.base_suffix}" # Unique name
  sku_size              = "Standard_B2ls_v2"
  zone                  = random_integer.zone_index.result

  admin_username        = var.admin_username
  admin_password        = var.admin_password
  admin_ssh_keys        = [{ username = var.admin_username, public_key = var.root_ssh_public_key }]

  encryption_at_host_enabled = false

  source_image_reference = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  network_interfaces = {
    network_interface_1 = {
      name = "worker-${module.naming.network_interface.name_unique}-${count.index + 1}" # Unique NIC name
      ip_configurations = {
        ip_configuration_1 = {
          name                        = "worker-${module.naming.network_interface.name_unique}-${count.index + 1}-ipconfig1"
          private_ip_subnet_resource_id = module.vnet.subnets["vm_subnet_1"].resource_id
        }
      }
    }
  }

  tags = local.tags
}