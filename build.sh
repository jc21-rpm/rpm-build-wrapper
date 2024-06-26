#!/bin/bash

##################################################
#
# ./build EL_VERSION [DOCKER_TAG] [SPEC_FILE]
#
# If no docker tag, `latest` is used
# If no Spec file (without .spec), all spec files
# found will be built.
#
# ie:
# ./build 8
#
##################################################

set +x

CWD=$(pwd)
CYAN='\E[1;36m'
RED='\E[1;31m'
YELLOW='\E[1;33m'
GREEN='\E[1;32m'
BLUE='\E[1;34m'
RESET='\E[0m'

EL_VERSION=$1
if [ "$EL_VERSION" == "" ]; then
	echo -e "${RED}ERROR: You must specify a EL version to build for, either 8 or 9"
	echo -e "ie: ./build 7${RESET}"
	exit 1
fi

DOCKER_TAG=$2
if [ "$DOCKER_TAG" == "" ]; then
	DOCKER_TAG=latest
fi

SPECIFIC_SPEC_FILE=$3

# Loop over all Specs in the SPECS folder
for SPECFILE in SPECS/*.spec; do
	PACKAGE=${SPECFILE#"SPECS/"}
	PACKAGE=${PACKAGE%".spec"}

	if [ "${SPECIFIC_SPEC_FILE}" == "" ] || [ "${SPECIFIC_SPEC_FILE}" == "${PACKAGE}" ]; then
		echo -e "${BLUE}❯ ${GREEN}Building ${CYAN}${PACKAGE} ${GREEN}for EL ${EL_VERSION}${RESET}"

		# Make sure docker exists
		if hash docker 2>/dev/null; then
			# Generate a Docker image based on env vars and rocky version, for use both manually and in CI
			eval "DOCKER_IMAGE=\$\{DOCKER_RPMBUILD_EL${EL_VERSION}:-jc21/rpmbuild-rocky${EL_VERSION}\}"
			eval "DOCKER_IMAGE=${DOCKER_IMAGE}"

			# Folder setup
			echo -e "${BLUE}❯ ${YELLOW}Folder setup${RESET}"
			rm -rf RPMS/* SRPMS/*
			mkdir -p {RPMS,SRPMS,DEPS,SPECS,SOURCES}
			chmod -R 777 {RPMS,SRPMS}

			# Pull latest builder image
			echo -e "${BLUE}❯ ${YELLOW}Pulling docker image: ${DOCKER_IMAGE}:${DOCKER_TAG}${RESET}"
			docker pull "${DOCKER_IMAGE}:${DOCKER_TAG}"

			# Use the build to change the ownership of folders
			echo -e "${BLUE}❯ ${YELLOW}Temporarily changing ownership${RESET}"
			docker run --rm \
				-v "${CWD}:/home/rpmbuilder/rpmbuild" \
				"${DOCKER_IMAGE}:${DOCKER_TAG}" \
				sudo chown -R rpmbuilder:rpmbuilder /home/rpmbuilder/rpmbuild

			# Do the build
			echo -e "${BLUE}❯ ${YELLOW}Building ${PACKAGE}${RESET}"

			DISABLE_MIRROR=
			if [ -n "$NOMIRROR" ]; then
				DISABLE_MIRROR=-m
			fi

			# Docker Run
			RPMBUILD=/home/rpmbuilder/rpmbuild
			docker run --rm \
				--name "rpmbuild-${BUILD_TAG:-${EL_VERSION}-${PACKAGE}}" \
				-v "${CWD}/DEPS:${RPMBUILD}/DEPS" \
				-v "${CWD}/RPMS:${RPMBUILD}/RPMS" \
				-v "${CWD}/SRPMS:${RPMBUILD}/SRPMS" \
				-v "${CWD}/SPECS:${RPMBUILD}/SPECS" \
				-v "${CWD}/SOURCES:${RPMBUILD}/SOURCES" \
				-e "GOPROXY=${GOPROXY}" \
				"${DOCKER_IMAGE}:${DOCKER_TAG}" \
				/bin/build-spec ${DISABLE_MIRROR} -n -o -r /home/rpmbuilder/rpmbuild/DEPS/*/*.rpm -- "/home/rpmbuilder/rpmbuild/SPECS/${PACKAGE}.spec"

			BUILD_SUCCESS=$?

			# Change ownership back
			echo -e "${BLUE}❯ ${YELLOW}Reverting ownership${RESET}"
			docker run --rm \
				-v "${CWD}:/home/rpmbuilder/rpmbuild" \
				"${DOCKER_IMAGE}:${DOCKER_TAG}" \
				sudo chown -R "$(id -u):$(id -g)" /home/rpmbuilder/rpmbuild

			# do we need to exit the loop?
			if [ $BUILD_SUCCESS -ne 0 ]; then
				echo -e "${BLUE}❯ ${RED}Exiting due to error${RESET}"
				exit ${BUILD_SUCCESS}
			fi
		else
			echo -e "${RED}ERROR: Docker command is not available${RESET}"
			exit 1
		fi
	fi
done
