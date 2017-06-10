#!/bin/sh
# Gratitiously stolen from:
#   https://github.com/Villanuevand/deployment-circleci-gh-pages/blob/master/scripts/deploy.sh
#   from: https://github.com/eldarlabs/ghpages-deploy-script
#   ideas used from https://gist.github.com/motemen/8595451

NO_COLOR="\033[0m"
GREEN="\033[0;32m"
RED="\033[31;01m"
WARN_COLOR="\033[33;01m"

OK_STRING="$OK_COLOR[OK] $NO_COLOR"
INFO="$GREEN====>>[INFO] $NO_COLOR"
ERROR="$RED====>>[ERROR] $NO_COLOR"
WARN="$YELLOW====>>[WARN] $NO_COLOR"

repo=$1

remote=git@github.com:newtonsystems/$1.git

siteSource="$2"

# Basic Sanity Checks

# Is there a sphinx built documentation folder
if [ ! -d "$siteSource" ]
then
    echo "Usage: $0 <sphinx html built folder>"
    exit 1
fi

# make a directory to put the gh-pages branch
mkdir -p _build
cd _build

# now lets setup a new repo so we can update the gh-pages branch
git config --global user.email "james.tarball@gmail.com" > /dev/null 2>&1
git config --global user.name "newtonsystems" > /dev/null 2>&1
git init
git remote add --fetch origin "$remote"

# switch into the the gh-pages branch
if git rev-parse --verify origin/gh-pages > /dev/null 2>&1
then
    git checkout gh-pages
    # delete any old site as we are going to replace it
    # Note: this explodes if there aren't any, so moving it here for now
    if [ "$(ls)" ];
    then
        git rm -rf .
    fi
else
    git checkout --orphan gh-pages
fi

# If not built - build the docs
if [ ! -d ../docs/build ];
then
    echo "$WARN docs haven't been built. Will run 'make html' ..."
    make html
fi

# copy over or recompile the new site
cp -a "../${siteSource}/." .

# stage any changes and new files
git add -A

# now commit, ignoring branch gh-pages doesn't seem to work, so trying skip
git commit --allow-empty -m "Deploy to GitHub pages [ci skip] for `git log -1 --pretty=short --abbrev-commit`"

# and push, but send any output to /dev/null to hide anything sensitive
git push --force origin gh-pages

# go back to where we started and remove the gh-pages git repo we made and used
# for deployment
cd ..
rm -rf _build

echo "$INFO Finished Deployment of docs!"
echo "$INFO You can view it at: https://newtonsystems.github.io/$repo/"
