from azure.identity import ClientSecretCredential 
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.datafactory import DataFactoryManagementClient
from azure.mgmt.datafactory.models import *
from datetime import datetime, timedelta
import sys
sys.path.append(".")
from app_funcs import *
import time
import os

def sql_to_pqt_blob_adf(project_name, out_file_name, out_file_container, 
                        sql_path, linked_service_name, storage_account_name, 
                        status_message_sleep_time, folder_path=None, tr_name=None): 
    
    with open(sql_path) as f:
        sql=f.read()
        
    client_id = "xxxxxxxx"
    tentant_id =  "xxxxxxxxx"
    client_secret = "xxxxxxxxx"
    
    
    # Azure subscription ID
    subscription_id = "subscription id here"

    # Creates this resource group. If it's an existing resource group, comment out the code that creates the resource group
    rg_name = 'rg that the df is in'

    # The data factory name. It must be globally unique.
    df_name = 'df name here'

    # Specify your Active Directory client ID, client secret, and tenant ID
    credentials = ClientSecretCredential(client_id=client_id, 
                                         client_secret=client_secret, 
                                         tenant_id=tentant_id) 


    resource_client = ResourceManagementClient(credentials, subscription_id)
    adf_client = DataFactoryManagementClient(credentials, subscription_id)


    # Data Factory setup 
    df_resource = Factory(location='eastus')
    df = adf_client.factories.create_or_update(rg_name, df_name, df_resource)
    print_item(df)
    while df.provisioning_state != 'Succeeded':
        df = adf_client.factories.get(rg_name, df_name)
        time.sleep(1)

    # input ls setup
    input_ls_name = linked_service_name
    input_ls = adf_client.linked_services.get(rg_name, df_name, input_ls_name)
    
    # output ls name 
    out_ls_name = storage_account_name
    out_ls = adf_client.linked_services.get(rg_name, df_name, out_ls_name)

    # create input dataset
    ds_input_name = f'{project_name}_input'
    ds_input_ls = LinkedServiceReference(reference_name=input_ls_name)
    ds_input_sql = DatasetResource(properties=SqlServerTableDataset(linked_service_name = ds_input_ls))

    ds_input = adf_client.datasets.create_or_update(rg_name, 
                                                    df_name, 
                                                    ds_input_name, 
                                                    ds_input_sql,)

    # create out dataset 
    ds_out_name = f'{project_name}_out'
    ds_out_ls = LinkedServiceReference(reference_name=out_ls_name)
    blob_path = out_file_container
    blob_filename = out_file_name
    pqt_props={'typeProperties':{
                    'location':{
                        'type':"AzureBlobStorageLocation",
                        'fileName':blob_filename,
                        'container':blob_path
                        }
                    }
                }
    if folder_path:
        pqt_props['typeProperties']['location']['folderPath']=folder_path
        
    ds_out_blob = DatasetResource(properties=ParquetDataset(linked_service_name=ds_out_ls, 
                                                            additional_properties=pqt_props,
                                                            compression_codec='snappy')
                                 )

    ds_input = adf_client.datasets.create_or_update(rg_name, 
                                                    df_name, 
                                                    ds_out_name, 
                                                    ds_out_blob)


    # create a pipeline
    act_name = f'Copy {project_name}'
    source = SqlServerSource(sql_reader_query=sql, partition_option=None)
    sink = ParquetSink(store_settings=AzureBlobStorageWriteSettings(),
                       format_settings=ParquetWriteSettings())
    dsin_ref = DatasetReference(reference_name=ds_input_name)
    dsout_ref = DatasetReference(reference_name=ds_out_name)
    copy_activity = CopyActivity(name=act_name, 
                                 inputs=[dsin_ref], 
                                 outputs=[dsout_ref], 
                                 source=source, 
                                 sink=sink)
    ParquetSink()


    p_name = f"{project_name}_pipe"
    params_for_pipeline={}

    p_obj = PipelineResource(activities=[copy_activity], parameters=params_for_pipeline)
    p = adf_client.pipelines.create_or_update(rg_name, 
                                              df_name, 
                                              p_name, 
                                              p_obj)
    print_item(p)

    run_response = adf_client.pipelines.create_run(rg_name,
                                                  df_name, 
                                                  p_name,
                                                  parameters={})


    # Monitor the pipeline run
    time.sleep(status_message_sleep_time)
    pipeline_run = adf_client.pipeline_runs.get(
        rg_name, df_name, run_response.run_id)
    print("\n\tPipeline run status: {}".format(pipeline_run.status))
    filter_params = RunFilterParameters(
        last_updated_after=datetime.now() - timedelta(1), last_updated_before=datetime.now() + timedelta(1))
    query_response = adf_client.activity_runs.query_by_pipeline_run(
        rg_name, df_name, pipeline_run.run_id, filter_params)
    print_activity_run_details(query_response.value[0])