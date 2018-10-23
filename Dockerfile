FROM microsoft/powershell:ubuntu-16.04 as builder
LABEL maintainer="Aditya Patwardhan <adityap@microsoft.com>"
RUN pwsh -c Install-Module PSScriptAnalyzer -RequiredVersion 1.17.1 -Force -Confirm:\$false
RUN apt-get update && apt-get --no-install-recommends -y install git=1:2.7.4-0ubuntu1.5 && \
 git clone https://github.com/PowerShell/PSScriptAnalyzer.git 
COPY install.ps1 /install.ps1
#This script will create and populate the /docs directory
RUN pwsh install.ps1

FROM microsoft/powershell:ubuntu-16.04
ARG IMAGE_NAME=PSCodacy
LABEL maintainer="Aditya Patwardhan <adityap@microsoft.com>"
COPY --from=builder /docs /docs
COPY runTool.ps1 /runTool.ps1
RUN pwsh -c Install-Module PSScriptAnalyzer -RequiredVersion 1.17.1 -Force -Confirm:\$false
RUN useradd -ms /bin/bash -u 2004 docker
USER docker
WORKDIR /src
CMD pwsh /runTool.ps1
