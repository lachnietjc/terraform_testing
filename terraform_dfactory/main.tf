# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.0"
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


# Get info from existing rg
data "azurerm_resource_group" "myterraformgroup" {
  name = "your resource group name"
}

# Get info from existing datafactory 
data "azurerm_data_factory" "myterraformdf" {
	name = "your data factory name"
	resource_group_name = data.azurerm_resource_group.myterraformgroup.name
}

# input linked service
data "azurerm_data_factory_linked_service_sql_server" "mytformls_in" {
	name = "your existing linked service name for source"
	data_factory_id = data.azurerm_data_factory.myterraformdf.id
}

# output linked service
data "azurerm_data_factory_linked_service_sql_server" "mytformls_out" {
	name = "your existing linked service name for desination"
	data_factory_id = data.azurerm_data_factory.myterraformdf.id
}

# input dataset
resource "azurerm_data_factory_dataset_sql_server_table" "dataset_in" {
  name                = "name for input dataset"
  data_factory_id     = data.azurerm_data_factory.myterraformdf.id
  linked_service_name = data.azurerm_data_factory_linked_service_sql_server.mytformls_out.name
}

# output dataset 
resource "azurerm_data_factory_dataset_sql_server_table" "dataset_out" {
  name                = "name for output dataset"
  data_factory_id     = data.azurerm_data_factory.myterraformdf.id
  linked_service_name = data.azurerm_data_factory_linked_service_sql_server.mytformls_in.name
}

resource "azurerm_data_factory_pipeline" "pipeline_name" {
  name = "pipeline name here"
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name
  data_factory_id = data.azurerm_data_factory.myterraformdf.id
  table_name = var.destination
  
  variables = {
    "view_sql":file(var.view_sql_location),
    "delete_sql":file(var.view_delete),
	"pipeline_var":var.pipeline_name,
    "destination_var":var.destination, 
	"output_var": azurerm_data_factory_dataset_sql_server_table.dataset_out.name
	"input_var": azurerm_data_factory_dataset_sql_server_table.dataset_in.name
  }

  activities_json = <<JSON
  [{
	"name": "pipeline_var",
	"properties": {
		"activities": [
			{
				"name": "pipeline_var",
				"type": "Copy",
				"dependsOn": [],
				"policy": {
					"timeout": "7.00:00:00",
					"retry": 0,
					"retryIntervalInSeconds": 30,
					"secureOutput": false,
					"secureInput": false
				},
				"userProperties": [
					{
						"name": "Source",
						"value": "."
					},
					{
						"name": "Destination",
						"value": "destination_var"
					}
				],
				"typeProperties": {
					"source": {
						"type": "SqlServerSource",
						"sqlReaderQuery": "view_sql",
						"partitionOption": "None"
					},
					"sink": {
						"type": "SqlServerSink",
            			"preCopyScript" : "delete_sql",
            			"tableOption" : "autoCreate"  
					},
					"enableStaging": false,
					"validateDataConsistency": false
				},
				"inputs": [
					{
						"referenceName": "input_var",
						"type": "DatasetReference"
					}
				],
				"outputs": [
					{
						"referenceName": "output_var",
						"type": "DatasetReference"
					}
				]
			}
		],
		"annotations": []
	},
	"type": "Microsoft.DataFactory/factories/pipelines"
}]
  JSON
}






