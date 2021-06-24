SUMMARY = "Load embedded container archives into the system"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI = "file://container-load.sh file://container-load.service"


RDEPENDS_${PN} = "docker bash"
REQUIRED_DISTRO_FEATURES= "systemd"

inherit systemd
SYSTEMD_SERVICE_${PN} = "container-load.service"
SYSTEMD_AUTO_ENABLE_${PN} = "enable"

do_install() {
    install -d "${D}${systemd_unitdir}/system"
    install -m 0644 "${WORKDIR}/container-load.service" "${D}${systemd_unitdir}/system"
    install -d "${D}${bindir}"
    install -m 0755 "${WORKDIR}/container-load.sh" "${D}${bindir}/container-load"
}
