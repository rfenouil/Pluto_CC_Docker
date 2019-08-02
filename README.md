# Pluto_CC_Docker

This repository gives instructions to build a (docker) environment for (cross-)compiling PlutoSDR firmware and tools.

It is based on instructions provided by Analog Devices (AD) [here](https://wiki.analog.com/university/tools/pluto/building_the_image).  
Thank you to [Lama_Bleu](https://twitter.com/fonera_cork) for his work and support, and [unixpunk](https://github.com/unixpunk) for having started it all with [PlutoWeb](https://github.com/unixpunk/PlutoWeb).

__!!! WORK IN PROGRESS !!!__  
In current state, the `docker build` command will install everything required for plutSDR firmware compilation and compile it.
No cross compilation or anything else tested yet.
 

Limitations
-----------

In theory, having a docker environment setup is nice because:
 - you can directly share the binary image with others, or use it on different machines
 - you can provide Dockerfile to people for customizing and re-building it easily

Unfortunately, both of these advantages are defeated because Xilinx Vivado SDK is a HUGE package (~20GB) that requires a license (registration required for downloading, personal information collected), and because its setup process is not 'Docker-friendly'.

However, an interesting advantage of using docker is that I can come back to a fresh/clean firmware build by simply starting a new container. That proved to be helpful after I started messing too much with buildroot and kernel config files :)

I provide instructions on how to create and use your own docker image but I cannot directly share the result here or on DockerHub (Xilinx SDK).
Hope it helps anyway.


Setup container: instructions
-----------------------------

Because of previously mentioned limitations, the process of building the image is more 'convoluted' than a simple `docker build` command.  
If one is not interested in using docker, he can just follow instructions/commands from Dockerfile or [AD website](https://wiki.analog.com/university/tools/pluto/building_the_image) and ignore all docker-specific steps.


#### 1. Make sure docker storage folder can handle large images (~85GB temporarily, ~37GB final)

By default, docker images are stored in: `/var/lib/docker/`  
You can check how much space is available there using the command: `df -h /var/lib`  
If you run out of space on this partition, you might want to follow [these instructions](https://blog.adriel.co.nz/2018/01/25/change-docker-data-directory-in-debian-jessie/) for moving the 'Docker Root Dir' somewhere else.   


#### 2. Define which 'Xilinx SDK' version you need

You can check manually from the [repository website](https://github.com/analogdevicesinc/plutosdr-fw).  
In `hdl` submodule (be sure to follow the link to the correct branch), you can open the file: `hdl/projects/scripts/adi_project.tcl`  
You should find a constant named `REQUIRED_VIVADO_VERSION`. In current example, the associated value is: `2018.2`

If you already cloned the repository somewhere (why not), you can use the command provided by AD to search for this value:  
`grep "set REQUIRED_VIVADO_VERSION" YoUr_RePo_FoLdEr/plutosdr-fw/hdl/projects/scripts/adi_project.tcl`


#### 3. Download Xilinx SDK 

Xilinx Vivado SDK is a huge (~20GB) and not 'free to use' package so you will need to register on their website before downloading it.  
In the archive download section, you will find files for the appropriate version of SDK.  
You need to download the archive: `Vivado HLx : All OS installer Single-File Download (TAR/GZIP ~18 GB)` and move it into the build context (next to the Dockerfile).

You need to add eventual updates only if they mention the plutoSDR SoC `Zynq Z-7010` (unlikely).


#### 4. Build the image

For the current example, let's use the name `pluto_env_0.31` as docker image tag.

Just run: `docker build ./YoUrFoLdEr -t rfenouil/pluto_env_0.31`

It can take between 1 and 2 hours to complete.


#### NOTE: Delete (huge) intermediate image

This Dockerfile uses a multi-stage build to:
 - stage 1: import SDK 'tar.gz' archive, extract it, and install SDK
 - stage 2: install other dependencies and compile firmware

The first stage build generates a huge (~48GB) intermediate image from which only the required folders are copied to second stage. Once the build is done, it is recommended to delete the intermediate image in order to recover some disk space (using `docker rmi -f ImAgE_Id` command).  


#### NOTE: Alternative method for creating docker image

While provided instructions is the easiest option for creating the docker image, an alternative method can be used to generate a similar image with a smaller footprint in 'Docker storage folder' (see point 1 above) during the creation process (final image size is identical).   

Instead of using a first build stage to import and extract the large archive (which generates a massive intermediate image), one can remove this stage from the Dockerfile to install only firmware dependencies and source.

SDK archive will be inflated manually on the host machine in a separate folder (Let's say `~/Downloads/XilinxSDK/`).    

Then, an interactive container session will be used to install the SDK manually from a mounted volume (where SDK archive has been inflated). Finally, this container can be committed and saved as a new image (not very clean but should do the job...). 

`docker run -it -v "~/Downloads/XilinxSDK:/externalFiles/XilinxSDK" rfenouil/pluto_env_0.31`

Install SDK inside the container:  
`/externalFiles/XilinxSDK/Xilinx_Vivado_SDK_2018.2_*/xsetup -b Install -e "Vivado HL WebPACK" -l /opt/Xilinx --agree XilinxEULA,3rdPartyEULA,WebTalkTerms`

Eventually add environment variables and compile firmware (see Dockerfile).

Finally, commit the container to a new image using: `docker commit <container_name> <final-image-name>:<tag>`

You can now remove the container used for installation.


Use container to customize firmware
-----------------------------------

### General

Once the final docker image is built, you can run a container instance using an interactive session:  
`docker run --name myCustomFW -it rfenouil/pluto_env_0.31`

A firmware with default configuration is compiled during the docker image build. You can check resulting files __inside the container__:  
`ls -lh /repos/plutosdr-fw/build`

It includes everything you need for flashing your device (frm/dfu files), and more...

The `docker cp` command is a convenient way to extract the compiled firmware files to host filesystem. In the host shell (__not__ from container):  
`docker cp myCustomFW:/repos/plutosdr-fw/build/pluto.frm ./`

Then you just need to copy that in the pluto share, eject the USB device, and it is flashing already :)


### Customize buildroot configuration

Pluto firmware is based on the 'buildroot' linux distribution.
You can customize it before compilation to include or remove packages, change options, etc...

In the following example, we add 'python3' package to the distribution.

In the container instance:

```
 # Set current directory to buildroot submodule
 cd /repos/plutosdr-fw/buildroot/

 # Copy the previously used configuration to '.config' file
 make oldconfig
 
 # Start customization
 make menuconfig
```

In the menu appearing, change the desired options using arrows, enter, 'y' and 'n' keys.  
The package 'python3' is located in: `> Target packages > Interpreter languages and scripting`  
Highlight it and press 'y'. You can also select python-specific modules (pip, numpy, ...) in submenus appearing below if you want.

Then, exit from menus until you quit the configuration program, it will save the updated configuration in the text file: `.config`

Pluto firmware compilation uses the configuration file `/repos/plutosdr-fw/buildroot/configs/zynq_pluto_defconfig`, so we need to replace it by the one we just generated and we can start the compilation:

```
 # Update the config file used by pluto firmware
 cp .config configs/zynq_pluto_defconfig

 # Come back to the firmware root folder (/repos/plutosdr-fw) 
 cd ..
 
 # Start compilation
 make
```

It can take some time depending on what you selected.  
Once done, you will find the new firmware files in: `/repos/plutosdr-fw/build`

Ready for flashing (see `docker cp` command to extract it from the container) !


#### NOTE: Firmware size 

Adding 'python3' (without any module) increased the firmware size (frm) from ~10 to ~17MB. It is important to know that the available space for flashing the firmware is limited.  
Max firmware size depends on device, but most of them (including mine) cannot handle a firmware file larger than 22MB (unless you do some tricky hacks).
It is therefore useless to add all packages in your firmware, you will not be able to flash it... Just pick the ones you need.


#### NOTE: Removing packages

While you keep playing with customization, you might use `make menuconfig` command again, and unselect 'python3' to free some space.
As seen before, the new configuration is saved to `.config` and you copy it over the `configs/zynq_pluto_defconfig` file.
If you restart the firmware compilation after that, you might be surprised... The firmware is as big as before, and still contains 'Python3'' (you can flash it to check).  
It is important to clean the build when you remove some package from configuration, otherwise the previously-compiled files will be added anyway. Use the command `make clean` from the buildroot folder before compiling the firmware again.

In the same concern however, because cleaning the build removes every file generated during compilation, the next `make` command will take much longer to regenerate all binaries (selected packages, but also the buildroot core).  
In this case, it might be more convenient to exit from the current container and restart another one from the same docker image. It contains the firmware build with default options (nothing added) generated when the docker image was being built. That can save you some time (if your container was named, you will have to delete it using `docker rm myCustomFW` before starting a new one with identical name)...  
It might also be safer in case some package do not cleanup properly.  
It does not help if you want to remove things included in the default configuration though...


#### PACKAGES NOTES

##### python3
Location: `> Target packages > Interpreter languages and scripting`  
Adds to FW size: ~7MB (no module)

##### python-pip (python3)
Location: `> Target packages > Interpreter languages and scripting > External python modules`  
Adds to FW size: ~3.2MB (including `ssl`)  
Should require module `ssl` in `> Target packages > Interpreter languages and scripting > core python3 modules` to work properly.

##### tmux
Location: `> Target packages > Shell and utilities`  
Adds to FW size: ~1.3MB (including locale)  
Requires to replace `en_US` by `en_US.UTF-8` in `> System configuration > Locales to keep` and add `en_US.UTF-8` to  `> System configuration > Generate locale data`.


#### FINAL NOTES (buildroot)

Buildroot documentation is great, go read it and report mistakes I make/write.

Use `make help` command to do more things.

Enjoy.


### Customize linux kernel

TODO