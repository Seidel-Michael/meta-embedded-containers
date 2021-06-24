STORE_DIR ??= "${WORKDIR}/container-store"
INSANE_SKIP_${PN} += "already-stripped arch"

EXTRACT_CONTAINER ?= "False"

check_configuration() {
    [ -n "${REGISTRY}" ] || bbfatal "REGISTRY not set"
    [ -n "${IMAGE}" ] || bbfatal "IMAGE not set"
    [ -n "${SHAHASH}" ] || bbfatal "SHAHASH not set"
    [ -n "${TAG}" ] || bbfatal "TAG not set"
}

check_credentials() {  

    if [ "${USE_ARTIFACTORY_AUTH}" = "True" ]; then
        [ -n "${ARTIFACTORY_DOCKER_REGISTRY_USER}" ] && DOCKER_REGISTRY_USER=${ARTIFACTORY_DOCKER_REGISTRY_USER}
        [ -n "${ARTIFACTORY_DOCKER_REGISTRY_PASSWORD}" ] && DOCKER_REGISTRY_PASSWORD=${ARTIFACTORY_DOCKER_REGISTRY_PASSWORD}
    else
        [ -n "${DOCKERHUB_DOCKER_REGISTRY_USER}" ] && DOCKER_REGISTRY_USER=${DOCKERHUB_DOCKER_REGISTRY_USER}
        [ -n "${DOCKERHUB_DOCKER_REGISTRY_PASSWORD}" ] && DOCKER_REGISTRY_PASSWORD=${DOCKERHUB_DOCKER_REGISTRY_PASSWORD}
    fi

    [ -n "${DOCKER_REGISTRY_USER}" ] || bbnote "DOCKER_REGISTRY_USER not set"
    [ -n "${DOCKER_REGISTRY_PASSWORD}" ] || bbnote "DOCKER_REGISTRY_PASSWORD not set"
}

set_credentials() {
    set CREDS=""
    if [ -n "${DOCKER_REGISTRY_USER}" ] && [ -n "${DOCKER_REGISTRY_PASSWORD}" ]; then
        CREDS="--creds=${DOCKER_REGISTRY_USER}:${DOCKER_REGISTRY_PASSWORD}"
    fi
}

get_container_name() {
    CONTAINER_NAME="$(echo ${IMAGE} | tr / _ )"
}

get_archive_name() {
    ARCHIVE_NAME="$(echo ${UNAME} | tr / _ )#$(echo ${IMAGE} | tr / _ )#${TAG}#$(echo ${SHAHASH} | cut -d':' -f2)"
}

do_pull_image() {

    check_configuration
    check_credentials
    set_credentials  

    # Specify the PATH env variable allowing Bitbake:
    # - to look for podman binary as /usr/bin is not defined in the originally PATH env
    # variable.
    # - to call /usr/bin/newgidmap and /usr/bin/newuidmap binaries which
    # set uid and gid mapping of a user namespace.

    if ! PATH=/usr/bin:${PATH} podman pull ${CREDS} "${REGISTRY}/${UNAME}/${IMAGE}@${SHAHASH}"; then
        bbfatal "Error pulling ${REGISTRY}/${UNAME}/${IMAGE}@${SHAHASH}"
    fi
}

do_tag_image() {
    check_configuration

    if ! PATH=/usr/bin:${PATH} podman tag "${REGISTRY}/${UNAME}/${IMAGE}@${SHAHASH}" "${UNAME}/${IMAGE}:${TAG}"; then
        bbfatal "Error tagging ${UNAME}/${IMAGE}:${TAG}"
    fi
}

do_save_image() {
    check_configuration
    get_archive_name

    mkdir -p "${STORE_DIR}"
    archive="${ARCHIVE_NAME}.tar"

    if [ -f "${WORKDIR}/${archive}" ]; then
        bbnote "Removing the archive ${STORE_DIR}/${archive}"
        rm "${WORKDIR}/${archive}"
    fi

    if [ -f "${WORKDIR}/${archive}.gz" ]; then
        bbnote "Removing the compressed archive ${STORE_DIR}/${archive}"
        rm "${WORKDIR}/${archive}.gz"
    fi

    if ! PATH=/usr/bin:${PATH} podman save --storage-driver vfs "${IMAGE}:${TAG}" \
        -o "${WORKDIR}/${archive}"; then
        bbfatal "Error saving ${IMAGE}:${TAG} container"
    fi

    if ! PATH=/usr/bin:${PATH} gzip "${WORKDIR}/${archive}"; then
        bbfatal "Error compressing ${IMAGE}:${TAG} container"
    fi
}

do_install() {
    check_configuration
    get_archive_name
    get_container_name

    install -d "${D}${datadir}/container-images"

    archive="${ARCHIVE_NAME}.tar.gz"
    [ -f "${WORKDIR}/${archive}" ] || bbfatal "${archive} does not exist"

    if [ "${EXTRACT_CONTAINER}" != "True" ]; then
        install -m 0400 "${WORKDIR}/${archive}" "${D}${datadir}/container-images/"
        rm -rf ${WORKDIR}/tmpextract
        mkdir ${WORKDIR}/tmpextract
        rm -rf ${WORKDIR}/${CONTAINER_NAME}
        mkdir ${WORKDIR}/${CONTAINER_NAME}
        tar -C ${WORKDIR}/tmpextract --wildcards -xvf ${WORKDIR}/${archive} *.tar
        for f in ${WORKDIR}/tmpextract/*.tar; do tar xf "$f" -C ${WORKDIR}/${CONTAINER_NAME}; done
        mkdir -p ${WORKDIR}/${CONTAINER_NAME}/licenses
        mkdir -p ${D}/usr/share/licenses
        cp -rf ${WORKDIR}/${CONTAINER_NAME}/licenses ${D}/usr/share/licenses/container-${CONTAINER_NAME}
    else
        rm -rf ${WORKDIR}/tmpextract
        mkdir ${WORKDIR}/tmpextract
        rm -rf ${WORKDIR}/${CONTAINER_NAME}
        mkdir ${WORKDIR}/${CONTAINER_NAME}
        tar -C ${WORKDIR}/tmpextract --wildcards -xvf ${WORKDIR}/${archive} *.tar
        for f in ${WORKDIR}/tmpextract/*.tar; do tar xf "$f" -C ${WORKDIR}/${CONTAINER_NAME}; done
        cp -R "${WORKDIR}/${CONTAINER_NAME}" "${D}${datadir}/container-images/"
    fi
}

# The order should be:
# 1. do_fetch
# 2. do_pull_image
# 3. do_tag_image
# 4. do_save_image
# 5. do_install
addtask pull_image before do_tag_image after do_fetch
addtask tag_image before do_save_image after do_pull_image
addtask save_image before do_install after do_tag_image

FILES_${PN} = "${datadir}/container-images \
               /usr/share/licenses \
              "