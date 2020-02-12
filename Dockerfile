# Build an Ubuntu-based container to run Mycroft
#
#   The steps in this build are ordered from least likely to change to most
#   likely to change.  The intent behind this is to reduce build time so things
#   like Jenkins jobs don't spend a lot of time re-building things that did not
#   change from one build to the next.
#
FROM ubuntu:18.04 as builder
ENV TERM linux
ENV DEBIAN_FRONTEND noninteractive
# Un-comment any package sources that include a multiverse
RUN sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list
# Install Server Dependencies for Mycroft
RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    bison \
    build-essential \
    curl \
    flac \
    git \
    jq \
    libfann-dev \
    libffi-dev \
    libicu-dev \
    libjpeg-dev \
    libglib2.0-dev \
    libssl-dev \
    libtool \
    locales \
    mpg123 \
    pkg-config \
    portaudio19-dev \
    pulseaudio \
    pulseaudio-utils \
    python3 \
    python3-dev \
    python3-pip \
    python3-setuptools \
    python3-venv \
    screen \
    sudo \
    swig \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set the locale
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Setup the virtual environment
#   This may not be the most efficient way to do this in terms of number of
#   steps, but it is built to take advantage of Docker's caching mechanism
#   to only rebuild things that have changed since the last build.
RUN mkdir /opt/mycroft
WORKDIR /opt/mycroft
RUN mkdir mycroft-core skills ~/.mycroft
RUN python3 -m venv "/opt/mycroft/mycroft-core/.venv"
RUN mycroft-core/.venv/bin/python -m pip install pip==20.0.2
COPY requirements.txt mycroft-core
RUN mycroft-core/.venv/bin/python -m pip install -r mycroft-core/requirements.txt
COPY . mycroft-core
EXPOSE 8181


# Integration Test Suite
#
#   Build against this target to set the container up as an executable that
#   will run the "voigt_kampff" integration test suite.
#
FROM builder as voigt_kampff
# Add the mycroft core virtual environment to the system path.
ENV PATH /opt/mycroft/mycroft-core/.venv/bin:$PATH
# Install required packages for test environments
RUN mycroft-core/.venv/bin/python -m pip install -r mycroft-core/test-requirements.txt
# Generate hash of required packages
RUN md5sum requirements.txt test-requirements.txt dev_setup.sh > .installed
RUN mkdir ~/.mycroft/allure-result

# Install Mark I default skills
RUN msm -p mycroft_mark_1 default

# The behave feature files for a skill are defined within the skill's
# repository.  Copy those files into the local feature file directory
# for test discovery.
WORKDIR /opt/mycroft/mycroft-core
RUN python -m test.integrationtests.voigt_kampff.skill_setup -c test/integrationtests/voigt_kampff/default.yml

# Setup and run the integration tests
WORKDIR /opt/mycroft/mycroft-core/test/integrationtests/voigt_kampff
ENTRYPOINT "./run_test_suite.sh"
