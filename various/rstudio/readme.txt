
# start a default amazon linux 2 instance
# t3a.2xlarge seems nice
# mount efs @ /mnt/efs
# make sure same security group between efs and this instance
sudo mount -t efs fs-3338c836:/ /mnt/efs

# with this instance, install docker, start the service, allow ec2-user in docker group
sudo yum update -y
sudo amazon-linux-extras install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user
# log out and log in to get group perm, then next command should not be an error
docker info


### bioconductor rocker docker
sudo mkdir /mnt/efs/rstudio
sudo chown ec2-user:ec2-user /mnt/efs/rstudio

docker pull bioconductor/bioconductor_docker:RELEASE_3_10

# to run manually
docker run -e PASSWORD=xxxx -p 8787:8787 --rm -v /mnt/efs/rstudio/xxxuser:/home/rstudio -e USERID=$UID -d bioconductor/bioconductor_docker:RELEASE_3_10

# to automatically start rstudio
sudo systemctl enable docker
docker run -e PASSWORD=xxxx -p 8787:8787 -v /mnt/efs/rstudio/xxxuser:/home/rstudio --restart always -e USERID=$UID -d bioconductor/bioconductor_docker:RELEASE_3_10

