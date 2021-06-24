#!/bin/bash
#
# This script loads all the container images contained in the manifest
# file.
#

IMAGE_DIR="/usr/share/container-images"

info() {
    echo "container-load: ${*}"
    logger -t "container-load" "${*}"
}

die() {
    info "Fatal: ${*}"
    exit 1
}

is_image_loaded() {
    shahash="${1}"
    output=$(docker images --digests --format='{{.Digest}} {{.Tag}}')
    echo "${output}" | grep -q "${shahash}" 
}

remove_old_images() {
    username="${1}"
    image="${2}"
    shahash="${3}"
    
    if [ -n "$(docker images --format='{{.Repository}}:{{.Tag}}@{{.Digest}} {{.ID}}' "${username}/${image}" | grep ${shahash} )" ]; then
        current_image_ids="$(docker images --format='{{.Repository}}:{{.Tag}}@{{.Digest}} {{.ID}}' "${username}/${image}" | grep ${shahash} | cut -d' ' -f2)"
        [ -n "$(docker images --format='{{.ID}}' "${username}/${image}" | grep -v "${current_image_ids}" )" ] && docker rmi --force "$(docker images --format='{{.ID}}' "${username}/${image}" | grep -v ${current_image_ids} | uniq | tr '\n' ' ')"
    else
        [ -n "$(docker images --format='{{.ID}}' "${username}/${image}" )" ] && docker rmi --force $(docker images --format='{{.ID}}' "${username}/${image}" | uniq | tr '\n' ' ')
    fi
}

# Load a "docker save" archive into the docker store.
load_image() {
    local file="${1}"
    local username="$(echo ${2} | tr _ / )"
    local image="$(echo ${3} | tr _ / )"
    local tag="${4}"

    info "Loading ${IMAGE_DIR}/${file} into the docker store..."

 
    if ! docker load -i "${IMAGE_DIR}/${file}"; then
        die "Error loading ${IMAGE_DIR}/${file}.tar into the docker store"
    fi

    if ! docker tag localhost/${image}:${tag} ${username}/${image}:${shahash}; then
        die "Error tagging ${username}/${image}:${tag}"
    fi

    if ! docker tag localhost/${image}:${tag} ${username}/${image}:${tag}; then
        die "Error tagging ${username}/${image}:${tag}"
    fi

    if ! docker rmi localhost/${image}:${tag}; then
        die "Error removing localhost tag ${username}/${image}:${tag}"
    fi    
}


########################### MAIN SCRIPT ###########################

case "${1}" in
start)
    filenames=`cd ${IMAGE_DIR} && ls *.tar.gz`
    for file in $filenames; do

        IFS='#'
        read -ra info <<< "$file"
        IFS=' '

        UNAME="${info[0]}"
        IMAGE="${info[1]}"
        TAG="${info[2]}"
        SHAHASH="$(echo ${info[3]} | cut -d'.' -f1)"

        remove_old_images "${UNAME}" "${IMAGE}" "${SHAHASH}"
        (is_image_loaded "${SHAHASH}" && info "${IMAGE_DIR}/${file} already in store.") || load_image "${file}" "${UNAME}" "${IMAGE}" "${TAG}"
    done

    info "Success loading all the images..."
    ;;
*)
    die "Usage: ${0} start"
    ;;
esac
