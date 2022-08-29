#!/usr/bin/env bash
set -eo pipefail

set -x

CWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

source "$CWD/test/util.sh"

function analyze_docker_image() {

    ANCHORE_SBOM_FLAGS=(--force --wait)

    ANCHORE_SCAN_DOCKER_REPOSITORY="${ANCHORE_SCAN_DOCKER_REPOSITORY}"
    ANCHORE_SCAN_DOCKER_TAG="${ANCHORE_SCAN_DOCKER_TAG}"

    if [[ -z "${ANCHORE_SBOM_FILE_NAME}" ]]; then
        err_exit "ANCHORE_SBOM_FILE_NAME without extension is required / doesn't exist"
    fi

    if [[ -f "${DOCKERFILE}" ]]; then 
        ANCHORE_SBOM_FLAGS+=(--dockerfile "${DOCKERFILE}")
    fi

    if [[ -d "${ANCHORE_SOURCE_DIR}" ]]; then
        pushd "${ANCHORE_SOURCE_DIR}"
        GIT_REVISION=$(git describe --always --abbrev=0 $(git rev-parse --short HEAD))
        GIT_BRANCH=$(git branch --show-current)
        if [[ -z "${GIT_BRANCH}" ]]; then
            GIT_BRANCH=$GIT_REVISION
        fi
        
        GIT_REPOHOST="github.com/kong"
        GIT_SOURCE_URL="$(git config --get remote.origin.url)"
        GIT_REPONAME="$(basename "${GIT_SOURCE_URL%.*}")"
        GIT_CHANGE_AUTHOR_EMAIL=$(git log -1 --pretty=format:'%ae')
        popd
        
        APP_REVISION=$(get_app_version)
        APP_NAME="kong-ee"

        ANCHORE_SBOM_FLAGS+=(--application "${APP_NAME}@${APP_REVISION}")
        ANCHORE_OUTPUT="/tmp/anchore/${GIT_REPONAME}"
    fi

    if [[ -n "${ANCHORE_OUTPUT}" ]] || [[ -z "${ANCHORE_OUTPUT}" ]]; then
        ANCHORE_OUTPUT="/tmp/anchore"
    fi

    ANCHORE_SBOM_FLAGS+=(--get all="${ANCHORE_OUTPUT}" \
        --from="${ANCHORE_SBOM_FILE_NAME}.json")
    
    # USING syft because anchorectl expects images to exist in docker registry
    # Sfyt works with generating sbom for images present on local docker daemon
    ANCHORE_SBOM_GENERATE="syft packages ${ANCHORE_SCAN_DOCKER_REPOSITORY}:${ANCHORE_SCAN_DOCKER_TAG} \
    	-o json=${ANCHORE_SBOM_FILE_NAME}.json \
    	-o spdx-json=${ANCHORE_SBOM_FILE_NAME}.spdx.json"
    
    eval "${ANCHORE_SBOM_GENERATE}"

    ANCHORE_SBOM_UPLOAD="anchorectl image add ${ANCHORE_SCAN_DOCKER_REPOSITORY}:${ANCHORE_SCAN_DOCKER_TAG} ${ANCHORE_SBOM_FLAGS[@]} ${ANCHORE_CONFIG[@]}"
    eval "${ANCHORE_SBOM_UPLOAD}"
}

function get_app_version() {
     #Must be a git directory and should be a absolute path
    if [[ -d "${ANCHORE_APPLICATION_DIR}" ]]; then
        APP_REVISION=$(git  -C ${ANCHORE_APPLICATION_DIR} describe --always --abbrev=7 $(git  -C ${ANCHORE_APPLICATION_DIR} rev-parse --short HEAD))
    fi
    echo "${APP_REVISION}"
}

#TODO: Fix upload sbom issue using anchorectl
#TODO: Parse event UUIDs returned by AnchoreCTL to link sboms to apps on UI
function analyze_source_sbom() {
         
    ANCHORE_SBOM_FLAGS=(--wait --force)
    if [[ -n "${ANCHORE_WORKFLOW_NAME}" ]]; then
        ANCHORE_SBOM_FLAGS+=(--workflow-name "${ANCHORE_WORKFLOW_NAME}")
    fi

    if [[ -z "${ANCHORE_SBOM_FILE_NAME}" ]]; then
        err_exit "ANCHORE_SBOM_FILE_NAME without extension is required / doesn't exist"
    fi

    #Must be a git directory and should be a absolute path
    if [[ -d "${ANCHORE_SOURCE_DIR}" ]]; then
        pushd "${ANCHORE_SOURCE_DIR}"
        GIT_REVISION=$(git rev-parse --short HEAD)
        GIT_BRANCH=$(git branch --show-current)
        if [[ -z "${GIT_BRANCH}" ]]; then
            GIT_BRANCH=$GIT_REVISION
        fi
        
        GIT_REPOHOST="github.com/kong"
        GIT_SOURCE_URL="$(git config --get remote.origin.url)"
        GIT_REPONAME="$(basename "${GIT_SOURCE_URL%.*}")"
        GIT_CHANGE_AUTHOR_EMAIL=$(git log -1 --pretty=format:'%ae')

        if [[ -z "${ANCHORE_OUTPUT}" ]]; then
            ANCHORE_OUTPUT="/tmp/anchore/${GIT_REPONAME}"
        fi

        APP_REVISION=$(get_app_version)
        APP_NAME="kong-ee"

        ANCHORE_SBOM_FLAGS+=(--branch "${GIT_BRANCH}" \
            --author "${GIT_CHANGE_AUTHOR_EMAIL}" \
            --application "${APP_NAME}@${APP_REVISION}" \
            --get all="${ANCHORE_OUTPUT}" \
            --from="${ANCHORE_SBOM_FILE_NAME}.json")
            
        popd

        ANCHORE_SBOM_GENERATE="syft packages dir:${ANCHORE_SOURCE_DIR} \
            -o json=${ANCHORE_SBOM_FILE_NAME}.json \
            -o spdx-json=${ANCHORE_SBOM_FILE_NAME}.spdx.json"

        eval "${ANCHORE_SBOM_GENERATE}"

        ANCHORE_SOURCE_UPLOAD="anchorectl source add ${GIT_REPOHOST}/${GIT_REPONAME}@${GIT_REVISION} ${ANCHORE_SBOM_FLAGS[@]} ${ANCHORE_CONFIG[@]}"
        eval "${ANCHORE_SOURCE_UPLOAD}"
    else
        err_exit "Unable to generate sbom for invalid/missing anchore source directory"
    fi
} 

case "$ANCHORE_ACTION_TYPE" in
  analyze-image)
    analyze_docker_image
    ;;
  analyze-source)
    analyze_source_sbom
    ;;
esac

