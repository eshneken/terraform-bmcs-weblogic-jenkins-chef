# Disable Firewall
firewall 'default' do
	action :disable
end

# set docker registry from attributes and assign container name
docker_registry = node['docker_registry_ip_and_port']
container_name = docker_registry + "/weblogic-1221"

# Start Docker
docker_service 'default' do
	action [:create, :start]
	tls false
	# insecure_registry '129.213.60.3:5000'
    insecure_registry docker_registry
end

# Pull tagged image
# docker_image '129.213.60.3:5000/weblogic-1221' do
docker_image container_name do
	tag 'latest'
	action :pull
end

# Run container
docker_container 'weblogic' do
	# repo '129.213.60.3:5000/weblogic-1221'
    repo container_name
	tag 'latest'
	port '7001:7001'
	action :run
end
