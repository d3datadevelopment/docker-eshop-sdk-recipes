#!/bin/bash

SCRIPT_PATH=$(dirname ${BASH_SOURCE[0]})

cd $SCRIPT_PATH/../../../../ || exit

# Prepare services configuration
make setup
make addbasicservices
make file=services/adminer.yml addservice

$SCRIPT_PATH/../../parts/b-7.0.x/start_shop.sh -eEE
$SCRIPT_PATH/../../parts/b-7.0.x/require_smarty_components.sh -eEE

# Require demodata package
docker compose exec -T \
  php composer config repositories.oxid-esales/oxideshop-demodata-ee \
  --json '{"type":"git", "url":"https://github.com/OXID-eSales/oxideshop_demodata_ee"}'
docker compose exec -T php composer require oxid-esales/oxideshop-demodata-ee:dev-b-7.0.x-SMARTY --no-update

# Clone Econda Analytics module to modules directory
git clone https://github.com/OXID-eSales/personalization-module.git --branch=master source/dev-packages/personalization

# Configure module in composer
docker compose exec -T \
  php composer config repositories.oxid-esales/personalization-module \
  --json '{"type":"path", "url":"./dev-packages/personalization", "options": {"symlink": true}}'
docker compose exec -T php composer require oxid-esales/personalization-module:* --no-update

# Install all preconfigured dependencies
docker compose exec -T php composer update --no-interaction

# ensure database, add demodata
$SCRIPT_PATH/../../parts/shared/setup_database.sh

# activate module, create admin

docker compose exec -T php bin/oe-console oe:module:activate oepersonalization

$SCRIPT_PATH/../../parts/shared/create_admin.sh

echo "Done!"
