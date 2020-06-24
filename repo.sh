#!/usr/bin/env bash

set -x
set -e
set -o pipefail

# Script for Git repos housing edX services. These repos are mounted as
# data volumes into their corresponding Docker containers to facilitate development.
# Repos are cloned to/removed from the directory above the one housing this file.

DEVSTACK_DIR=`dirname $0`
for conf in ${DEVSTACK_DIR}/local*.sh ; do
    source ${conf}
done

if [ -z "$DEVSTACK_WORKSPACE" ]; then
    if ls ../src/lms.env.json > /dev/null 2>&1 ; then
        export DEVSTACK_WORKSPACE=`pwd`/..
    else
        echo "Please set workspace dir variable. This is the directory where cloned"
        echo "repositories are kept (edx-platform, cs_comments_service, credentials, etc, etc)"
        echo " "
        echo "export DEVSTACK_WORKSPACE=/Users/user/work/hawthorn"
        echo " "
        echo "Ones can store configuration variables in 'local.sh' file"
        exit 1
    fi
elif [ ! -d "$DEVSTACK_WORKSPACE" ]; then
    echo "Workspace directory $DEVSTACK_WORKSPACE doesn't exist"
    exit 1
fi

if [ -n "${OPENEDX_RELEASE}" ]; then
    BRANCH="open-release/${OPENEDX_RELEASE}"
else
    BRANCH="master"
fi

if [ -z "${repos}" ]; then
    repos=(
        "https://github.com/edx/course-discovery.git,$BRANCH"
        "https://github.com/edx/credentials.git,$BRANCH"
        "https://github.com/edx/cs_comments_service.git,$BRANCH"
        "https://github.com/edx/ecommerce.git,$BRANCH"
        "https://github.com/edx/edx-e2e-tests.git,$BRANCH"
        "https://github.com/edx/edx-notes-api.git,$BRANCH"
        "https://github.com/raccoongang/edx-platform.git,hawthorn-rg"
        "https://github.com/raccoongang/edx-theme.git,base-hawthorn-stage"
        "https://github.com/edx/xqueue.git,$BRANCH"
        "https://github.com/edx/edx-analytics-pipeline.git,$BRANCH"
    )
fi

if [ -z "${private_repos}" ]; then
    private_repos=(
        # Needed to run whitelabel tests.
        "https://github.com/edx/edx-themes.git,$BRANCH"
    )
fi

repobranch_pattern="(.*),(.*)"
name_pattern='^(.*)/([^/]+).git$'

_checkout ()
{
    repos_to_checkout=("$@")

    for repobranch in "${repos_to_checkout[@]}"
    do
        # Use Bash's regex match operator to capture the name of the repo.
        # Results of the match are saved to an array called $BASH_REMATCH.
        [[ $repobranch =~ $repobranch_pattern ]]
        repo="${BASH_REMATCH[1]}"
        branch="${BASH_REMATCH[2]}"
        [[ $repo =~ $name_pattern ]]
        origin="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"

        # If a directory exists and it is nonempty, assume the repo has been cloned.
        if [ -d "${DEVSTACK_WORKSPACE}/${name}" -a -n "$(ls -A "${DEVSTACK_WORKSPACE}/${name}" 2>/dev/null)" ]; then
            echo "Checking out branch $branch of $name"
            git -C ${DEVSTACK_WORKSPACE}/${name} pull
            git -C ${DEVSTACK_WORKSPACE}/${name} checkout "$branch"
        fi
    done
}

checkout ()
{
    _checkout "${repos[@]}"
}

_clone ()
{
    # for repo in ${repos[*]}
    repos_to_clone=("$@")

    for repobranch in "${repos_to_clone[@]}"
    do
        # Use Bash's regex match operator to capture the name of the repo.
        # Results of the match are saved to an array called $BASH_REMATCH.
        [[ $repobranch =~ $repobranch_pattern ]]
        repo="${BASH_REMATCH[1]}"
        branch="${BASH_REMATCH[2]}"
        [[ $repo =~ $name_pattern ]]
        origin="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"

        # If a directory exists and it is nonempty, assume the repo has been checked out.
        if [ -d "${DEVSTACK_WORKSPACE}/${name}" -a -n "$(ls -A "${DEVSTACK_WORKSPACE}/${name}" 2>/dev/null)" ]; then
            printf "The [%s] repo is already checked out. Continuing.\n" $name
        else
            if [ "${SHALLOW_CLONE}" == "1" ]; then
                git clone --depth=1 $repo -b ${branch} ${DEVSTACK_WORKSPACE}/${name}
            else
                git clone $repo -b ${branch} ${DEVSTACK_WORKSPACE}/${name}
            fi
        fi
    done
}

clone ()
{
    _clone "${repos[@]}"
}

clone_private ()
{
    _clone "${private_repos[@]}"
}

reset ()
{
    for repobranch in ${repos[*]}
    do
        [[ $repobranch =~ $repobranch_pattern ]]
        repo="${BASH_REMATCH[1]}"
        branch="${BASH_REMATCH[2]}"
        [[ $repo =~ $name_pattern ]]
        origin="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"

        if [ -d "${DEVSTACK_WORKSPACE}/${name}" ]; then
            echo "Resetting [${name}] to ${repo} and branch ${branch}..."
            git -C ${DEVSTACK_WORKSPACE}/${name} remote set-url origin ${repo}
            git -C ${DEVSTACK_WORKSPACE}/${name} fetch
            git -C ${DEVSTACK_WORKSPACE}/${name} reset --hard HEAD
            git -C ${DEVSTACK_WORKSPACE}/${name} checkout ${branch}
            git -C ${DEVSTACK_WORKSPACE}/${name} reset --hard origin/${branch}
            git -C ${DEVSTACK_WORKSPACE}/${name} pull origin ${branch}
        else
            printf "The [%s] repo is not cloned. Continuing.\n" $name
        fi
    done
}

status ()
{
    for repo in ${repos[*]}
    do
        [[ $repo =~ $name_pattern ]]
        origin="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"

        if [ -d "${DEVSTACK_WORKSPACE}/${name}" ]; then
            printf "\nGit status for [%s]:\n" ${DEVSTACK_WORKSPACE}/${name}
            git -C ${DEVSTACK_WORKSPACE}/${name} remote -v
            git -C ${DEVSTACK_WORKSPACE}/${name} status
        else
            printf "The [%s] repo is not cloned. Continuing.\n" $name
        fi
    done
}

if [ "$1" == "checkout" ]; then
    checkout
elif [ "$1" == "clone" ]; then
    clone
elif [ "$1" == "whitelabel" ]; then
    clone_private
elif [ "$1" == "reset" ]; then
    read -p "This will override any uncommited changes in your local git checkouts. Would you like to proceed? [y/n] " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        reset
    fi
elif [ "$1" == "status" ]; then
    status
fi
