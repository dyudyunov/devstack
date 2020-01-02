#!/usr/bin/env bash

set -e
set -o pipefail

# Script for Git repos housing edX services. These repos are mounted as
# data volumes into their corresponding Docker containers to facilitate development.
# Repos are cloned to/removed from the directory above the one housing this file.

if [ -z "$DEVSTACK_WORKSPACE" ]; then
    if ls ../src/lms.env.json > /dev/null 2>&1 ; then
        export DEVSTACK_WORKSPACE=`pwd`/..
    else
        echo "need to set workspace dir"
        exit 1
    fi
elif [ -d "$DEVSTACK_WORKSPACE" ]; then
    cd $DEVSTACK_WORKSPACE
else
    echo "Workspace directory $DEVSTACK_WORKSPACE doesn't exist"
    exit 1
fi

echo "Working in ${DEVSTACK_WORKSPACE}"

if [ -n "${OPENEDX_RELEASE}" ]; then
    OPENEDX_GIT_BRANCH=open-release/${OPENEDX_RELEASE}
else
    OPENEDX_GIT_BRANCH=open-release/ironwood.master
fi

repos=(
    "https://github.com/edx/course-discovery.git,$OPENEDX_GIT_BRANCH"
    "https://github.com/edx/credentials.git,$OPENEDX_GIT_BRANCH"
    "https://github.com/edx/cs_comments_service.git,$OPENEDX_GIT_BRANCH"
    "https://github.com/edx/ecommerce.git,$OPENEDX_GIT_BRANCH"
    "https://github.com/edx/edx-e2e-tests.git,$OPENEDX_GIT_BRANCH"
    "https://github.com/edx/edx-notes-api.git,$OPENEDX_GIT_BRANCH"
    "https://gitlab.raccoongang.com/edx/edx-platform.git,ironwood-rg"
    "https://gitlab.raccoongang.com/edx/edx-theme.git,ironwood-rg"
    "https://github.com/edx/xqueue.git,$OPENEDX_GIT_BRANCH"
    "https://github.com/edx/edx-analytics-pipeline.git,$OPENEDX_GIT_BRANCH"
)

private_repos=(
    # Needed to run whitelabel tests.
    "https://github.com/edx/edx-themes.git,$BRANCH"
)

repobranch_pattern="(.*),(.*)"
name_pattern=".*/(.*)/(.*).git"

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
            _checkout_and_update_branch
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

        # If a directory exists and it is nonempty, assume the repo has been checked out
        # and only make sure it's on the required branch
        if [ -d "${DEVSTACK_WORKSPACE}/${name}" -a -n "$(ls -A "${DEVSTACK_WORKSPACE}/${name}" 2>/dev/null)" ]; then
            printf "The [%s] repo is already checked out. Checking for updates.\n" $name
            _checkout_and_update_branch
        else
            if [ "${SHALLOW_CLONE}" == "1" ]; then
                git clone --single-branch -b ${branch} -c core.symlinks=true --depth=1 ${repo} ${DEVSTACK_WORKSPACE}/${name}
            else
                git clone --single-branch -b ${branch} -c core.symlinks=true ${repo} ${DEVSTACK_WORKSPACE}/${name}
            fi
        fi
    done
    cd - &> /dev/null
}

_checkout_and_update_branch ()
{
    GIT_SYMBOLIC_REF="$(git -C ${DEVSTACK_WORKSPACE}/${name} symbolic-ref HEAD 2>/dev/null || true)"
    BRANCH_NAME=${GIT_SYMBOLIC_REF##refs/heads/}
    git -C ${DEVSTACK_WORKSPACE}/${name} fetch --all --tags
    if [ "${BRANCH_NAME}" == "${branch}" ]; then
        git -C ${DEVSTACK_WORKSPACE}/${name} pull origin ${branch}
    else
        git -C ${DEVSTACK_WORKSPACE}/${name} fetch origin ${branch}:${branch}
        git -C ${DEVSTACK_WORKSPACE}/${name} checkout ${branch}
    fi
    find ${DEVSTACK_WORKSPACE}/${name} -name '*.pyc' -not -path './.git/*' -delete 
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
    currDir=$(pwd)
    for repo in ${repos[*]}
    do
        [[ $repo =~ $name_pattern ]]
        origin="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"

        if [ -d "$name" ]; then
            cd $name;git reset --hard HEAD;git checkout master;git reset --hard origin/master;git pull;cd "$currDir"
        else
            printf "The [%s] repo is not cloned. Continuing.\n" $name
        fi
    done
    cd - &> /dev/null
}

status ()
{
    currDir=$(pwd)
    for repo in ${repos[*]}
    do
        [[ $repo =~ $name_pattern ]]
        origin="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"

        if [ -d "$name" ]; then
            printf "\nGit status for [%s]:\n" $name
            cd $name;git remote -v;git status;cd "$currDir"
        else
            printf "The [%s] repo is not cloned. Continuing.\n" $name
        fi
    done
    cd - &> /dev/null
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
