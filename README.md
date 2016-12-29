# Tensorflow-Android

Build : docker build - < Dockerfile

Usage: docker run -it --privileged -v /dev/bus/usb:/dev/bus/usb -v HOST_SHARED_PATH:/shared iMAGE bash

Docker provides:
> Complete Tensorflow-Android environment for custom APK and Benchmark binaries generation and installation.
> Generated Benchmark Binaries and Tensorflow Demo APKs.
> SDK API Level: Android-23 and build-tools-23.0.1

In Dockerfile, I have listed commands to build custom APK and install them into the phone from Docker itself.You can go through the dockerfile and follow these.bb 
