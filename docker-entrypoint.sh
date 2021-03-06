#!/bin/bash
set -eo pipefail
shopt -s nullglob
rm -rf .php_setup

if [ "$1" = 'php-fpm' ] || [ "$1" = 'php' ];  then

    mkdir -p var/cache var/logs temp/

    echo "parameters:" > app/config/parameters.yml
    echo "parameters:" > app/config/parameters.yml.dist

    while IFS='=' read -r envvar_key envvar_value
    do
        if [[ "$envvar_key" =~ ^[symfony]+\_[a-z]+ ]]
        then
              replaceWith=""
              envvar_key=${envvar_key/symfony_/${replaceWith}}

              if [ "$envvar_value" == "true" ] || [ "$envvar_value" == "false" ]
              then
                  echo "    $envvar_key: $envvar_value" >> app/config/parameters.yml
                  echo "    $envvar_key: $envvar_value" >> app/config/parameters.yml.dist
              else
                  echo "    $envvar_key: '$envvar_value'" >> app/config/parameters.yml
                  echo "    $envvar_key: '$envvar_value'" >> app/config/parameters.yml.dist
              fi


        fi
    done < <(env)


    if [ "$ISDEV" == "true" ]; then
       composer install --optimize-autoloader --no-interaction || (echo >&2 "Composer Install Dev Failed" && exit 1)
    else
       composer install --optimize-autoloader --no-interaction --no-dev || (echo >&2 "Composer Install Prod Failed" && exit 1)
    fi

    php bin/console --env="$ENVIRONMENT" doctrine:migrations:migrate --no-interaction || (echo >&2 "Doctrine Migrations Failed" && exit 1)
    php bin/console --env="$ENVIRONMENT" assets:install web || (echo >&2 "Assetic Install Failed" && exit 1)

    if [ "$ISDEV" == "true" ]; then
        php bin/console --env="$ENVIRONMENT" assetic:dump --no-interaction || (echo >&2 "Assetic Dump Dev Failed" && exit 1)
    else
        php bin/console --env="$ENVIRONMENT" assetic:dump --no-interaction --no-debug || (echo >&2 "Assetic Dump Prod Failed" && exit 1)
    fi

    if [ "$ISDEV" == "true" ]; then
        php bin/console --env="$ENVIRONMENT" cache:warmup || (echo >&2 "Cache Warmup Dev Failed" && exit 1)
    else
        php bin/console --env="$ENVIRONMENT" cache:warmup --no-debug || (echo >&2 "Cache Warmup Prod Failed" && exit 1)
    fi

    if [ "$ISDEV" == "true" ]; then
            #Save off the db dir number.
            numdirs=$(ls -l "$DB_DIR" | grep -v ^d | wc -l | xargs)
            echo "Number of db directories is $numdirs"
            if  [ $numdirs -le 2 ]; then
                php bin/console --env="$ENVIRONMENT" doctrine:fixtures:load --no-interaction --multiple-transactions || (echo >&2 "Doctrine Fixtures Failed" && exit 1)
            fi
    fi
fi

chmod -R 777 var/cache

echo "1" > .php_setup

exec "$@"
