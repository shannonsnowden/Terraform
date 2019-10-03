# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "ssterraformgroup" {
    name     = "ssTFRG"
    location = "eastus"

    tags = {
        environment = "Zerto Terraform Demo"
    }
}
# Create virtual network
resource "azurerm_virtual_network" "ssterraformnetwork" {
    name                = "ssVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.ssterraformgroup.name}"

    tags = {
        environment = "SS Terraform Demo"
    }
}
# Create subnet
resource "azurerm_subnet" "ssterraformsubnet" {
    name                 = "ssSubnet"
    resource_group_name  = "${azurerm_resource_group.ssterraformgroup.name}"
    virtual_network_name = "${azurerm_virtual_network.ssterraformnetwork.name}"
    address_prefix       = "10.0.2.0/24"
}
# Create public IPs
resource "azurerm_public_ip" "ssterraformpublicip" {
    name                 = "myPublicIP"
    location             = "eastus"
    resource_group_name  = "${azurerm_resource_group.ssterraformgroup.name}"
    allocation_method    = "Dynamic"

    tags = {
        environment = "SS Terraform Demo"
    }
}
# Create Network Security Group and rules
resource "azurerm_network_security_group" "ssterraformnsg" {
    name                = "ssNetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.ssterraformgroup.name}"
    
    security_rule {
        name                       = "RDP"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3389"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "SS Terraform Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "ssterraformnic" {
    name                = "myNIC"
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.ssterraformgroup.name}"
    network_security_group_id = "${azurerm_network_security_group.ssterraformnsg.id}"

    ip_configuration {
        name                          = "ssNicConfiguration"
        subnet_id                     = "${azurerm_subnet.ssterraformsubnet.id}"
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.ssterraformpublicip.id}"
    }

    tags = {
        environment = "SS Terraform Demo"
    }
}
# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.ssterraformgroup.name}"
    }
    
    byte_length = 8
}
# Create storage account for boot diagnostics
resource "azurerm_storage_account" "ssstorageaccount" {
    name                = "diag${random_id.randomId.hex}"
    resource_group_name = "${azurerm_resource_group.ssterraformgroup.name}"
    location            = "eastus"
    account_replication_type = "LRS"
    account_tier = "Standard"

    tags = {
        environment = "SS Terraform Demo"
    }
}
# Create virtual machine
provider "azurerm" {
    version = "~> 1.34.0"
}
resource "azurerm_virtual_machine" "ssterraformvm" {
    name                  = "ssmyVM"
    location              = "eastus"
    resource_group_name   = "${azurerm_resource_group.ssterraformgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.ssterraformnic.id}"]
    vm_size               = "Standard_DS3_v2"
  
    storage_os_disk {
        name              = "ssOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "zerto"
        offer     = "zerto-vms"
        sku       = "zerto7"
        version   = "7.0.0"
        }

    os_profile {
        computer_name  = "sstfvm"
        admin_username = "zerto"
        admin_password = "Password123#"
    }

    os_profile_windows_config {
        provision_vm_agent = true
    }

       boot_diagnostics {
        enabled     = "true"
        storage_uri = "${azurerm_storage_account.ssstorageaccount.primary_blob_endpoint}"
    }

    tags = {
        environment = "SS Terraform Demo"
    }
}