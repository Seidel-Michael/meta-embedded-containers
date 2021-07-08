# Meta-embedded-containers layer

## Description

The meta-embedded-containers provides different approaches to embed Docker
container(s) into a target root filesystem with Yocto.

The first approach is to embed a Docker archive in the root filesystem.

The second approach is to populate the Docker store (i.e.
/var/lib/docker directory) into the target root filesystem.

The original approaches are documented here:
https://blog.savoirfairelinux.com/en-ca/2020/containers-on-linux-embedded-systems/
https://blog.savoirfairelinux.com/en-ca/2020/integrating-container-image-in-yocto/

This layer extended the approaches with container classes and the ability to automatically download the newest image from an Artifactory Repository.

## Dependencies

URI: git://git.openembedded.org/meta-openembedded
Branch: zeus

URI: git://git.yoctoproject.org/cgit/cgit.cgi/poky
Branch: zeus

## Adding the meta-embedded-container layer to your build

Please run the following command:

$ bitbake-layers add-layer meta-embedded-containers

## Documentation

For the oroginal approaches the process is documented in these Blog Posts.
https://blog.savoirfairelinux.com/en-ca/2020/containers-on-linux-embedded-systems/
https://blog.savoirfairelinux.com/en-ca/2020/integrating-container-image-in-yocto/


For the new approach you can add new containers by cloning the `recipes-docker-container/hello-world/hello-world-container.bb` recipe.
`REGISTRY` defines the URL to the registry to pull from. The official Registry is `registry.hub.docker.com`.-
`UNAME` defines the username where the image is stored in.
`IMAGE` defines the name of the image to pull.
`SHAHASH` defines the SHA256 hash of the image to pull. This has to be the hash of the correct architecture. e.g. `sha256:50b8560ad574c779908da71f7ce370c0a2471c098d44d1c8f6b513c5a55eeeb1`.
`TAG` defines how to tag the image on the target device. This has nothing to do with the image that is pulled. This is only defined by the `SHAHASH`.

You also have to install `container-load` to your image to automatically load all installed containers on boot. The script only loads the image if it is not loaded already and remove any other version of the image.

## Customize your image recipe

The image recipe is located under
`recipes-core/images/embedded-container-image.bb` file. In the
IMAGE_INSTALL Bitbake variable, you can customize which kind of approach
you want:
- container-image: pull the container image(s) and install the Docker
  store in the target root filesystem,
- container-archive: pull the container image(s) and save the container
  archive(s) in the rootfs,
- container-multiple-archives: pull the container image(s), save them in
  the rootfs as archive files and start them with docker-compose at
boot.

For the alternative approach you have to add every image you need in your image and container-load to IMAGE_INSTALL.
