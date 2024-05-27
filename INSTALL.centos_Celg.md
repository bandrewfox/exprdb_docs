# Installation

## Background

An instance with CentOS 7 was provided at Celgene. Here are some of the specific features/notes for what had to be done at the admin/root level before I had access:

* user accounts: all users with corporate passwords via Active Directory (AD).
* sudo is highly restricted, so these docs don't require it.
* Except, add to /etc/sudoers the ability to start and stop apache for the user (assuming user bfox in the docs below).
* user 'geneatlas' with home: /usr/local/geneatlas
* user 'geneatlas' owner of: /var/www and /etc/httpd/conf*
* user 'geneatlas' can access: /var/log/httpd
* SELinux is disabled

### bfox user setup, personal preferences:

    # in ~bfox/.bashrc
    echo "alias atlas='sudo su - geneatlas'" >> ~/.bashrc

    # re-run .bashrc to get the alias loaded
    . ~/.bashrc

### 'geneatlas' user setup

    # log in 
    atlas

    # add these to ~geneatlas/.bash_profile
    cat <<EOT >> ~geneatlas/.bash_profile
    if [ -f /etc/bashrc ]; then
            . /etc/bashrc
    fi

    # this is important for later when python is installed
    export PATH=$HOME/.local/bin:$PATH
    export PYTHONPATH=$HOME/.local/
    EOT

    # add these lines to this file /etc/sudoers.d/geneatlas_admins
    # Gene Atlas commands
    User_Alias      GENEATLAS_USERS=foxb6,geneatlas
    Cmnd_Alias      GENEATLAS_CMDS=/bin/su geneatlas,/bin/su - geneatlas,/bin/systemctl start httpd,/bin/systemctl stop httpd
    GENEATLAS_USERS ALL=(ALL) NOPASSWD: GENEATLAS_CMDS


After editing .bash_profile, ***exit and then re login as geneatlas*** so those changes are applied.

### Build and Install software with user 'geneatlas'

Be sure to run 'sudo su - geneatlas' so you can be the geneatlas user for these steps. Or, if you setup the alias for the AD user, then just type 'atlas' to log in as 'geneatlas.'

#### Install python and pip as geneatlas user

Make a local dir to store all the bin, lib, man files. Then install Python and pip to there.     
For the python configure script, I tried --enable-shared which I thought would automatically enable -fPIC, but that behaved strangely where the resulting python executable became the earlier version already on the machine. I need fPIC to build mod_wsgi
    
    # setup build and local directories
    atlas
    cd ~/
    mkdir ~/.local
    mkdir ~/downloads
    mkdir ~/build
    
    # get Python source, build it and install
    cd ~/downloads
    wget https://www.python.org/ftp/python/2.7.16/Python-2.7.16.tgz
    cd ~/build
    tar zxvf ~/downloads/Python-2.7.16.tgz
    cd Python-2.7.16
    ./configure --enable-optimzations --prefix=$HOME/.local CFLAGS=-fPIC CXXFLAGS=-fPIC
    make
    make install

    # download and install pip
    cd ~/build
    wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py -O - | $HOME/.local/bin/python - --user
    
### Configure apache and install mod_wsgi

This was a little tricky - you have to compile python with fPIC flags and then make sure that you edit the Makefile so it doesn't try and install to the default location.

    # create the .local/httpd_modules directory so that apache can load our new mod_wsgi
    mkdir /usr/local/geneatlas/.local/httpd_modules    
    
    # build mod_wsgi
    atlas
    cd ~/downloads
    wget https://github.com/GrahamDumpleton/mod_wsgi/archive/4.6.5.tar.gz -O modwsgi-4.6.5.tar.gz
    cd ~/build
    tar zxvf ~/downloads/modwsgi-4.6.5.tar.gz
    cd modwsgi-4.6.5
    ./configure --with-python=$HOME/.local/bin/python --prefix=$HOME/.local --exec_prefix=$HOME/.local
    make
    
    # change Makefile line to install to a .local location
    sed -i "/^LIBEXECDIR/c\LIBEXECDIR = /usr/local/geneatlas/.local/httpd_modules" Makefile
    # confirm
    grep LIBEXECDIR Makefile
    
    # install mod_wsgi there
    make install

    # make sure this is the only line in the 10-wsgi.conf file in the modules location
    echo "LoadModule wsgi_module /usr/local/geneatlas/.local/httpd_modules/mod_wsgi.so" > /etc/httpd/conf.modules.d/10-wsgi.conf
    

### Install R and some packages
Perform the installation when signed into the 'geneatlas' account so that it is easy for the atlas user to add new packages to the default R location without needing sudo privaleges. An older version of R may exist already on the machine, but ignore it.
	
    # install R
    atlas
    cd ~/downloads
    wget https://cran.r-project.org/src/base/R-3/R-3.5.3.tar.gz
    cd ~/build
    tar zxvf ~/downloads/R-3.5.3.tar.gz
    cd R-3.5.3
    ./configure --prefix=$HOME/.local
    make
    make install
	
	# start R as user 'geneatlas'
	R
	
	# install packages (choose any USA mirrors when it asks)
    # in the future, I should use the R package manager for these pacakges
	install.packages("httr")
	install.packages("ggplot2")
    install.packages("gplots")
    install.packages("png")
    install.packages("gridExtra")
    install.packages("gridGraphics")
    
    # NOTE 1: during installation, it should give you this confirmation
    The downloaded source packages are in
        /tmp/RtmpXXXXX/downloaded_packages
    Updating HTML index of packages in '.Library'
    Making 'packages.html' ... done
    
    # NOTE 2: After that message, it sometimes says this (with a 
    # different list of packages each time).  I usually submit "n"
    # so that I am not constantly updating packages.
    Update old packages: 'boot', 'cluster', 'curl', 'foreign', 'ggplot2', 'httr',
      'MASS', 'Matrix', 'mgcv', 'nlme', 'openssl', 'Rcpp', 'rpart', 'survival',
      'sys'
    Update all/some/none? [a/s/n]: n
	
    # install some bioconductor pacakges
    if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
    
    BiocManager::install("limma")
    BiocManager::install("GEOquery")
    
    # quit R
    quit(save="no")

    # you can see all the R packages by checking here:
    ls -altr /usr/local/geneatlas/.local/lib64/R/library/
    
    # after cloning the exprdb repo, check exprdb/requirements.R.txt in case there are more packages to install

### Install the exprdb code

#### Clone the exprdb repository from bitbucket as user 'geneatlas' into /var/www/exprdb

You need an ssh key to access the bitbucket.org/bandrewfox/exprdb repo. After you generate your key, 
email the public key (the file id_rsa.pub) to bfox.

Brian: in order to add it to the bitbucket, go here: https://bitbucket.org/bandrewfox/exprdb/admin/access-keys/

    # generate a private/public key and save it into the default location, no passphrase
    atlas
    ssh-keygen
    
    # email the contents of the public key file to Brian
    cat ~/.ssh/id_rsa.pub
    
    # Now you can clone the repo:
    cd /var/www
    git clone git@bitbucket.org:bandrewfox/exprdb.git
    
#### Make some additional directories for the django app

	# make the static and media directories as user 'geneatlas'
    atlas
    cd /var/www
	mkdir dj_static
	mkdir dj_media
	mkdir dj_media/tmp_debug
	mkdir dj_media/rplots_tmp
	mkdir dj_media/tmp_sessions
    mkdir log
    
    
#### Add python packages using pip

    atlas
    cd /var/www/exprdb
	pip install -r requirements.txt
    
    
#### Configure the apache VirtualHost for django

    # copy the VirtualHost apache configuration to the right location
    cp /var/www/exprdb/conf/centos7_celgene/httpd-app.conf /etc/httpd/conf.d/geneatlas.conf

## Data Loading to the RDS database

### Setup the mysql/RDS database access
Make the ~/.my.cnf file and then make sure that USE_MY_CNF=1 is set in django settings.py file for this server (line ~241). 
The reason I have two sections in the .my.cnf file is that when database=gadb is in the [client] section, then mysqldump 
will try and use that database but since that database isn't the same name as the one on the old server, it adds 
'create database' to the mysqldump.  But, I don't want create database in the mysqldump, so I need to separate 
it out into [mysql]

    # contents of ~/.my.cnf
    [client]
    user=gadb
    password=xxxxxxx
    host=gadb.xxxxxxxx.us-west-1.rds.amazonaws.com

    [mysql]
    database=gadb

### Copy data from existing RDS database

Since we built the production server first, then copy the database contents from the 
RDS of prod to the staging RDS. Use AWS tools/interface for this.  Do NOT delete any data.

### Make sure manage.py process_tasks is running
Use crontab to keep checking and starting "manage.py process_tasks".

    # Add this line to crontab -e:
    *  *  *  *  *   /var/www/exprdb/conf/centos7_celgene/cron_tasks.sh  >/dev/null 2>&1


#### Configure Django and see if it works

    # make sure that exprdb/exprdb/settings.py has the IP address of this server in/near line 218:
    # elif ec2_ip in ["10.113.24.23", "10.113.24.217"]:
    # if not, then please ask Brian to fix it, since if you fix it here, then it will be overwritten when
    # doing a 'git pull.' The ssh token doesn't allow you to push code back to bitbucket.

    atlas
    
    # test the django app code
	cd /var/www/exprdb/
    python manage.py test
	
	# add the static assets to the /dj_static directory
	python manage.py collectstatic
	

### Restart Apache to load any django code updates or apache config changes

    # restart apache in the 'bfox' account
    sudo systemctl stop httpd; sudo systemctl start httpd

## Done

You should now be done!

If it doesn't work, check these logs for clues:

* /var/log/httpd/error_log
* /var/log/httpd/access_log


## Software Updates

Upon request by users/Brian, you can apply software updates.
When new code is deployed to the bitbucket repo, then you can udpate the server as follows:

    # log in as geneatlas
    atlas
    
    # git new code
    cd /var/www/exprdb
    # or
    cd ~/exprdb
    git pull
	
    # collect any static files to dj_static
    python manage.py collectstatic
    
    # can test the code
    python manage.py test
    
    # get the PID for manage.py process_tasks, then kill it (it should restart each minute due to crontab)
    ps -aux | grep -v grep | grep "manage.py process_tasks"
    kill PID
    
    # Restart apache as your user (not geneatlas)
    sudo systemctl stop httpd; sudo systemctl start httpd


### Workarounds

#### I don't remember if I need to do this: it requires sudo, try without it first

	# this has gcc, git and many other useful development tools (to help compile things)
	sudo yum groupinstall "Development Tools"
	sudo yum install mysql-devel

#### /var/log access
IF geneatlas doesn't have access to /var/log/httpd, then you can set the logs to a directory where it can access by editing the httpd.conf file. 

    mkdir /var/www/log
    vi /etc/httpd/conf/httpd.conf
    # ErrorLog "/var/www/log/error_log"
    # CustomLog "/var/www/log/access_log" combined


Copy data from old GXPA. Use scp and ssh tunnel to mysql on old server: 10.113.16.237 = geneatlas.celgene.com

    # get all the session directories
    scp -i priv.key.txt ubuntu@10.113.16.237:/home/ubuntu/dj_media .
    rm -rf dj_media/tmp_debug dj_media/rplots_tmp
    mv dj_media/* /var/www/dj_media

    # get the mysql data via mysqldump (can't just write whole database to file since 
    # filesystem isn't big enough on old server)
    
    # setup ssh tunnel to mysql on geneatlas.celgene.com (3306 is blocked at network level)
    ssh -i priv.key.txt ubuntu@10.113.16.237 -L 8001:localhost:3306 -N
    
    # this connects to the remote (old) mysql database via a localhost:8001 port
    mysql exprdb -u django -pdjango --port 8001 -h 127.0.0.1
    
    # grab all the mysql data and save to new server
    mysqldump -u django -pdjango --port 8001 -h 127.0.0.1 exprdb | gzip -c > exprdb.old.sql.gz &

    # import to new database (make sure .my.cnf has server/user/pass/database for RDS in it)
    zcat exprdb.old.sql.gz | mysql

	# just in case: build the database tables?
	# python myproj/exprdb/manage.py syncdb

Other tips

    # more aliases that I like
    alias mv="mv -i"
    alias rm="rm -i"
    alias cp="cp -i"
    alias dir="ls -al"
    alias h=history
    
    # ~geneatlas/.vimrc
    :hi Comment ctermfg=5
    autocmd Filetype python setlocal expandtab tabstop=4 shiftwidth=4 autoindent
    autocmd Filetype perl setlocal expandtab tabstop=4 shiftwidth=4 autoindent
    autocmd Filetype R setlocal expandtab tabstop=2 shiftwidth=2 autoindent
    autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif

#### clone repo using https

    # if you are Brian and have password access to bitbucket, then do this:
	# git config --global user.name "geneatlas.celgene"
	# git config --global credential.helper cache
	# git config --global credential.helper 'cache --timeout=3600000'
    # git clone https://bandrewfox@bitbucket.org/bandrewfox/exprdb.git

