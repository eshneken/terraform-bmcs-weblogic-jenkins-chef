This directory needs to be populated with local keyfiles:

1) docker_registry_ip_and_port.cfg:  single text string in the form of <ip_address>:<port> of private docker registry (e.g. "129.32.212.12:5000")
2) eshneken-bmcs.pem:  private key (.pem) for BMCS user
3) eshneken-chef-io.pem:  private key (.pem) for Chef.io user
4) eshneken-opc:  private key (RSA) for BMCS opc user
5) eshneken-opc.pub:  public key (RSA) corresponding to #4 private key file

Once the local directory has all of these, the userdata directory needs to be moved to the ~opc directory on the Jenkins buildserver.