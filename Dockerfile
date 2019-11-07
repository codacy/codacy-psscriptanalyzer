FROM mcr.microsoft.com/powershell:6.2.3-ubuntu-18.04
LABEL maintainer="Aditya Patwardhan <adityap@microsoft.com>"
COPY docs /docs
COPY runTool.ps1 /runTool.ps1
RUN useradd -ms /bin/bash -u 2004 docker
USER docker
COPY psscriptanalyzer.version /
RUN pwsh -c "Install-Module PSScriptAnalyzer -RequiredVersion $(tr -d '\n' < /psscriptanalyzer.version) -Force -Confirm:\$false"
WORKDIR /src
CMD pwsh /runTool.ps1
