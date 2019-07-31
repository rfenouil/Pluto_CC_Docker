########################################################
# Build and cross-compile environment for Pluto SDR FW #
########################################################
#
# Based on Analog Devices documentation:
# - https://wiki.analog.com/university/tools/pluto/building_the_image
#
# This is a multi-stage build:
# - First stage imports Vivado SDK archive and installs it
# - Second stage imports SDK installation folder and compiles plutoSDR firmware
#
# 'VERSION_XILINX_SDK' value must match with the version required for firmware 
# compilation (see doc). The SDK 'tar.gz' archive expected in the build context 
# must of course match with this version too and with the naming scheme:
# 'Xilinx_Vivado_SDK_${VERSION_XILINX_SDK}_*'
#
# Version: 0.1
# Date: 2019/07
#



#### Define global ARGs accessible by all stages of multi-stage build

ARG VERSION_XILINX_SDK=2018.2
ARG DIR_XILINX_SDK=/opt/Xilinx






#### Create a first 'stage' for installing Xilinx SDK
 
FROM ubuntu:18.04 as SDK_INSTALL 

# Expected ARGs
ARG VERSION_XILINX_SDK
ARG DIR_XILINX_SDK



#### Install required Vivado Design suite and SDK
# Because Xilinx don't allow direct download of their SDK (account required),
# this Dockerfile imports and extracts it from external archive using 'ADD'.
# It is therefore assumed that you previously download the required archive
# from Xilinx website and put it in Dockefile folder:
# - Vivado Design Suite (All OS installer Single-File Download: ~20GB tar.gz)
# See documentation to find which version you need.

# Import files from downloaded archive
ADD Xilinx_Vivado_SDK_*.tar.gz /externalFiles/Xilinx/

# Run the installer in batch mode
RUN /externalFiles/Xilinx/Xilinx_Vivado_SDK_${VERSION_XILINX_SDK}_*/xsetup -b Install -e "Vivado HL WebPACK" -l ${DIR_XILINX_SDK} --agree XilinxEULA,3rdPartyEULA,WebTalkTerms 

# Remove the SDK installation files (should not really help because layers are stored anyway, multi-stage build might help however)
RUN rm -rf /externalFiles






#### Create the image based on SDK stage (not storing the heavy ADD layer)

FROM ubuntu:18.04
MAINTAINER Romain Fenouil <rfenouil@gmail.com>

# Expected ARGs
ARG VERSION_XILINX_SDK
ARG DIR_XILINX_SDK

# Copy result of SDK installation from previous stage
COPY --from=SDK_INSTALL ${DIR_XILINX_SDK} ${DIR_XILINX_SDK}



#### Install apt dependencies
# Added git to recommended list for cloning repositories

RUN apt-get update \
    && apt-get -y install build-essential \
                          ccache \
                          device-tree-compiler \
                          dfu-util \
                          fakeroot \
                          git \
                          help2man \
                          libncurses5-dev \
                          libssl1.0-dev \
                          mtools \
                          rsync \
                          u-boot-tools \
                          bc python \
                          cpio \
                          zip \
                          unzip \
                          file \
                          wget
                    


#### Clone main Pluto FW repository
# Includes appropriate branches from git-submodules:
#  - Linux Kernel
#  - FPGA HDL
#  - Buildroot User Space
#  - u-boot Bootloader

ENV DIR_PLUTO_FW_SOURCE /repos/plutosdr-fw

RUN git clone --recursive https://github.com/analogdevicesinc/plutosdr-fw.git ${DIR_PLUTO_FW_SOURCE}



#### Set environment variables for build

ENV CROSS_COMPILE=arm-linux-gnueabihf-
ENV PATH="${PATH}:${DIR_XILINX_SDK}/SDK/${VERSION_XILINX_SDK}/gnu/aarch32/lin/gcc-arm-linux-gnueabi/bin"
ENV VIVADO_SETTINGS=${DIR_XILINX_SDK}/Vivado/${VERSION_XILINX_SDK}/settings64.sh



#### Build firmware

RUN cd ${DIR_PLUTO_FW_SOURCE} && make -j 30



