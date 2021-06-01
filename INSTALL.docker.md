# Installation


This document helps you to install the app on an Amazon 2 linux instance as a connected set of three docker containers:

* django
* mysql
* simple flask app to call R/bioconductor

## Start a new Amazon linux 2 instance

Launch a new instance with these settings:

* (Step 1) AMI: pick the most recent Amazon Linux 2 AMI [Amazon Linux 2 AMI (HVM), SSD Volume Type x86]
* (Step 2) Instance Types:
    * t3a.2xlarge (32 GB RAM, 8vCPUs, $0.30/hr) [or t3 for an extra 10% cost]  
    * t3a.xlarge (16 GB RAM, 4vCPUs, $0.15/hr) [or t3 for an extra 10% cost]
* (Step 3) Instance details: use defaults, or adjust as needed
* (Step 4) Storage: increase root volume to 30 GB, add EBS volume of 50-80 GB. Use gp2, or 
can use provisioned for better performance on the EBS volume. Note the device mount location (eg. /dev/sdb)
* (Step 5) Tags: up to you
* (Step 6) Security Groups: configure as needed for your networking needs
* (Review)
* (Launch): Pick your key

### Domain name / networking

You also need to figure out how to configure the domain name.  I don't currently 
have the docker containers configured for using https certificates, so if you want https, then the ELB 
option below is how I currently do it. Some choices are:

* use current IP address (this is http only and changes every time instance reboots)
* assign a fixed IP address and use AWS Route 53 to setup DNS to use that fixed IP (http only).
* use AWS ELB to accept requests and connect to this instance. This option enables you to use a certificate and
configure https. I can provide more detailed steps for using this option.

## Configure the new instance

The new instance needs docker and git to be installed.

    # connect to your running instance
    ssh -i mykey.pem ec2-user@1.2.3.4

    # apply updates
    sudo yum update -y

    # install docker
    sudo amazon-linux-extras install -y docker
    
    # install git
    sudo amazon-linux-extras install -y git
    
    # give ec2-user permission to start/stop docker containers
    sudo usermod -a -G docker ec2-user

    # run docker as a service (may need to figure out how to have this run when VM starts up)
    sudo service docker start
    
    # log out and log in to get group perm, then next command should not be an error
    exit
    ssh -i mykey.pem ec2-user@1.2.3.4
    docker info   # this should now work with no errors
    
    # install docker compose
    # visit this site to get most recent version: https://docs.docker.com/compose/install/
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # confirm this works, displays version
    docker-compose --version

## mount the EBS volume

I like to put all the app specific code and data on a separate EBS volume so that I can detach and increase the size, 
attach to another instance, make snapshots for backups, etc. Also, if you want things to go faster, you can pay more
for a faster EBS.

    # Make sure this symbolic link [get the real /dev/... name from the EC2 console]
    file -s /dev/sdb

    # Make the filesystem on that disk [this is destructive]
    sudo mkfs -t ext4 /dev/sdb

    # mount the formatted volume to this instance at: /mnt/atlas
    sudo mkdir /mnt/atlas
    sudo mount /dev/sdb /mnt/atlas
    
    # confirm the disk is mounted and has right amount of space
    lsblk
    df -h
    
    # add mount command to /etc/fstab so it is mounted when instance starts up next time
    grep atlas /etc/mtab  # just make sure this shows the line you want to add to /etc/fstab
    sudo sh -c 'grep atlas /etc/mtab >> /etc/fstab'
    tail /etc/fstab  # confirm it is there

    # make the EFS volume mount point owner by the non-root user
    sudo chown ec2-user:ec2-user /mnt/atlas

## Clone the exprdb repository from bitbucket

    # You need a read only key to access the bitbucket.org/bandrewfox/exprdb repo.
    # generate a private/public key on this instance and save it into the default location
    ssh-keygen
    cat ~/.ssh/id_rsa.pub
    # email the contents of the public key file to the bitbucket repo owner (Brian)
    # so that he can add the key: https://bitbucket.org/bandrewfox/exprdb/admin/access-keys/

    # Now you can clone the repo:
    cd /mnt/atlas
    git clone git@bitbucket.org:bandrewfox/exprdb.git
    
## Prepare the site specific configuration

The last step in this code chunk is where you'll make the configuration settings for your app. You may want
to put it under version control to your own private repo. Just make sure users can't see this file since
it has passwords.

    # make sure you're in the starting directory
    cd /mnt/atlas

    # make symbolic link to the docker-compose configuration
    ln -s exprdb/conf/docker/docker-compose-env.yml .

    # make a copy of the docker-compose template with ENV variables
    cp exprdb/conf/docker/template.env ./atlas.env

    # make a symbolic link from template to ".env" which is where docker-compose expects it
    ln -s atlas.env .env
    
    # edit the docker-compose env file (see notes in file for instructions)
    vi atlas.env


## Start the app

The first time building the images takes an hour-ish because installing all the R and bioconductor packages is 
slow. I could build and deploy that image on docker hub, but I haven't done that before so it will take some effort.
You only need to do a full build of that image once, so I haven't gone through the effort yet.

    # If you have just rebooted the instance, then run docker service again
    sudo service docker start

    # go to the starting directory
    cd /mnt/atlas

    # this will read .env, build and start the 3 containers (detached mode)
    docker-compose -f docker-compose-env.yml up -d --build
    

## Connect to app via web browser

For this step, you need to get address of the instance and go to:

http://1.2.3.4/browse

The /browse is required. You can do something on the networking side to redirect 
"/" requests to "/browse".


## [DO NOT RUN - this is automatic now] First time usage of the app to build the mysql tables:
    
    # create the mysql tables
    # docker-compose -f docker-compose-env.yml exec djangoapp python manage.py migrate
    
    # create the superuser (so you can log in and make accounts)
    # docker-compose -f docker-compose-env.yml exec djangoapp python manage.py createsuperuser

## Add data to app

Log in to the account on the demo atlas in order to grab the API token from the settings page. Then go to
the settings page on your new app and click the "remote connections" link. Add the demo server and the key.

### Add feature info

From your app, browse the datasets on the demo server and download the uniprot human and mouse sessions.
On your new app, open those sessions and in the "Load Data" section, select "feature_info.txt"


### Add expression datasets
    
From your app, browse the data on the demo server and find the sessions you would like to add to your app.
On your new app, open those sessions and load the data from the "Load Data" section. Currently, large datasets
like TCGA and single cell ones are too big, and so I need to fix the approach I use.


## Maintenance


### backups

You should backup the EBS volume via snapshots after you add new datasets or perform and calculations.

### Update with new version of code

    # go to the code directory
    cd /mnt/atlas/exprdb
    
    # pull new code
    git pull
    
    # stop then start the docker container
    docker-compose -f docker-compose-env.yml down
    docker-compose -f docker-compose-env.yml up -d --build


### After you download/start/stop many images with docker, the root disk starts filling

    # in case your disk starts filling with un-needed docker chunks
    docker rmi `docker images | grep none | awk '{print $3}'`
    
### To increase the size of the data volume

Steps:
* make a snapshot in ec2 console
* increase volume size in ec2 console
* lsblk to confirm the volume is larger than 'df -h' says
* sudo resize2fs /dev/nvme1n1

### to peek inside the running containers
    # check if mysql command was sent and configured:
    # docker exec atlas_djangoapp_1 mysql -u root -prootpass -h atlas_db_1 -D django -e 'SHOW VARIABLES LIKE "max_allowed_packet";'

### to run tests

    # run tests (after starting the app as above)
    # docker exec atlas_djangoapp_1 python manage.py test

