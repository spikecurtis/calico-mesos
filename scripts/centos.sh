#!/usr/bin/env bash
set -e
set -x

# Upgrade all packages.
yum update -y

# Install EPEL
yum install -y tar wget epel-release
wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo

# Install Wandisco (for subversion-devel)
cat <<EOT >> /etc/yum.repos.d/wandisco-svn.repo
[WANdiscoSVN]
name=WANdisco SVN Repo 1.9
enabled=1
baseurl=http://opensource.wandisco.com/centos/7/svn-1.9/RPMS/$basearch/
gpgcheck=1
gpgkey=http://opensource.wandisco.com/RPM-GPG-KEY-WANdisco
EOT

# Mesos Deps
yum groupinstall -y "Development Tools"
yum install -y \
  apache-maven \
  python-devel \
  java-1.7.0-openjdk-devel \
  zlib-devel \
  libcurl-devel \
  openssl-devel \
  cyrus-sasl-devel \
  cyrus-sasl-md5 \
  apr-devel \
  subversion-devel \
  apr-util-devel \
  protobuf-devel \
  protobuf-python \
  boost-devel \
  python-setuptools \
  automake

# Install the picojson headers
wget https://raw.githubusercontent.com/kazuho/picojson/v1.3.0/picojson.h -O /usr/local/include/picojson.h

# Build & install glog
cd /root
git clone https://github.com/google/glog.git
cd glog
git checkout v0.3.3
./configure --prefix=/usr/local
make install
cd /root

# Prepare to build Mesos
mkdir mesos
mkdir -p /tmp
mkdir -p /usr/share/java/
wget http://search.maven.org/remotecontent?filepath=com/google/protobuf/protobuf-java/2.5.0/protobuf-java-2.5.0.jar -O protobuf.jar
mv protobuf.jar /usr/share/java/

# Clone Mesos (master branch)
git clone https://github.com/apache/mesos.git
cd mesos
git checkout 0.25.0
git log -n 1

# Bootstrap
./bootstrap

# Configure
mkdir build && cd build && ../configure --disable-java --disable-optimize --without-included-zookeeper --with-glog=/usr/local --with-protobuf=/usr --with-boost=/usr/local

# Build Mesos
make -j 2 install

# Install python eggs (needed for sample framework)
easy_install /root/mesos/build/src/python/dist/mesos.interface-*.egg
easy_install /root/mesos/build/src/python/dist/mesos.native-*.egg

# Isolator
cd /root
mkdir net-modules
git clone https://github.com/mesosphere/net-modules.git net-modules
cd net-modules && git checkout integration/0.25
cd isolator

./bootstrap && \
  rm -rf build && \
  mkdir build && \
  cd build && \
  export LD_LIBRARY_PATH=LD_LIBRARY_PATH:/usr/local/lib && \
  ../configure --with-mesos=/usr/local --with-protobuf=/usr && \
  make all
