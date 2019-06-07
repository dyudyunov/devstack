#!/usr/bin/env bash

GAMMA_CONFIG=$DEVSTACK_WORKSPACE/gamma/gamma/settings/local.py
if [ ! -f "$GAMMA_CONFIG" ]; then
    echo "$GAMMA_CONFIG does not exist, will create it using local_example.py"
    cp $DEVSTACK_WORKSPACE/gamma/gamma/settings/local_example.py $DEVSTACK_WORKSPACE/gamma/gamma/settings/local.py
fi

docker-compose $DOCKER_COMPOSE_FILES up -d gamma

# performing migrations
docker exec -t edx.devstack.gamma.app python manage.py migrate

# creating superuser for django admin
docker exec -t edx.devstack.gamma.app bash -c 'echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser(\"admin\", \"admin@example.com\", \"admin\") if not User.objects.filter(username=\"admin\").exists() else None" | python manage.py shell'
