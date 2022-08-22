#!/usr/bin/env bash
set -eo pipefail

set -x

CWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

source "$CWD/test/util.sh"

function analyze_docker_image() {
    ANCHORE_SBOM_FLAGS=(--scope AllLayers --wait)

    ANCHORE_SCAN_DOCKER_REPOSITORY="${ANCHORE_SCAN_DOCKER_REPOSITORY}"
    ANCHORE_SCAN_DOCKER_TAG="${ANCHORE_SCAN_DOCKER_TAG}"

    if [[ -f "${DOCKERFILE}" ]]; then 
        ANCHORE_SBOM_FLAGS+=(--dockerfile "${DOCKERFILE}")
    fi

    ANCHORE_SBOM_UPLOAD="anchorectl sbom upload ${ANCHORE_SCAN_DOCKER_REPOSITORY}:${ANCHORE_SCAN_DOCKER_TAG} ${ANCHORE_SBOM_FLAGS[@]} ${ANCHORE_CONFIG[@]}"
    eval "${ANCHORE_SBOM_UPLOAD}"
}

#TODO: Fix upload sbom issue using anchorectl
#TODO: Parse event UUIDs returned by AnchoreCTL to link sboms to apps on UI
function analyze_source_sbom() {

    ANCHORE_SBOM_FLAGS=()
    if [[ -n "${ANCHORE_WORKFLOW_NAME}" ]]; then
        ANCHORE_SBOM_FLAGS+=(--workflowName "${ANCHORE_WORKFLOW_NAME}")
    fi

    #Must be a git directory and should be a absolute path
    if [[ -d "${ANCHORE_SOURCE_DIR}" ]]; then
        pushd "${ANCHORE_SOURCE_DIR}"
        GIT_REVISION=$(git describe --always $(git rev-parse --short HEAD))
        GIT_BRANCH=$(git branch --show-current)
        if [[ -z "${GIT_BRANCH}" ]]; then
            GIT_BRANCH=$GIT_REVISION
        fi
        GIT_REPONAME=$(basename `git rev-parse --show-toplevel`)
        GIT_REPOHOST="https://github.com"
        GIT_CHANGE_AUTHOR_EMAIL=$(git log -1 --pretty=format:'%ae')

        ANCHORE_SBOM_FLAGS+=(--branch "${GIT_BRANCH}" \
            --changeAuthor "${GIT_CHANGE_AUTHOR_EMAIL}" \
            --repoHost "${GIT_REPOHOST}" \
            --repoName "${GIT_REPONAME}" \
            --revision "${GIT_REVISION}")

        popd
        ANCHORE_SBOM_FILE="/tmp/anchore_sbom_${GIT_REPONAME}_${GIT_REVISION}.json"
        ANCHORE_SBOM_GENERATE_CMD="anchorectl sbom create dir:${ANCHORE_SOURCE_DIR} ${ANCHORE_CONFIG[@]} -o json"
        ANCHORE_SOURCE_UPLOAD_CMD="anchorectl source import --sbomFile ${ANCHORE_SBOM_FILE} ${ANCHORE_SBOM_FLAGS[@]} ${ANCHORE_CONFIG[@]}"

        eval "${ANCHORE_SBOM_GENERATE_CMD} > ${ANCHORE_SBOM_FILE}"
        eval "${ANCHORE_SOURCE_UPLOAD_CMD}"
    else
        err_exit "Unable to generate sbom for invalid/missing anchore source directory"
    fi
}


ANCHORE_CONFIG=()

if [[ -f "${ANCHORE_CONFIG_FILE}" ]]; then
    ANCHORE_CONFIG+=(--config ${ANCHORE_CONFIG_FILE})
fi 

case "$ANCHORE_SCAN_TYPE" in
  image)
    analyze_docker_image
    ;;
  source)
    analyze_source_sbom
    ;;
esac

