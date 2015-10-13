cd 'C:\Program Files\WindowsPowerShell\Modules'

Import-Module coreos-hyperv

## Setup etcd cluster
$NetworkConfig = New-CoreosNetworkConfig -SwitchName 'Virtual Switch' -Gateway '10.9.8.1' -SubnetBits 24 -RangeStartIP '10.9.8.10' -DNSServers @('8.8.8.8', '8.8.4.4')

New-CoreosCluster -Name dev-coreos-etcd -Count 1 -NetworkConfigs $NetworkConfig -Channel Stable -Config .\coreos-hyperv\configs\etcd-cluster.yaml | Start-CoreosCluster

## Setup kubernetes cluster
$NetworkConfig = New-CoreosNetworkConfig -SwitchName 'Virtual Switch' -Gateway '10.9.8.1' -SubnetBits 24 -RangeStartIP '10.9.8.20' -DNSServers @('8.8.8.8', '8.8.4.4')

New-CoreosCluster -Name dev-coreos-k8s -Count 3 -NetworkConfigs $NetworkConfig -Channel Alpha -Release 773.1.0 -Config .\coreos-hyperv\configs\k8s-master.yaml | Start-CoreosCluster

#$cluster = Get-CoreosCluster -ClusterName coreos-basiccluster0
#$cluster | Remove-CoreosCluster
