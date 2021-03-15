#!/bin/bash
#
# This script loads all the container images contained in the manifest
# file.
#

IMAGE_DIR="/usr/share/container-images"
MANIFEST="${IMAGE_DIR}/images.manifest"

info() {
    echo "container-load: ${*}"
    logger -t "container-load" "${*}"
}

die() {
    info "Fatal: ${*}"
    exit 1
}

# Check if the image from a repository is loaded. The archive name is
# named like '/usr/share/images/${name}-${version}.tar' and
# the docker images are tagged as 'localhost/${name}' in the
# docker local registry.
# $1: the image name
is_image_loaded() {
    local image version image_name image_version output
    image="${1}"
    version="${2}"
    image_name="localhost/${image}"
    output=$(docker images --format='{{.Repository}} {{.Tag}}' "${image_name}")
    grep -q "${image_name} ${version}" <<< "${output}"
}

remove_old_images() {
    local image version image_name image_version output
    image="${1}"
    version="${2}"
    image_name="localhost/${image}"
    docker rmi $(docker images --format='{{.Repository}}:{{.Tag}}' "${image_name}" | grep -v "${image_name}:${version}")
}

# Load a "docker save" archive into the docker store.
load_image() {
    local image="${1}"
    local version="${2}"
    info "Loading ${IMAGE_DIR}/${image}-${version}.tar into the docker store..."

    if ! gzip -dc "${IMAGE_DIR}/${image}-${version}.tar.gz" > "/tmp/${image}-${version}.tar"; then
        die "Error extracting ${IMAGE_DIR}/${image}-${version}.tar.gz"
    fi

    if ! docker load -i "/tmp/${image}-${version}.tar"; then
        die "Error loading /tmp/${image}-${version}.tar into the docker store"
    fi

    if ! rm -f "/tmp/${image}-${version}.tar"; then
        die "Error removing /tmp/${image}-${version}.tar"
    fi
}

# Tag the images described in the manifest to "latest" tag.
tag_images() {
    [ -f "${MANIFEST}" ] ||
        die "${MANIFEST} is not installed on the system"

    local name version image
    while read -r name version shasum image _; do
        docker tag "localhost/${image}:${version}" "localhost/${image}:latest" ||
            die "Error tagging localhost/${image}:${version}"

        docker tag "localhost/${image}:${version}" "${name}:${version}" ||
            die "Error tagging ${name}:${version}"
    done < ${MANIFEST}
}

########################### MAIN SCRIPT ###########################

case "${1}" in
start)
    while read -r name version shasum image _; do
        remove_old_images "${image}" "${version}"
        is_image_loaded "${image}" "${version}" || load_image "${image}" "${version}"
        info "Succes loading ${image}:${version}..."
    done < ${MANIFEST}

    info "Success loading all the images..."
    #tag_images
    #info "Success tagging all the images to the latest tag..."
    ;;
*)
    die "Usage: ${0} start"
    ;;
esac
