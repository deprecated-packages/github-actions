#!/bin/sh -l

# if a command fails it stops the execution
set -e

# script fails if trying to access to an undefined variable
set -u

function note()
{
    MESSAGE=$1;

    printf "\n";
    echo "[NOTE] $MESSAGE";
    printf "\n";
}

note "Starts"

PACKAGE_DIRECTORY="$1"
SPLIT_REPOSITORY_ORGANIZATION="$2"
SPLIT_REPOSITORY_NAME="$3"
COMMIT_MESSAGE="$4"
TAG="$5"
USER_EMAIL="$6"
USER_NAME="$7"

# setup git
if test ! -z "$USER_EMAIL"
then
    git config --global user.email "$USER_EMAIL"
fi

if test ! -z "$USER_NAME"
then
    git config --global user.name "$USER_NAME"
fi

WORKDIR="$(pwd)"

CLONE_DIR=$(mktemp -d)
CLONED_REPOSITORY="https://github.com/$SPLIT_REPOSITORY_ORGANIZATION/$SPLIT_REPOSITORY_NAME.git"
note "Cloning '$CLONED_REPOSITORY' repository"

# clone previous version of split repository
git clone -- "https://$GITHUB_TOKEN@github.com/$SPLIT_REPOSITORY_ORGANIZATION/$SPLIT_REPOSITORY_NAME.git" "$CLONE_DIR"
cd "$CLONE_DIR"
ls -la

# delete all files first (to handle deletions)
note "Cleaning destination repository of old files"
git rm -r
ls -la

note "Copying contents to git repo"
# Must restore workdir, as PACKAGE_DIRECTORY is likely relative path
cd "$WORKDIR"
cp -r "$PACKAGE_DIRECTORY"/{.??*,*} "$CLONE_DIR"
ls -la "$CLONE_DIR"

note "Adding git commit"

ORIGIN_COMMIT="https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
COMMIT_MESSAGE="${COMMIT_MESSAGE/ORIGIN_COMMIT/$ORIGIN_COMMIT}"

git add .
git status

# git diff-index : to avoid doing the git commit failing if there are no changes to be commit
git diff-index --quiet HEAD || git commit --message "$COMMIT_MESSAGE"

note "Pushing git commit"

# --set-upstream: sets the branch when pushing to a branch that does not exist
git push --quiet origin master

# push tag if present
if test ! -z "$TAG"
then
    note "Publishing tag: ${TAG}"

    # if tag already exists in remote
    TAG_EXISTS_IN_REMOTE=$(git ls-remote origin refs/tags/$TAG)

    # tag does not exist
    if test -z "$TAG_EXISTS_IN_REMOTE"
    then
        git tag $TAG -m "Publishing tag ${TAG}"
        git push --quiet origin "${TAG}"
    fi
fi
