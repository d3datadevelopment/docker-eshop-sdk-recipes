#!/bin/bash

# Flags possible:
# -e for shop edition. Possible values: CE/PE/EE
# b-6.5.x.sh -ePE

edition='ee'
while getopts e: flag; do
  case "${flag}" in
  e) edition=${OPTARG} ;;
  *) ;;
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

docker compose exec php composer create-project oxid-esales/oxideshop-project . dev-b-7.0-${edition,,}

# restart Apache
docker compose up -d

echo "Done!"
