# ##############################################
#
# RaccoonGang configuration defaults
#
# - to disable effect of this file remove it or rename to local-rg.sh.disabled
# - to work with docker or docker-compose build please set this variables in
#   current terminal session by executing `. local-rg.sh`
#
# ##############################################

# The part of docker container names can be overriden for specific project
#
# please do not modify this variable! the work is in progress...

COMPOSE_PROJECT_NAME=ironwood
export COMPOSE_PROJECT_NAME

# The directory where clonned repositories will be kept
# (edx-platform, cs_comments_service, credentials, etc, etc)
#
# Your can keep single workspace for multiple projects by
# specifying here the full path to workspace directory

# Default suffix while selecting branch name for ALL repositories.
# Many OpenEdx devstack management scripts relies on this variable.
#
OPENEDX_RELEASE=ironwood.master
export OPENEDX_RELEASE

# Customisible list of devstack repositories

repos=(
    "https://github.com/edx/course-discovery.git,open-release/${OPENEDX_RELEASE}"
    "https://github.com/edx/credentials.git,open-release/${OPENEDX_RELEASE}"
    "https://github.com/edx/cs_comments_service.git,open-release/${OPENEDX_RELEASE}"
    "https://github.com/edx/ecommerce.git,open-release/${OPENEDX_RELEASE}"
    "https://github.com/edx/edx-e2e-tests.git,open-release/${OPENEDX_RELEASE}"
    "https://github.com/edx/edx-notes-api.git,open-release/${OPENEDX_RELEASE}"
    "https://github.com/raccoongang/edx-platform.git,ironwood-rg"
    "https://github.com/raccoongang/edx-theme.git,base-ironwood-stage"
    "https://github.com/edx/xqueue.git,open-release/${OPENEDX_RELEASE}"
    "https://github.com/edx/edx-analytics-pipeline.git,open-release/${OPENEDX_RELEASE}"
)
export repos
