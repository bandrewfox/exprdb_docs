# Installation

## Configure and Install Amazon Linux 2, RDS, attach an EBS volume

### EC2

* Amazon Linux 2 (HVM)
* AMI ID: amzn2-ami-hvm-2.0.20200406.0-x86_64-gp2 (ami-0d6621c01e8c2de2c)
* Launch a new Amazon Linux 2 instance (small disk, t2.large)
* Create an EBS volume and Attach it (~30 GB)

### Elastic IP

* Allocate an elastic IP, eg 1.2.3.4
* Use Route 53 to create a new A record: geneatlas.needlegenomics.com and 1.2.3.4
* Associate the launched instance with the new Elastic IP 1.2.3.4
* add elastic IP in inbound connections in the ec2 security group

### RDS on Amazon

Start an RDS instance with Aurora Serverless

* server name=needle-sonoma-db, user=atlas, pw=xxxx
* create database: exprdb
* endpoint: (get from RDS page)
* add the ec2 instance (internal IP) to the RDS security group so that the ec2 instance can access the RDS

### Do most of the actions which require sudo


    sudo yum update
    sudo yum groupinstall "Development Tools"
    sudo yum install python-pip
    sudo yum install mysql
    sudo yum install mysql-devel
    sudo yum install mysql-python
    sudo amazon-linux-extras install R3.4
	sudo yum install httpd
	sudo yum install mod_wsgi
    sudo yum install curl-devel
    sudo yum install libxml2-devel
    
This enables apache to start on boot

	sudo systemctl enable httpd.service
	# start supervisor and apache
	sudo service httpd start

Mount the EBS volume (check ec2 for volume, could be /dev/xvdf or /dev/sdf)

    sudo file -s /dev/xvdf
    sudo mkfs -t ext4 /dev/xvdf
    sudo mkdir /mnt/data
    sudo mount /dev/xvdf /mnt/data/
    sudo sh -c 'grep xvdf /etc/mtab >> /etc/fstab'

Make the django directories on /mnt/data

    sudo mkdir /mnt/data/dj_static
    sudo mkdir /mnt/data/dj_sessions
    sudo mkdir /mnt/data/dj_logs
    sudo mkdir /mnt/data/dj_media
	sudo mkdir /mnt/data/dj_media/tmp_debug
	sudo mkdir /mnt/data/dj_media/rplots_tmp
	sudo mkdir /mnt/data/dj_media/tmp_sessions
	
    sudo chown atlas:atlas -R /mnt/data/*
    sudo chmod a+rwx -R /mnt/data/*
    
    # link to the /var/html dir
    #sudo ln -s /mnt/data/dj_media/ /var/www/html/media
    #sudo ln -s /mnt/data/dj_static/ /var/www/html/static

#### Make user "atlas"

    # add user named atlas
    sudo adduser atlas

    # set the atlas password to something you'll remember so you can become user atlas with 'su - atlas'
    sudo passwd atlas

    # Prevent user 'atlas' from logging in via ssh by adding these lines to /etc/ssh/sshd_config
    sudo sh -c 'echo "DenyUsers atlas" >> /etc/ssh/sshd_config'

    echo "alias atlas='su - atlas'" >> ~/.bashrs

    # make .my.cnf
    [client]
    port = 3306
    host = needle-db.cluster-xxxxx.us-west-2.rds.amazonaws.com
    password = xxxxx
    user = atlas
    database = exprdb

### setup django user and db in mysql

    mysql -u atlas -pxxxxx mysql
    create user 'django'@'localhost' identified by 'django';
    create database exprdb;
    #grant all on exprdb.* to 'django'@'localhost';
    #grant all on exprdb.* to 'django'@'10.1.1.74';
    #flush privileges;
    exit
    mysql exprdb
    

#### Install R packages
	
	# log in as atlas:
	atlas

	# start R
	sudo R
	
	# install packages
	install.packages("httr")
	install.packages("ggplot2")
	install.packages("reshape2")
	
	# for gplots, it requires caTools where the newest version doesn't work for R 3.4
	# and caTools requires bitops
	install.packages("bitops")
	# wget https://cran.r-project.org/src/contrib/Archive/caTools/caTools_1.17.1.4.tar.gz
	# sudo R CMD INSTALL wget caTools_1.17.1.4.tar.gz
	install.packages("gplots")
	# for heatmaps with color legends:
    install.packages("png")
	install.packages("gridExtra")
	install.packages("gridGraphics")
	
	# bioconductor (older version)
	source("https://bioconductor.org/biocLite.R")
    biocLite("limma")
    biocLite("org.Hs.eg.db")
    biocLite("org.Mm.eg.db")
    biocLite("GEOquery")

### Clone the exprdb repository from bitbucket as user geneatlas

    # You need a read only key to access the bitbucket.org/bandrewfox/exprdb repo.
    # generate a private/public key and save it into the default location
    ssh-keygen
    cat  ~/.ssh/id_rsa.pub
    # email the contents of the public key file to the bitbucket repo owner (Brian)
    # so that he can add the key: https://bitbucket.org/bandrewfox/exprdb/admin/access-keys/
    # Now you can clone the repo:
    git clone git@bitbucket.org:bandrewfox/exprdb.git
    
    # or, if you are Brian and have password access to bitbucket, then do this:
	# git config --global user.name "geneatlas.redda"
	# git config --global credential.helper cache
	# git config --global credential.helper 'cache --timeout=3600000'
    # git clone https://bandrewfox@bitbucket.org/bandrewfox/exprdb.git
    
    # as user ec2-user
    sudo pip install -r ~atlas/exprdb/requirements.txt
    
    # if you want to process new uniprot, then you need Biopython
    sudo pip install Biopython

### Finish Configuring apache using sudo

	# as user ec2-user
	# Link the correct conf file to the apache conf.d location
	# (check if rewriteEngine is On and sending all http requests to https)
	sudo ln -s /home/atlas/exprdb/conf/amazon_linux_2/django.conf /etc/httpd/conf.d/django.conf
	chmod +x /home/atlas
	
### On AWS, configure ELB to use an SSL certificate

Follow these directions mostly, except add a step to use the new ELB security group
https://docs.bitnami.com/aws/how-to/configure-elb-ssl-aws/#step-4-modify-the-web-server-configuration-on-the-bitnami-application-instance

#### Set up the Elastic Load Balancer

* Click the "Create Load Balancer" Blue button in the EC2 Dashboard
* Choose "Application Load Balancer" type
* On the subsequent "Configure Load Balancer” page:
    * Enter a name
    * Choose "Internet facing" and ipv4
    * For "Listeners," ensure that there is an HTTP listener (port 80) and an HTTPS listener (port 443).
    * For "Availability Zones," use the same VPC as the app instance and select 2 subnets from its availability zone.
* On the "Configure Security Settings" page"
    * Request a new certificate from ACM if you don't already have one for *.needlegenomics.com
        * Enter domain names, eg. *.needlegenomics.com and needlegenomics.com
        * Select email verification, submit, check email, click link, come back to see if it says "issued."
    * Refresh the list of certificates and choose the new one
    * Pick the default security policy (ELBSecurityPolicy-2016-08)
* On the "Configure Security Group" page:
    * Create a new security group - called "LoadBal-myClient"
    * add inbound traffic from specific IPs or anywhere for HTTP and HTTPS
* On the "Configure Routing" page, setup the traffic between the ELB and instance to use HTTP, even for 
  HTTPS requests from the client:
    * Create a "New Target Group" with a new name, HTTP, port 80 and Target type of "instance"
    * In "health checks," use HTTP and "/"
* On the "Register Targets" page:
    * Find the instance to use for this ELB and move it up
* Review everything and submit
* Set Idle Timeout attribute to 3600 seconds ****

#### Route 53 DNS update

* Get the ELB DNS name from the EC2 dashboard, eg: needle-load-balancer-1234456.us-west-2.elb.amazonaws.com
* Go to Route 53, select the hosted zone, pick the subdomain you want
* Create/edit the A record and use "Alias" mode
* Paste the ELB DNS name in the "Alias Target" box, and "Save Record Set"

#### Add security group to ec2 instance

* Make a new security group
    * named: From-LoadBal-client1
    * inbound from other security group attached to ELB: LoadBal-client1
    * outbound to all
    * attach it to the instance specified in the Register Targets of the ELB config

#### Finish up

Add the new ELB security group to the running instance (can delete others, except still need one for ssh).
When you ssh to the instance, now you need to use the public IP instead of the domain name now. 
Make sure the apache conf has the rewrite rule here in order to redirect all traffic to HTTPS.

    RewriteEngine On
    RewriteCond %{HTTP:X-Forwarded-Proto} !https
    RewriteRule ^.*$ https://%{SERVER_NAME}%{REQUEST_URI}



#### Adjust some django settings for this instance

	# edit the settings file
	vi exprdb/settings.py

Here are the chunks to adjust:
1. add the AWS IP address to one of the IP specific configuration blocks, or make a new block.
2. Be sure to also add the web readable domain name in the ALLOWED_HOSTS line of that block
3. Adjust the database settings to match
	

#### See if django works

	# open a django python shell
	cd ~/myproj/exprdb/
	python manage.py shell
	
	# add the static assets to the /dj_static directory
	python manage.py collectstatic
	
	# build the database tables
	python myproj/exprdb/manage.py syncdb
	
	# create superuser
	python manage.py createsuperuser


### Make sure manage.py process_tasks is running
Use crontab to keep checking and starting "manage.py process_tasks".

    # make sure apache can read the access log in order for the ctron job to see if anyone has accessed 
    # website in past hour
    chmod a+rx /var/log/httpd/
    chmod a+r /var/log/httpd/access_log
    
    # Add this line to apache's crontab (must be apache so that session file permissions don't get hosed):
    # sudo crontab -u apache -e
    *  *  *  *  *   /home/atlas/exprdb/conf/amazon_linux_2/cron_tasks.sh  >/dev/null 2>&1


## Loading Features
After the 2019.11 release of uniprot, new "/note=" elements were added to the FT and CC records, which broke 
BioPython. So, I had to manually download an old release and rename it to raw_features.tar.gz and then
continue extracting the organism I wanted. I also had to manually edit the file size and md5sum.

## Docker

Eventually, I'd like to do this with docker.  Here are some helpful hints:

* https://www.caktusgroup.com/blog/2017/03/14/production-ready-dockerfile-your-python-django-app/
* https://confluence.atlassian.com/bitbucket/python-with-bitbucket-pipelines-873891271.html#PythonwithBitbucketPipelines-PyUnit
* https://datascienceunicorn.tumblr.com/post/182297983466/building-a-docker-to-run-python-r
* https://stackoverflow.com/questions/54239485/add-a-particular-version-of-r-to-a-docker-container
* https://hackernoon.com/running-docker-on-aws-ec2-83a14b780c56
* https://hub.docker.com/layers/python/library/python/2.7.18/images/sha256-bf3ab881bf19bb40497cf97172c95f98af50a556d4005d15c3f2ef983b38cae6?context=explore
* https://bioconda.github.io/contributor/faqs.html
* https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/create_deploy_dockerpreconfig.html
