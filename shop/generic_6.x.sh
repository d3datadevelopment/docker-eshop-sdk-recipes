#!/bin/bash

set -euo pipefail
# set -x # debug mode

minor=7.0
edition="ee"

usage(){
  >&2 cat << EOF
  Usage: $0
     [ -m7.0 | --minor 7.0 ]
     [ -ePE | --edition PE ]
EOF
  exit 1
}

args=$(getopt -a -o hm:e: --long minor:,edition:,help -- "$@")

if [[ $# -eq 0 ]]; then
  usage
fi

eval set -- ${args}
while :
do
  case $1 in
    -m | --minor)   minor=$2    ; shift 2 ;;
    -e | --edition) edition=$2  ; shift 2 ;;
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
make file=recipes/oxid-esales/services/selenium-firefox-old.yml addservice

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

docker compose exec php composer create-project oxid-esales/oxideshop-project . dev-b-${minor}-${edition,,}

# restart Apache
docker compose up -d

echo "Done!"
