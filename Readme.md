# Infrastructure-as-Code (IaC) with Jenkins, Terraform, Chef, and Weblogic on Oracle Bare Metal Cloud (BMCS)
Ed Shnekendorf, Cloud Platform Architect, Oracle

## Overview
This repository provides the code used to demonstrate IaC concepts using Oracle Cloud, Jenkins, Terraform, and Chef.

To demonstrate, the user needs to set up a Jenkins server (either in Oracle Cloud or on-premises) to act as an orchestrator, a private docker registry (ideally running in BMCS and potentially on the same compute instance as the Jenkins server), and to have a [Hosted Chef](https://chef.io/) account to which the included cookbooks can be uploaded.

The demo flow consists of going to the Jenkins console and triggering an environment deployment.  Doing this will prompt the user to enter 4 parameters:

* An **Environment Identifier** which acts as a unique designator and allows multiple deployments to occur in parallel (e.g. DEV, TEST, SPRINT_5, FEATURE_XYZ, etc)
* A **Region** which defines which BMCS region is the target
* An **Availability Domain** which designates which AD of the selected region the infrastructure is deployed to
* A **Docker Application Tag** which designates which docker image is in the docker repo that should be installed

Upon starting the pipeline, Jenkins will pull all of the IaC assets from GitHub (demonstrating a key aspect of infrastructure as code) and kick off a Terraform process to create a virtual cloud network (VCN) with associated subnet, security list, internet gateway, and routing tables.  Terraform will also provision a compute instance and then trigger a call the hosted Chef server to configure the instance.  Chef will install Docker on the target instance and then pull a Weblogic 12.2.1.2 image from the private Docker registry and install and run it on the compute instance.  The end-result is a fresh software-defined environment provisioned and running Weblogic in a completely automated fashion in about 5 minutes.

Jenkins also exposes a destruction pipeline which can be called (using the same Environment Identifier) to destroy the infrastructure.  Calling this flow will remove the compute instance and the software-defined network that was created.  This is accomplished (with concurrency) but leveraging BMCS object storage (behind the scenes) to manage multiple Terraform state files based on the unique identifier.

It is helpful to understand Terraform before modifying this code for your own purposes.  A great resource that I used to learn was this [excellent book](http://www.terraformupandrunning.com/) by Jim Brikman.  It is also important to understand Chef and a great resource is working through the 'Getting Started' and 'Infrastructure Automation' modules of the [Learn Chef Rally](https://learn.chef.io/).

## Project Organization
This project is organized with three independant but related subdirectories.  

The **terraform** directory contains all of Terraform assets.  It has a **userdata** sub-folder which needs to be populated on the user's machine with a number of key files as described in the readme.txt file in that folder.

The **chef** directory contains the chef root directory and the cookbook used in this example.  Before running the demo, the user will need to have the Chef-DK set up on their machine (simply to facilitate uploading the cookbook to their Chef instance using knife).  The **knife.rb** file will need to be modified to point to the appropriate hosted Chef instance.

The **jenkins** directory contains the groovy domain specific language (GDSL) scripts that define the Jenkins pipelines for environment creation and destruction.  The GitHub location of these scripts is used directly in the Jenkins job config (also demonstrating IaC concepts).

## Environment Setup
First, make sure that you have an Oracle BMCS account and know all the important things like tenancy OCID, compartment OCID, User OCID, User fingerprint, etc.  

Next, make sure you have visited [Hosted Chef](https://chef.io) and create an account for yourself with an organization.  Alternatively, you can always use a Chef instance that you set up on a local server but this seems silly given the ease of using the hosted version.  

After that, make sure that you've installed the Chef development kit on your local machine by following [these instructions](https://docs.chef.io/install_dk.html).

Finally, you probably want to fork this repository since you'll want to make changes in GitHub for your own environment.  Because we're demonstrating IaC principles, Jenkins pulls from a Git repo so you will actually need to make changes in Git to point to your own stuff to make things work

### Install a Jenkins Server and Private Docker Registry
I recommend doing this in BMCS (after all, why not?) so create a VCN, make sure your security list allows 8080 (default Jenkins port) & 5000 (docker registry port), and create a compute instance.  Log into that instance and make sure to disable the local firewall; here are the sample commands for OEL/RHEL/CentOS 7:

```css
sudo service firewalld stop
sudo systemctl disable firewalld
```

Now, SSH into your new instance and do the following:

#### Install Jenkins
```css
wget -O bitnami-jenkins-linux-installer.run https://bitnami.com/stack/jenkins/download_latest/linux-x64
chmod 755 bitnami-jenkins-linux-installer.run
./bitnami-jenkins-linux-installer.run
```

#### Install Private Docker Registry
First, install the Docker binaries on this instance:
```css
curl -sSL https://get.docker.com/ | sh
sudo usermod -aG docker opc
```

Then, create a **/etc/docker/daemon.json** file and add the following config:
```css
{ "insecure-registries":["REGISTRY_IP:5000"] }
```
where **REGISTRY_IP** is replaced with the **public ip address** of the instance you're connected to.  Then, execute the following commans to complete the installation:
```css
sudo systemctl enable docker
sudo systemctl start docker
sudo docker run -d -p 5000:5000 --restart=always --name registry registry:2
```

#### Copy Terraform userdata to the Jenkins build server
Once you've populated your local contents of the **/terraform/userdata** directory with the correct files (and correct file permissions for keys) based on the contents of **readme.txt** you will need to move them up to your Jenkins build server.  Here is a sample of how I did it:
```css
scp -r -i ~/Keys/eshneken-opc userdata opc@129.213.60.3:/home/opc
```

#### Install Terraform & BMCS Provider
Install Terraform binary and BMCS provider by following the [instructions here](https://github.com/oracle/terraform-provider-baremetal).  Make sure to put the Terraform binaries in the OPC user home directory.

#### Install BMCS Command Line Interface (CLI)
Install the BMCS CLI by following the [instructions here](https://docs.us-phoenix-1.oraclecloud.com/Content/API/SDKDocs/cli.htm).  Make sure to put the BMCS provider plugin in the OPC user home directory.

### Populate the Docker Registry
Now that you have a private registry configured in the cloud, you want to put an image into it that can be pulled by Chef during environment configuration.  In a real workflow this can be pushed as part of a CI/CD flow but for this sample we assumed a base Weblogic 12.2.1.2 image pulled from the Docker Store.

First, navigate to the [Docker Store](https://store.docker.com) in your favorite browser, get the official Weblogic image, and accept all the license conditions.  

Then, execute the following in your local Docker environment (which should be tied to your DockerHub account thereby enabling you to access items you've regisatered for in the Docker Store):

```css
docker pull store/oracle/weblogic:12.2.1.2
docker tag  store/oracle/weblogic:12.2.1.2 REGISTRY_IP:5000/weblogic-1221
docker push REGISTRY_IP:5000/weblogic-1221
docker image rm REGISTRY_IP:5000/weblogic-1221
docker image rm store/oracle/weblogic:12.2.1.2
```
where **REGISTRY_IP** is replaced with the **public ip address** of the instance on which you've set up the Docker Registry.

### Upload Cookbooks to Chef
Make sure that **/chef/.chef/knife.rb** has correct config for your environment and that it matches the Chef config in the **/terraform/jenkins.tfvars** file.

From the **/chef** directory type 
```css
knife cookbook list
```
to make sure you don't get any errors back.  Once you have a clean result then run the following to upload your cookbook:
```css
knife upload cookbooks/bmcs_servers
```
You will also need to upload all the cookbook dependencies by using Chef's package manager (berks) by doing the following:
```css
cd cookbooks/bmcs_servers
berks install
berks upload
```

### Configure Jenkins Build Pipelines
Start by logging into your Jenkins server (http://<PUBLIC_IP>:8080/jenkins).

#### Configure Credentials
First, set up a credential in the credential store that points to your GitHub account.  Do this by navigating to **Credentials->Jenkins->Global Credentials->Add Credentials** and add a **Username with Password** credential.  Remember, you should have forked my GitHub project so that you can make the appropriate changes in your GDSL files.

#### Update Config Files and Push to GitHub
Open the **/jenkins/*.gdsl** files and set the **git credentialsId** block to point to your GitHub account.  Also, update all the lines with a **bmcs** CLI call to reference the tenancy name you're using (-ns) and the compartment you have access to (--compartment-id)

Also, open **/terraform/jenkins.tfvars** and update all the settings to be relevant for your environment,

Once you are done with these tasks, commit the changes and push to your hosted git account (GitHub, Bitbucket, Whatevs...)

#### Create Build Job
Do the following to create the build job:

* From dashboard click **New Item**, select **Pipeline**, and give it a name like **Docker-Build_Environment**
* Click **This Project is Parameterized** and add the following params:
    * Environment_Identifier, string parameter
    * Region, choice parameter, [us-ashburn-1, us-phoenix-1]
    * Availability_Domain, choice parameter, [1,2,3]
    * Docker_Application_Tag, string parameter, default=wls_sample_app
* Under **Pipeline** select **Pipeline script from SCM** 
* Point the **Repository URL** to your GitHub project (e.g. https://github.com/your_handle/terraform-bmcs-weblogic-jenkins-chef.git) and select the **credentials** you configured from the dropdown
* For the **Script Path**, type:  jenkins/docker_buildpipeline.gdsl
* Click **Save**

#### Create Destroy Job
Do the following to create the destroy job:

* From dashboard click **New Item**, select **Pipeline**, and give it a name like **Docker-Destroy_Environment**
* Click **This Project is Parameterized** and add the following params:
    * Environment_Identifier, string parameter
* Under **Pipeline** select **Pipeline script from SCM** 
* Point the **Repository URL** to your GitHub project (e.g. https://github.com/your_handle/terraform-bmcs-weblogic-jenkins-chef.git) and select the **credentials** you configured from the dropdown
* For the **Script Path**, type:  jenkins/docker_destroypipeline.gdsl
* Click **Save**

## Running The Demo
You should now be able to kick off create and destroy jobs from Jenkins.  As long as you use the same **Environment Identifier** for both things should work since the pipelines store the Terraform state file (terraform.tfstate) in a bucket (in object storage) named for the identifier.

After the build completes, you should have a running Weblogic server with a base domain configured.  The admin server runs on port **7001** and the password for the **weblogic** user is autogenerated.  To get the password, SSH into the instance that Terraform/Chef configured and execute the following code:

```css
sudo docker ps
sudo docker logs <ID of Weblogic Container> |grep password
```