set -e
set -o pipefail
set -x

apps=( lms studio )

# Load database dumps for the largest databases to save time
./load-db.sh edxapp
./load-db.sh edxapp_csmh

# Bring edxapp containers online
for app in "${apps[@]}"; do
    docker-compose $DOCKER_COMPOSE_FILES up -d $app
done

docker-compose exec lms bash -c 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform && NO_PYTHON_UNINSTALL=1 paver install_prereqs'

#Installing prereqs crashes the process
docker-compose restart lms

# Run edxapp migrations first since they are needed for the service users and OAuth clients
docker-compose exec lms bash -c 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform && paver update_db --settings devstack_docker'

# Create a superuser for edxapp
docker-compose exec lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms --settings=devstack_docker manage_user edx edx@example.com --superuser --staff'
docker-compose exec lms bash -c 'source /edx/app/edxapp/edxapp_env && echo "from django.contrib.auth import get_user_model; User = get_user_model(); user = User.objects.get(username=\"edx\"); user.set_password(\"edx\"); user.save()" | python /edx/app/edxapp/edx-platform/manage.py lms shell  --settings=devstack_docker'

# Create an enterprise service user for edxapp
docker-compose exec lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms --settings=devstack_docker manage_user enterprise_worker enterprise_worker@example.com'

# Enable the LMS-E-Commerce integration
docker-compose exec lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms --settings=devstack_docker configure_commerce'

# Create demo course and users
docker-compose exec lms bash -c '/edx/app/edx_ansible/venvs/edx_ansible/bin/ansible-playbook /edx/app/edx_ansible/edx_ansible/playbooks/demo.yml -v -c local -i "127.0.0.1," --extra-vars="COMMON_EDXAPP_SETTINGS=devstack_docker" --extra-vars="common_debian_variants=[]"'

# Fix missing vendor file by clearing the cache
docker-compose exec lms bash -c 'rm /edx/app/edxapp/edx-platform/.prereqs_cache/Node_prereqs.sha1'

# Create static assets for both LMS and Studio
for app in "${apps[@]}"; do
    docker-compose exec $app bash -c 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform && paver update_assets --settings devstack_docker'
done

# Provision a retirement service account user
./provision-retirement-user.sh retirement retirement_service_worker

# Add demo program
./programs/provision.sh lms

# Move original lms.env.json and cms.env.json to backup files on /edx/src docker volume
# Create lms.env.json and cms.env.json as symlinks to files on /edx/src docker volume
for app in "${apps[@]}"; do
    docker-compose exec $app bash -c 'mkdir -p /edx/src; test -L /edx/app/edxapp/lms.env.json || (mv /edx/app/edxapp/lms.env.json /edx/src/lms.env.json.orig; ln -s /edx/src/lms.env.json /edx/app/edxapp/lms.env.json); test -L /edx/app/edxapp/cms.env.json || (mv /edx/app/edxapp/cms.env.json /edx/src/cms.env.json.orig; ln -s /edx/src/cms.env.json /edx/app/edxapp/cms.env.json)'
done
