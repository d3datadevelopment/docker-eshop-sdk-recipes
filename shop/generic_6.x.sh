#!/bin/bash

set -euo pipefail
# set -x # debug mode

composercmd="composer"
minor=7.0
edition="ee"
cmdargs=""
nosetup=false
composer1=false

usage(){
  >&2 cat << EOF
  Usage: $0
     [ -m7.0 | --minor 7.0 ]
     [ -ePE | --edition PE ]
     [ --no-dev ]
     [ --no-setup ]
     [ --composer1 ]
EOF
  exit 1
}

args=$(getopt -a -o hm:e: --long minor:,edition:,no-dev,no-setup,composer1,help -- "$@")

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
    --composer1)    composercmd="composer1"   ; shift   ;;
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
make file=recipes/shop/services/selenium-firefox-old.yml addservice

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

# if [ "$nosetup" = false ]
# then 
  # run setup, but unavailable via CLI in OXID 6
# fi

# restart Apache
docker compose up -d

echo "Done!"
