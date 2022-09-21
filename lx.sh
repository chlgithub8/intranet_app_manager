#!/bin/sh
dir=$(pwd)
configPath=$dir/src/main/resources/application.properties
caPath=$dir/src/main/resources/static/crt/ca.crt
p12Path=$dir/src/main/resources/server.pkcs12
sslConfigPath=$dir/openssl.cnf
param=$1

echo "$param"
getIpForMac(){
  ifconfig | grep inet | grep -v inet6 | grep -v 127 | cut -d ' ' -f2
}

getIpForLinux(){
  ip a | grep inet | grep -v inet6 | grep -v 127 | sed 's/^[ \t]*//g' | cut -d ' ' -f2
}

ip="127.0.0.1"
ip="$(getIpForLinux)"

build(){
  mysqlAddr="docker_mysql"
  sed -i "" "s/\${ip}/$mysqlAddr/" "$configPath"
  gradle clean
  gradle build
  cd "$dir/build/libs/"
  mv intranet_app_manager*.jar intranet_app_manager.jar
  cd "$dir"
  sed -i "" "s/$mysqlAddr/\${ip}/" "$configPath"
}

createCert(){
  cd "$dir"
  rm -rf certs
  mkdir -p certs/CA/{certs,crl,newcerts,private}
  touch certs/CA/index.txt
  touch certs/CA/certs.db
  cp -rf "$sslConfigPath" certs/openssl.cnf
  echo 00 > certs/CA/serial
  sed -i "" "s/\${ip}/$ip/" "$dir/certs/openssl.cnf"
  cd "$dir/certs"
  echo "输入:123456"
  openssl req -new -x509 -days 3650 -keyout ca.key -out ca.crt -config openssl.cnf
  openssl genrsa -out server.key 2048
  openssl req -new -key server.key -out server.csr -config openssl.cnf
  openssl ca -in server.csr -out server.crt -cert ca.crt -keyfile ca.key -extensions v3_req -config openssl.cnf
  openssl pkcs12 -export -in server.crt -inkey server.key -out server.pkcs12
  cp -rf "$dir/certs/ca.crt" "$caPath"
  cp -rf "$dir/certs/server.pkcs12" "$p12Path"
  cd "$dir"
  rm -rf certs
}

startup(){
  ps -efww | grep -w 'intranet_app_manager' | grep -v grep |awk '{print $2}'|xargs kill -9
  killall -9 mysqld
  docker-compose up -d
}

openPage(){
  address="http://$ip:8080/account/signin"
  echo "$address"
  x-www-browser "$address"
}

setup(){
  createCert
  build
  docker-compose build
  startup
  openPage
}

setup