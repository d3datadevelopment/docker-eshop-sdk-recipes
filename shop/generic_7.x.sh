#!/bin/bash

set -euo pipefail
# set -x # debug mode

composercmd="composer"
minor=7.0
edition="ee"
cmdargs=""
nosetup=false
nodemodata=false
shoplanguage="de"

usage(){
  >&2 cat << EOF
  Usage: $0
     [ -m7.0 | --minor 7.0 ]
     [ -ePE | --edition PE ]
     [ --no-dev ]
     [ --no-setup ]
     [ --no-demodata ]
     [ --shoplanguage de ]
EOF
  exit 1
}

args=$(getopt -a -o hm:e: --long minor:,edition:,no-dev,no-setup,no-demodata,shoplanguage:,help -- "$@")

if [[ $# -eq 0 ]]; then
  usage
fi

eval set -- ${args}
while :
do
  case $1 in
    -m | --minor)   minor=$2    ; shift 2 ;;
    -e | --edition) if echo $2 | grep -iq '^[C|P|E]E$'; then edition=$2; else echo "invalid shop edition, use default"; fi  ; shift 2 ;;
    --no-dev)       cmdargs=${cmdargs}"--no-dev "    ; shift   ;;
    --no-setup)     nosetup=true    ; shift   ;;
    --no-demodata)  nodemodata=true    ; shift   ;;
    --shoplanguage) shoplanguage=$2  ; shift 2 ;;
    -h | --help)    usage       ; shift   ;;
    --) shift; break ;;
    *) >&2 echo Unsupported option: $1
       usage ;;
  esac
done

SCRIPT_PATH=$(dirname ${BASH_SOURCE[0]})

cd $SCRIPT_PATH/../../../ || exit

make setup
make addbasicservices
make file=services/adminer.yml addservice
make file=services/selenium-chrome.yml addservice
make file=services/node.yml addservice

# Configure containers
perl -pi\
  -e 's#error_reporting = .*#error_reporting = E_ALL ^ E_WARNING ^ E_DEPRECATED#g;'\
  containers/php/custom.ini

# Configure containers
perl -pi\
  -e 's#/var/www/#/var/www/source/#g;'\
  containers/httpd/project.conf

# Start all containers
make up

docker compose exec php ${composercmd} create-project ${cmdargs}oxid-esales/oxideshop-project . dev-b-${minor}-${edition,,}

if [ "$nosetup" = false ]
then 
  docker compose exec php ./vendor/bin/oe-console oe:setup:shop --db-host=mysql --db-port=3306 --db-name=example --db-user=root --db-password=root --shop-url=https://localhost.local --shop-directory=/var/www/source --compile-directory=/var/www/source/tmp --language=${shoplanguage}
  
  if [ "$nodemodata" = false ]
  then 
    docker compose exec php ./vendor/bin/oe-console oe:setup:demodata
  fi
  
  read -p "Admin Login E-Mail: " adm_mail
  read -sp "Admin Login Password: " adm_passwd
  docker compose exec php ./vendor/bin/oe-console oe:admin:create-user --admin-email=${adm_mail} --admin-password=${adm_passwd}
  
  docker compose exec php ./vendor/bin/oe-console oe:theme:activate apex
fi

# restart Apache
docker compose up -d

echo "Done!"
