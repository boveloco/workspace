output "ip_addresses" {
  value = {
    bastion = module.bastion.network_interfaces.network_interface_1.ip_configuration[0].private_ip_address
    etcd = [module.etcd.*.network_interfaces.network_interface_1.ip_configuration[*][0].private_ip_address]
    api-server = [module.api-server.*.network_interfaces.network_interface_1.ip_configuration[*][0].private_ip_address]
    workers = [module.worker.*.network_interfaces.network_interface_1.ip_configuration[*][0].private_ip_address]
    }
}