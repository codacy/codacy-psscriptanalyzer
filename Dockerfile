FROM mcr.microsoft.com/powershell:lts-7.2-alpine-3.14
LABEL maintainer="Codacy <code@codacy.com>"
COPY docs /docs
COPY runTool.ps1 /runTool.ps1
RUN adduser -D -u 2004 docker
USER docker
COPY psscriptanalyzer.version /
RUN pwsh -c "Install-Module PSScriptAnalyzer -RequiredVersion $(tr -d '\n' < /psscriptanalyzer.version) -Force -Confirm:\$false"
WORKDIR /src
CMD pwsh /runTool.ps1
