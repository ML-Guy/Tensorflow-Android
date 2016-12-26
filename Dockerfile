### Usage: docker run -it --privileged -v /dev/bus/usb:/dev/bus/usb -v HOST_SHARED_PATH:/shared iMAGE bash
###############################################################################################
###			SECTION 1- Install required SDK and NDK 
###############################################################################################
# Copyright 2010-2016, Google Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution.
#     * Neither the name of Google Inc. nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

FROM ubuntu:14.04.5

ENV DEBIAN_FRONTEND noninteractive

# Package installation
RUN apt-get update
## Common packages for linux build environment
RUN apt install -y clang python pkg-config git curl bzip2 unzip make
## Packages for linux desktop version
RUN apt install -y libibus-1.0-dev libglib2.0-dev qtbase5-dev libgtk2.0-dev libxcb-xfixes0-dev
## Packages for Android
RUN apt install -y --no-install-recommends openjdk-7-jdk openjdk-7-jre-headless libjsr305-java ant zip libc6-i386 lib32stdc++6 lib32ncurses5 lib32z1
## Packages for NaCl
RUN apt install -y libc6-i386 lib32stdc++6
## For emacsian
RUN apt install -y emacs

ENV HOME /home/mozc_builder
RUN useradd --create-home --shell /bin/bash --base-dir /home mozc_builder
#USER mozc_builder

# SDK setup
RUN mkdir -p /home/mozc_builder/work
WORKDIR /home/mozc_builder/work

## Android SDK/NDK
RUN curl -LO http://dl.google.com/android/repository/android-ndk-r12b-linux-x86_64.zip && unzip android-ndk-r12b-linux-x86_64.zip && rm android-ndk-r12b-linux-x86_64.zip
RUN curl -L http://dl.google.com/android/android-sdk_r24.1.2-linux.tgz | tar -zx
ENV ANDROID_NDK_HOME /home/mozc_builder/work/android-ndk-r12b
ENV ANDROID_HOME /home/mozc_builder/work/android-sdk-linux
ENV PATH $PATH:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools:${ANDROID_NDK_HOME}
RUN echo y | android update sdk --all --force --no-ui --filter android-23
RUN echo y | android update sdk --all --force --no-ui --filter build-tools-23.0.1
RUN echo y | android update sdk --all --force --no-ui --filter extra-android-support
RUN echo y | android update sdk --all --force --no-ui --filter platform-tool

## NaCl SDK
RUN curl -LO http://storage.googleapis.com/nativeclient-mirror/nacl/nacl_sdk/nacl_sdk.zip && unzip nacl_sdk.zip && rm nacl_sdk.zip
RUN cd nacl_sdk && ./naclsdk install pepper_49
ENV NACL_SDK_ROOT /home/mozc_builder/work/nacl_sdk/pepper_49

## depot_tools for Ninja prebuilt
RUN git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
ENV PATH $PATH:/home/mozc_builder/work/depot_tools

# check out Mozc source with submodules
RUN git clone https://github.com/google/mozc.git -b master --single-branch --recursive

###############################################################################################
###			SECTION 2 - Install Tensorflow Dependencies 
###############################################################################################

ENV JAVA_HOME /usr/lib/jvm/java-1.8.0-openjdk-amd64
ENV NDK_ROOT /home/mozc_builder/work/android-ndk-r12b/
ENV ANDROID_API_LEVEL 23
ENV ANDROID_BUILD_TOOLS_VERSION 23.0.1
ENV ANDROID_SDK_HOME ${ANDROID_HOME}
#ENV ANDROID_NDK_HOME ${ANDROID_NDK_HOME}

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        git \
        libcurl3-dev \
        libfreetype6-dev \
        libpng12-dev \
        libzmq3-dev \
        pkg-config \
        python-dev \
        rsync \
        software-properties-common \
        unzip \
        zip \
        zlib1g-dev \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y autoconf automake pkg-config libgtk-3-dev libtool maven vim

RUN curl -fSsL -O https://bootstrap.pypa.io/get-pip.py && \
    python get-pip.py && \
    rm get-pip.py

RUN pip --no-cache-dir install \
        ipykernel \
        jupyter \
        matplotlib \
        numpy \
        scipy \
        sklearn \
        && \
    python -m ipykernel.kernelspec

## Set up our notebook config.
#COPY jupyter_notebook_config.py /root/.jupyter/
#
## Jupyter has issues with being run directly:
##   https://github.com/ipython/ipython/issues/7062
## We just add a little wrapper script.
#COPY run_jupyter.sh /

# Set up Bazel.

# We need to add a custom PPA to pick up JDK8, since trusty doesn't
# have an openjdk8 backport.  openjdk-r is maintained by a reliable contributor:
# Matthias Klose (https://launchpad.net/~doko).  It will do until
# we either update the base image beyond 14.04 or openjdk-8 is
# finally backported to trusty; see e.g.
#   https://bugs.launchpad.net/trusty-backports/+bug/1368094
RUN add-apt-repository -y ppa:openjdk-r/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends openjdk-8-jdk openjdk-8-jre-headless && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Running bazel inside a `docker build` command causes trouble, cf:
#   https://github.com/bazelbuild/bazel/issues/134
# The easiest solution is to set up a bazelrc file forcing --batch.
RUN echo "startup --batch" >>/root/.bazelrc
# Similarly, we need to workaround sandboxing issues:
#   https://github.com/bazelbuild/bazel/issues/418
RUN echo "build --spawn_strategy=standalone --genrule_strategy=standalone" \
    >>/root/.bazelrc
ENV BAZELRC /root/.bazelrc
# Install the most recent bazel release.
ENV BAZEL_VERSION 0.4.2
WORKDIR /
RUN mkdir /bazel && \
    cd /bazel && \
    curl -fSsL -O https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
    curl -fSsL -o /bazel/LICENSE.txt https://raw.githubusercontent.com/bazelbuild/bazel/master/LICENSE.txt && \
    chmod +x bazel-*.sh && \
    ./bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
    cd / && \
    rm -f /bazel/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh


###############################################################################################
###			SECTION 3 - Download tensorflow 
###############################################################################################
# Download TensorFlow.

RUN git clone https://github.com/tensorflow/tensorflow.git && \
    cd tensorflow && \
    git checkout r0.12
WORKDIR /tensorflow

ENV CI_BUILD_PYTHON python
RUN tensorflow/contrib/makefile/download_dependencies.sh

# Build TensorFlow : Not required for apk compilation. Uncomment following if you still require standalone tf

## TODO(craigcitro): Don't install the pip package, since it makes it
## more difficult to experiment with local changes. Instead, just add
## the built directory to the path.
#
#
#RUN tensorflow/tools/ci_build/builds/configured CPU \
#    bazel build -c opt tensorflow/tools/pip_package:build_pip_package && \
#    bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/pip && \
#    pip --no-cache-dir install --upgrade /tmp/pip/tensorflow-*.whl && \
#    rm -rf /tmp/pip && \
#    rm -rf /root/.cache
## Clean up pip wheel and Bazel cache when done.
#
## TensorBoard
#EXPOSE 6006
## IPython
#EXPOSE 8888

###############################################################################################
###			SECTION 4 - Compile Benchmarking Binaries for tensorflow Android 
###############################################################################################

RUN mkdir -p ~/graphs
RUN curl -o ~/graphs/inception.zip \
 https://storage.googleapis.com/download.tensorflow.org/models/inception5h.zip \
 && unzip ~/graphs/inception.zip -d ~/graphs/inception

RUN tensorflow/contrib/makefile/compile_android_protobuf.sh -c
RUN make -f tensorflow/contrib/makefile/Makefile TARGET=ANDROID

## Push benchmark binaries to Android mobile phone: Uncomment/Run if phone is connected
#adb push ~/graphs/inception/tensorflow_inception_graph.pb /data/local/tmp/
#adb push tensorflow/contrib/makefile/gen/bin/benchmark /data/local/tmp/
#adb shell '/data/local/tmp/benchmark \
# --graph=/data/local/tmp/tensorflow_inception_graph.pb \
# --input_layer="input:0" \
# --input_layer_shape="1,224,224,3" \
# --input_layer_type="float" \
# --output_layer="output:0"
#'

###############################################################################################
###			SECTION 5 - Compile Tensorflow Demo APK for Android	
###############################################################################################
# Clean makefile leftovers to avoid the conflicts because of makefile usage before bazel
RUN rm -rf tensorflow/contrib/makefile/downloads

# Configure tensorflow
RUN tensorflow/tools/ci_build/builds/configured ANDROID

# Download graphs for tensorflow demo apk
RUN curl -L https://storage.googleapis.com/download.tensorflow.org/models/inception5h.zip -o /tmp/inception5h.zip
RUN curl -L https://storage.googleapis.com/download.tensorflow.org/models/mobile_multibox_v1.zip -o /tmp/mobile_multibox_v1.zip
RUN unzip /tmp/inception5h.zip -d tensorflow/examples/android/assets/
RUN unzip /tmp/mobile_multibox_v1.zip -d tensorflow/examples/android/assets/

# Edit WORKSPACE file for sdk and ndk path and build tensorflow_demo.apk
RUN tensorflow/tools/ci_build/builds/android.sh
 
## To build custom APK. Demo APK is already built by android.sh. Uncomment, if required.
## If fails, run "./configure" and "git submodule update --init" and then build again
#RUN bazel build -c opt --copt=-mfpu=neon --spawn_strategy=standalone //tensorflow/examples/android:tensorflow_demo

## Install APK to Android mobile phone: Uncomment/Run if phone is connected
#RUN adb install -r -g bazel-bin/tensorflow/examples/android/tensorflow_demo.apk

###############################################################################################
###			SECTION 6 - Everything Ready!! Get bash and finish.
###############################################################################################

RUN echo All set darling!!! Your turn now!! 
WORKDIR /root
CMD ["/bin/bash"]