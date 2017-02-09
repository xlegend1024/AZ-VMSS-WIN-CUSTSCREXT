param(
$ResourceGroupName,
$noVM=400,
$storageSKU='Standard_LRS',
$location = 'koreasouth',
#$imageuri='https://juleekoreasouth.blob.core.windows.net/vmimage/image.vhd',
#$imagekey='PRwy2N982rc4m3ZzF0LWv/Sp/Ik6Bp5WtEpPy6CY75XrIEhCLJdhybAPRprlgLbTEdZ8J3dL77yDTV/p3hq0VQ==',
#$imageSAresourcegroup='service-demo-korea',
$imageuri,
$imagekey,
$imageSAresourcegroup,
$vmsize='Standard_A2_v2',
$adminusername,
$adminpassword,
$vnetname,
$subnetname,
$vnetResourceGroup
)


$maxVMperSA=40
#$imageblobname='vmimage.vhd'

$numberofstorageaccount=[math]::Ceiling($noVM/$maxVMperSA)

$sas=@()
for($i=0;$i -lt $numberofstorageaccount;$i++){
    $sas+=(($ResourceGroupName.Tolower() -replace '._-()','') + (New-Guid).Guid.Replace('-','')).substring(0,23)
}

try{
get-job|remove-job -ErrorAction stop
}
catch{
write-host 'There are running jobs. Try to run "get-job|stop-job" and run again'
return
}

New-AzureRmResourceGroup -Name $ResourceGroupName -Location $location -Force

$tmpfile=New-TemporaryFile
Save-AzureRmProfile -Path $tmpfile.FullName -Force -verbose:$false

write-host (get-date)": Starting creating storage account and copying the images"


    $srcStorageAccount=(($imageuri.Split("/"))[2].split("."))[0]
    $srccontainer=$imageuri.Split("/")[3]
    $imageblobfullname=$imageuri.TrimStart("https://$srcStorageAccount.blob.core.windows.net/$srccontainer/")
    $imageblobname=$imageblobfullname.split("/")[-1]

$i=0

foreach($sa in $sas){

    Set-AzureRmCurrentStorageAccount -ResourceGroupName $imageSAresourcegroup -Name $srcStorageAccount|Out-Null
    $srcblob=Get-AzureStorageBlob -Container $srccontainer -Blob $imageblobname   

    Start-Job -ScriptBlock{

        param($resourcegroupname,$sa,$tmpfile,$storageSKU,$location,$srcblob,$imageuri,$imageSAresourcegroup)
            
        $dstcontainer='vmimage'

        write-host "running select-azurermprofile"
        Select-AzureRmProfile -Path $tmpfile.FullName  

        $srcStorageAccount=(($imageuri.Split("/"))[2].split("."))[0]
        $srccontainer=$imageuri.Split("/")[3]
        $imageblobfullname=$imageuri.TrimStart("https://$srcStorageAccount.blob.core.windows.net/$srccontainer/")
        $imageblobname=$imageblobfullname.split("/")[-1]

        Set-AzureRmCurrentStorageAccount -ResourceGroupName $imageSAresourcegroup -Name $srcStorageAccount|Out-Null
        $srcblob=Get-AzureStorageBlob -Container $srccontainer -Blob $imageblobfullname   
               
        write-host (get-date)": creating storage account $sa"
        do{
            try{
                $storageaccount=New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $sa -SkuName $storageSKU -Location $location -ErrorAction stop
                Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourcegroupname -Name $sa
                New-AzureStorageContainer -Name $dstcontainer
            }
            catch{
                write-host "catched: new-azurermstorageaccount"
                Start-Sleep -Seconds 60
                continue;
            }
            break;
        }while($true)
        

        write-host (get-date)": copying the image"
        do{
            try{
                write-host (get-date)": blob copy started!"
                Start-AzureStorageBlobCopy -CloudBlob $srcblob.ICloudBlob -DestContainer $dstcontainer -DestBlob $imageblobname -Force
                Get-AzureStorageBlobCopyState -Blob $imageblobname -Container $dstcontainer -WaitForComplete
                
                
            }
            catch{
                write-host "catched: start-azurestorageblobcopy"
                Start-Sleep -Seconds 60
                continue;
            }
            break;
        }while($true)

        write-host (get-date)": done copying the image"

        
    } -Arg $ResourceGroupName,$sa,$tmpfile,$storageSKU,$location,$srcblob,$imageuri,$imageSAresourcegroup|out-null
    Write-Progress -Activity "Creating Jobs for storage accounts" -PercentComplete (++$i/$sas.count*100)    

}


do{
$jobs=get-job
if($jobs.childjobs.jobstateinfo.state -eq 'Completed'){} #if there is only one job
else{start-sleep -Seconds 15;continue}
$pc=(($jobs.childjobs.jobstateinfo.state -eq 'Completed').count/$jobs.count)*100
write-progress -activity "Finishing creating Storage Accounts and copying the images" -percentcomplete $pc
start-sleep -seconds 15
if($pc -eq 100){break;}
}while($true)

<#
write-host (get-date)": creating vnet"

#$subnetname=$subnet
$subnetprefix='10.0.0.0/16'
$subnet = New-AzureRmVirtualNetworkSubnetConfig -Name $subnetname -AddressPrefix $subnetprefix

#$vnetname=$ResourceGroupName+"vnet"
$vnetprefix='10.0.0.0/8'
$vnet = New-AzureRmVirtualNetwork -Name $vnetname -ResourceGroupName $ResourceGroupName -Location $location -AddressPrefix $vnetprefix -Subnet $subnet
#>



get-job|remove-job
 $i=0

 write-host (get-date)": creating VMs"

 foreach($sa in $sas){

    $saname=Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $sa

    
    if($i -eq ($numberofstorageaccount-1)){
        $instanceCount=$noVM % $maxVMperSA
        if($instanceCount -eq 0) {$instanceCount =$maxVMperSA}
        $params = @{vmSSname="vmss$i";instanceCount=$instanceCount;vmSize=$vmsize;adminusername=$adminusername;adminPassword=$adminpassword;sourceImageVhdUri="https://$($saname.storageaccountname).blob.core.windows.net/vmimage/$imageblobname";vnetname=$vnetname;subnetname=$subnetname;vnetResourceGroup=$vnetResourceGroup}
    }
    else{
        $params = @{vmSSname="vmss$i";instanceCount=$maxVMperSA;vmSize=$vmsize;adminusername=$adminusername;adminPassword=$adminpassword;sourceImageVhdUri="https://$($saname.storageaccountname).blob.core.windows.net/vmimage/$imageblobname";vnetname=$vnetname;subnetname=$subnetname;vnetResourceGroup=$vnetResourceGroup}
    }
    
    
    Start-Job -ScriptBlock{

        param($sa, $ResourceGroupname, $params,$tmpfile)
            
        $VerbosePreference="Continue"

        write-host "running select-azurermprofile"
        Select-AzureRmProfile -Path $tmpfile.FullName  

        
        

        write-host (get-date)": Creating VMs"
        do{
            try{
                write-host $sa
                write-host $ResourceGroupname
                write-host $params.vnetname
                New-AzureRmResourceGroupDeployment -Name $sa -ResourceGroupName $ResourceGroupName `
                -TemplateUri https://raw.githubusercontent.com/xlegend1024/AZ-VMSS-WIN-CUSTSCREXT/master/lgeid.json `
                -Mode Incremental -Force -TemplateParameterObject $params -ErrorAction stop
                
            }
            catch{
                write-host "catched: new-azurermresourcegroupdeployment"
                Start-Sleep -Seconds 60
                continue;
            }
            break;
        }while($true)
        write-host (get-date)": done creating VMs"

    } -Arg $sa,$ResourceGroupName,$params,$tmpfile|out-null
    Write-Progress -Activity "Creating Jobs for VMs" -PercentComplete ((++$i)/$sas.count*100)    

}
do{
$jobs=get-job
if($jobs.childjobs.jobstateinfo.state -eq 'Completed'){} #if there is only one job
else{start-sleep -Seconds 15;continue}
$pc=(($jobs.childjobs.jobstateinfo.state -eq 'Completed').count/$jobs.count)*100
write-progress -activity "Finishing creating VMs" -percentcomplete $pc
start-sleep -seconds 15
if($pc -eq 100){break;}
}while($true)


write-host (get-date)": finished creating all VMs"



Remove-Item -Path $tmpfile.FullName -Force
