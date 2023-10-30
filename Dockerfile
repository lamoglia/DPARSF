FROM ubuntu:22.04

RUN apt-get update -qq \
           && apt-get install -y -q --no-install-recommends \
                  ca-certificates curl apt-utils gnupg\
           && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
ENV NODE_MAJOR 18
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
RUN apt-get update -qq \
	&& apt-get install nodejs -y -q --no-install-recommends \
	&& rm -rf /var/lib/apt/lists/*

RUN node --version && npm --version && npm install -g bids-validator@1.9.9

# Save specification to JSON.
RUN printf '{ \
  "pkg_manager": "apt", \
  "existing_users": [ \
    "root" \
  ], \
  "instructions": [ \
    { \
      "name": "from_", \
      "kwds": { \
        "base_image": "ubuntu:jammy-20221130" \
      } \
    }, \
    { \
      "name": "install", \
      "kwds": { \
        "pkgs": [ \
          "ca-certificates curl apt-utils" \
        ], \
        "opts": null \
      } \
    }, \
    { \
      "name": "run", \
      "kwds": { \
        "command": "apt-get update -qq \\\\\\n    && apt-get install -y -q --no-install-recommends \\\\\\n           ca-certificates curl apt-utils \\\\\\n    && rm -rf /var/lib/apt/lists/*" \
      } \
    }, \
    { \
      "name": "run", \
      "kwds": { \
        "command": "curl -sL https://deb.nodesource.com/setup_18.x | bash -" \
      } \
    }, \
    { \
      "name": "install", \
      "kwds": { \
        "pkgs": [ \
          "nodejs" \
        ], \
        "opts": null \
      } \
    }, \
    { \
      "name": "run", \
      "kwds": { \
        "command": "apt-get update -qq \\\\\\n    && apt-get install -y -q --no-install-recommends \\\\\\n           nodejs \\\\\\n    && rm -rf /var/lib/apt/lists/*" \
      } \
    }, \
    { \
      "name": "run", \
      "kwds": { \
        "command": "node --version && npm --version && npm install -g bids-validator@1.9.9" \
      } \
    } \
  ] \
}' > /.reproenv.json
# End saving to specification to JSON.

ARG DEBIAN_FRONTEND="noninteractive"

# MAINTAINER Chao-Gan Yan <ycg.yan@gmail.com>
#Referenced from Guillaume Flandin's SPM BIDS apps

# Update system
RUN apt-get -qq update && \
    apt-get -qq install -y --no-install-recommends \
        unzip \
        xorg \
        octave \
        wget && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install MATLAB MCR
ENV MATLAB_VERSION R2016b
RUN mkdir /opt/mcr_install && \
    mkdir /opt/mcr && \
    wget --quiet -P /opt/mcr_install http://www.mathworks.com/supportfiles/downloads/${MATLAB_VERSION}/deployment_files/${MATLAB_VERSION}/installers/glnxa64/MCR_${MATLAB_VERSION}_glnxa64_installer.zip && \
    unzip -q /opt/mcr_install/MCR_${MATLAB_VERSION}_glnxa64_installer.zip -d /opt/mcr_install && \
    /opt/mcr_install/install -destinationFolder /opt/mcr -agreeToLicense yes -mode silent && \
    rm -rf /opt/mcr_install /tmp/*

# Configure environment
ENV MCR_VERSION v91
ENV LD_LIBRARY_PATH /opt/mcr/${MCR_VERSION}/runtime/glnxa64:/opt/mcr/${MCR_VERSION}/bin/glnxa64:/opt/mcr/${MCR_VERSION}/sys/os/glnxa64:/opt/mcr/${MCR_VERSION}/sys/opengl/lib/glnxa64
ENV MCR_INHIBIT_CTF_LOCK 1
ENV MCRPath /opt/mcr/${MCR_VERSION}

# Install DPARSFA Standalone (from OSF mirror due to connectivity issues)
RUN wget --quiet --no-check-certificate -c -O /opt/DPARSFA_run_StandAlone_Linux.zip "https://files.osf.io/v1/resources/q8g5z/providers/osfstorage/5a1a97366c613b026d5e6f79" && \
    unzip -q /opt/DPARSFA_run_StandAlone_Linux.zip -d /opt && \
    rm -f /opt/DPARSFA_run_StandAlone_Linux.zip

# Configure DPARSF BIDS App entry point
COPY run.sh /opt/DPARSFA_run_StandAlone_Linux/
COPY Template_V4_CalculateInMNISpace_Warp_DARTEL_docker.mat /opt/DPARSFA_run_StandAlone_Linux/
COPY y_Convert_BIDS2DPARSFA.m /opt/DPARSFA_run_StandAlone_Linux/
COPY y_CopyDARTELTemplate.m /opt/DPARSFA_run_StandAlone_Linux/
COPY Atlas /opt/DPARSFA_run_StandAlone_Linux/
COPY version /version
RUN chmod +x /opt/DPARSFA_run_StandAlone_Linux/run.sh && \
    chmod +x /opt/DPARSFA_run_StandAlone_Linux/run_DPARSFA_run.sh && \
    chmod +x /opt/DPARSFA_run_StandAlone_Linux/DPARSFA_run

ENV DPARSFPath /opt/DPARSFA_run_StandAlone_Linux

RUN rm /opt/mcr/v91/sys/os/glnxa64/libstdc++.so.6
RUN ln -s /usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.30 /opt/mcr/v91/sys/os/glnxa64/libstdc++.so.6
RUN rm /opt/mcr/v91/bin/glnxa64/libfreetype.so.6
RUN ln -s /usr/lib/x86_64-linux-gnu/libfreetype.so.6 /opt/mcr/v91/bin/glnxa64/libfreetype.so.6
ENTRYPOINT ["/opt/DPARSFA_run_StandAlone_Linux/run.sh"]
