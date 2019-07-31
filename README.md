# Pluto_CC_Docker
A docker environment for PlutoSDR firmware build and cross compilation + tools &amp; scripts

This repository gives instructions on how to build a (docker) environment for (cross-)compiling PlutoSDR firmware and tools.

!!! WORK IN PROGRESS !!!

In current state, the `docker build` command will install everything required for plutSDR firmware compilation and compile it.
No cross compilation or anything else tested yet.

!!! WORK IN PROGRESS !!!
 

Limitations
-----------

It is based on instructions provided by Analog Devices (AD) [here](https://wiki.analog.com/university/tools/pluto/building_the_image).

In theory, having a docker environment setup is nice because:
 - you can directly share the binary image with others or use it on different machines
 - you can provide Dockerfile to people for customizing and re-building it easily

Unfortunately, both of these advantages are defeated because Xilinx Vivado SDK is a HUGE package (~20GB) that requires a license (registration required for downloading, personal information collected), and because its setup process is not 'Docker-friendly'.

Because I work with various environments, I provide here instructions on how to create your own docker image but I cannot directly share the result here or on DockerHub.
Hope it helps anyway.


Setup container: instructions
-----------------------------

Because of previously mentioned limitations, the process of building the image is more 'convoluted' than a simple `docker build` command.
If one is not interested in using Docker, he can just follow instructions/commands from Dockerfile or [AD website](https://wiki.analog.com/university/tools/pluto/building_the_image) and ignore all docker-specific steps.


##### 1. Make sure Docker storage folder can handle large images (~85GB temporarily, ~37GB final)

By default, docker images are stored in `/var/lib/docker/`. You can check how much space is available there using the command `df -h /var/lib`.
If you run out of space on this partition, you might want to follow [these instructions](https://blog.adriel.co.nz/2018/01/25/change-docker-data-directory-in-debian-jessie/) for moving the 'Docker Root Dir' somewhere else.   


##### 2. Define which 'Xilinx SDK' version you need

You can check manually from the [repository website](https://github.com/analogdevicesinc/plutosdr-fw), in `hdl` submodule (be sure to follow the link to the correct branch), you can open the file `hdl/projects/scripts/adi_project.tcl`.
You should find a constant named `REQUIRED_VIVADO_VERSION`. In current example, the associated value is "2018.2".

If you already cloned the repository somewhere (why not), you can use the command provided by AD to search for this value:
`grep "set REQUIRED_VIVADO_VERSION" YoUr_RePo_FoLdEr/plutosdr-fw/hdl/projects/scripts/adi_project.tcl`


##### 3. Download Xilinx SDK 

Xilinx Vivado SDK is a huge (~20GB) and not 'free to use' package so you will need to register on their website before downloading it.
In the archive download section, you will find files for the appropriate version of SDK.
You need to download the archive `Vivado HLx : All OS installer Single-File Download (TAR/GZIP ~18 GB)` and move it next to the Dockerfile.

You would only need to add eventual updates if they mention the plutoSDR SoC `Zynq Z-7010` (unlikely).


##### 4. Build the image

For the current example, let's use the name `pluto_env_0.31` as docker image tag.
Just run `docker build 'github.com/rfenouil/Pluto_CC_Docker' -t YoUr_ChOiCe/pluto_env_0.31`
Get lunch...



SIDE NOTES AND COMMANDS
-----------------------

#### Delete (huge) intermediate image

This Dockerfile uses a multi-stage build to:
 - stage 1: import SDK 'tar.gz' archive, extract it, and install SDK
 - stage 2: install other dependencies and compile firmware

The first stage build generates a huge (~50GB) intermediate image from which only the required folders are copied to second stage.
Once the build is done, it is therefore recommended to delete the intermediate image in order to get this storage space back (using `docker rmi -f ImAgE_Id` command).  


#### Extract required SDK version from FW source in container:
`docker run YoUrChOiCe/pluto_env_0.31 grep "set REQUIRED_VIVADO_VERSION" /repos/plutosdr-fw/hdl/projects/scripts/adi_project.tcl`


#### Alternative method for creating Docker image

While provided instructions are the easiest method for creating the docker image, an alternative option can be used to generate a similar image with a smaller footprint in 'Docker storage folder' (see point 1 above) during the creation process (final image size is identical).   

Instead of using a first build stage to import and extract the large archive (which generates a massive intermediate image), one can remove this stage from the Dockerfile to install only firmware dependencies and source.

SDK archive will be inflated manually on the host machine in a separate folder (Let's say `~/Downloads/XilinxSDK/`).    

Then, an interactive container session will be used to install the SDK manually from a mounted volume (where SDK archive has been inflated). Finally, this container can be committed and saved as a new image (not very clean but should do the job...). 

`docker run -it -v "~/Downloads/XilinxSDK:/externalFiles/XilinxSDK" YoUrChOiCe/pluto_env_0.31`

Inside container:
`/externalFiles/XilinxSDK/Xilinx_Vivado_SDK_2018.2_*/xsetup -b Install -e "Vivado HL WebPACK" -l /opt/Xilinx --agree XilinxEULA,3rdPartyEULA,WebTalkTerms`

Eventually add environment variables and compile firmware (see Dockerfile).

Finally, commit the container to a new image using: `docker commit <container_name> <final-image-name>:<tag>`

You can now remove the container used for installation.


