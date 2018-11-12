#!/usr/bin/env bash

set -eo pipefail

CWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

BINTRAY_ORG="kong"
BINTRAY_USR=$BINTRAY_USR
BINTRAY_KEY=$BINTRAY_KEY
BINTRAY_API="https://api.bintray.com"

KONG_PACKAGE_NAME=$KONG_PACKAGE_NAME
KONG_VERSION=$KONG_VERSION
PACKAGE_TYPE=$PACKAGE_TYPE

BUILD_DIR="output"
REPOSITORY_NAME=""
BINTRAY_PUT_ARGS=""

if [ "$RESTY_IMAGE_BASE" == "ubuntu" ]; then
  PACKAGE_TYPE="deb"
  REPOSITORY_NAME=$KONG_PACKAGE_NAME-deb
  OUTPUT_FILE_SUFFIX=".${RESTY_IMAGE_TAG}.all.deb"
  BINTRAY_PUT_ARGS=";deb_distribution=$RESTY_IMAGE_TAG;deb_component=main;deb_architecture=i386,amd64,noarch"
elif [ "$RESTY_IMAGE_BASE" == "rhel" ]; then
  PACKAGE_TYPE="rpm"
  REPOSITORY_NAME=$KONG_PACKAGE_NAME-rpm
  OUTPUT_FILE_SUFFIX=".rhel${RESTY_IMAGE_TAG}.noarch.rpm"
elif [ "$RESTY_IMAGE_BASE" == "centos" ]; then
  PACKAGE_TYPE="rpm"
  REPOSITORY_NAME=$KONG_PACKAGE_NAME-rpm
  OUTPUT_FILE_SUFFIX=".el${RESTY_IMAGE_TAG}.noarch.rpm"
fi

BINTRAY_PUT_ARGS="$BINTRAY_PUT_ARGS?publish=1&override=0"

DIST_FILE="$KONG_PACKAGE_NAME-$KONG_VERSION$OUTPUT_FILE_SUFFIX"
BUILD_DIR="$CWD/output/"

function print_result {
  [[ "$#" != 2 ]] && exit 1
  local status=$(echo $2 | awk -F"=" '{print $2}')
  local result=$(echo $2 | awk -F"=" '{print $1}')
  echo "$1: [status = $status] $result"
}

# create a repository
# - arg 1: repo name
# - arg 2: repo type - e.g., deb, rpm, docker
function create_repo {
  local repo_name=$1
  local repo_type=$2

  local repo_is_private=$PRIVATE_REPOSITORY

  local metadata_depth_json
  if [[ "$repo_type" == "rpm" ]]; then
    metadata_depth_json='"yum_metadata_depth": 2,'
  fi

  # check if repo exists
  local resp=$(curl -X GET --write-out =%{http_code} -s -o - \
             -u $BINTRAY_USR:$BINTRAY_KEY \
             "$BINTRAY_API/repos/$BINTRAY_ORG/$repo_name")

  # retrieve status code and response body
  local status=$(echo $resp | awk -F"=" '{print $2}')
  local result=$(echo $resp | awk -F"=" '{print $1}')

  # if repo does not exist, create
  if [[ "$status" -ne "200" ]]; then

    echo "Creating repo $repo_name..."

    resp=$(curl -X POST --write-out =%{http_code} -s -o - \
                -u $BINTRAY_USR:$BINTRAY_KEY \
                "$BINTRAY_API/repos/$BINTRAY_ORG/$repo_name" \
                -H "Content-type: application/json" \
                -d @- << EOF
                {
                    "type": "$repo_type",
                    "private": $repo_is_private,
                    "gpg_sign_metadata": true,
                    "gpg_sign_files": true,
                    $metadata_depth_json
                    "labels": ["API Gateway", "Kong"],
                }
EOF
          )

    status=$(echo $resp | awk -F"=" '{print $2}')
    result=$(echo $resp | awk -F"=" '{print $1}')

    echo "Repo creation status: [status: $status] $result"
  fi
}

# create a package inside a repo
# - arg 1: repo name
# - arg 2: package name
function create_package {
  local repo_name=$1
  local package_name=$2

  local package_stats_private=true
  local package_license='"licenses": ["Apache-2.0"],'

  # check if package exists
  local resp=$(curl -X GET --write-out =%{http_code} -s -o - \
             -u $BINTRAY_USR:$BINTRAY_KEY \
             "$BINTRAY_API/packages/$BINTRAY_ORG/$repo_name/$package_name")

  # retrieve status code and response body
  local status=$(echo $resp | awk -F"=" '{print $2}')
  local result=$(echo $resp | awk -F"=" '{print $1}')

  # if package does not exist, create
  if [[ "$status" -ne "200" ]]; then

    echo "Creating package $package_name..."

    resp=$(curl -X POST --write-out =%{http_code} -s -o - \
                -u $BINTRAY_USR:$BINTRAY_KEY \
                "https://api.bintray.com/packages/$BINTRAY_ORG/$repo_name" \
                -H "Content-type: application/json" \
                -d @- << EOF
                {
                    "name": "$package_name",
                    $package_license
                    "vcs_url": "https://github.com/Kong/kong/",
                    "website_url": "https://getkong.org/",
                    "issue_tracker_url": "https://github.com/Kong/kong/issues",
                    "public_download_numbers": $package_stats_private,
                    "public_stats": $package_stats_private
                 }
EOF
          )

    status=$(echo $resp | awk -F"=" '{print $2}')
    result=$(echo $resp | awk -F"=" '{print $1}')

    echo "Package creation status: [status: $status] $result"
  fi
}

create_repo "$REPOSITORY_NAME" "$PACKAGE_TYPE"
create_package "$REPOSITORY_NAME" "$RESTY_IMAGE_BASE"
  
RESPONSE=$(curl -X PUT --write-out =%{http_code} -s -o - \
  -u $BINTRAY_USR:$BINTRAY_KEY \
  "$BINTRAY_API/content/$BINTRAY_ORG/$REPOSITORY_NAME/$RESTY_IMAGE_BASE/$KONG_VERSION/dists/$DIST_FILE$BINTRAY_PUT_ARGS" \
  -T $DIR/$BUILD_DIR$DIST_FILE)

print_result "$REPOSITORY_NAME artifact upload" "$RESPONSE"

echo -e "\nVersion $KONG_VERSION release finished"

exit 0