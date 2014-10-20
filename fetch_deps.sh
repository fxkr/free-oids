#!/bin/bash

#
# Fetches the dependencies
#

set -e -u -x

# Change to this scripts directory
cd "$( dirname "${BASH_SOURCE[0]}" )"


# Bootstrap
# ---------

# Get URL of latest bootstrap release (urgh)
BOOTSTRAP_URL=$(curl -s https://api.github.com/repos/twbs/bootstrap/releases \
    | python -c "`cat <<EOF
import json, re, sys
EXPR = re.compile('bootstrap-[0-9.]+-dist.zip$')
releases = json.load(sys.stdin)
releases.sort(key=lambda release: release["created_at"], reverse=True)
release = releases[0]
assets = release["assets"]
assets = [asset for asset in assets if EXPR.match(asset["name"])]
asset = assets[0]
url = asset["browser_download_url"]
print(url)
EOF`")

# Create temporary directory
TEMP_DIR="`mktemp -d`"
trap "rm -rf \"$TEMP_DIR\"" EXIT

# Download and unpack it
wget "$BOOTSTRAP_URL" -O "$TEMP_DIR/bootstrap.zip"
unzip -q -d "$TEMP_DIR" "$TEMP_DIR/bootstrap.zip"

# Copy files to right folders
COMPONENTS=($TEMP_DIR/bootstrap-*-dist/{css,js,fonts})
echo "${COMPONENTS[@]}"
cp -a "${COMPONENTS[@]}" freeoids/static/


# JQuery
# ------

wget https://code.jquery.com/jquery-2.1.1.min.js \
    -O freeoids/static/js/jquery.min.js


# Virtualenv
# ----------

# Create environment
if [ ! -e .env ] ; then
    virtualenv .env
fi

# Enter it
virtualenv .env

# Install packages
pip install -r requirements.txt

