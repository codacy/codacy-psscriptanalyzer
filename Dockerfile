FROM microsoft/powershell:ubuntu-16.04 as builder

LABEL maintainer="Aditya Patwardhan <adityap@microsoft.com>"

RUN pwsh -c Install-Module PSScriptAnalyzer -RequiredVersion 1.17.1 -Force -Confirm:\$false

RUN apt-get update && apt-get --no-install-recommends -y install git=1:2.7.4-0ubuntu1.5 && \
 git clone https://github.com/PowerShell/PSScriptAnalyzer.git 

RUN pwsh -c " \
\$null = New-Item -Type Directory /docs -Force; \
\$patterns = Get-ScriptAnalyzerRule | Where-Object { \$_.RuleName -ne 'PSUseDeclaredVarsMoreThanAssignments' } ;\
\$codacyPatterns = @(); \
\$codacyDescriptions = @(); \
New-Item -Type Directory /docs/description -Force | Out-Null ; \
foreach(\$pat in \$patterns) { \
    \$patternId = \$pat.RuleName.ToLower() ;   \
    \$patternNameLowerCased = \$patternId.SubString(2) ; \
    # could not use pat.RuleName for filename because of a mismatch in the uppercase 'W' in AvoidUsingUserNameAndPassWordParams
    \$patternNameCamelCased = (ls /PSScriptAnalyzer/RuleDocumentation | grep -io \$patternNameLowerCased).split(\"\\n\")[0] ; \
    \$originalPatternFileName = \$patternNameCamelCased + '.md' ; \
    \$patternFileName = \$patternId + '.md' ; \
    cp /PSScriptAnalyzer/RuleDocumentation/\$originalPatternFileName /docs/description/\$patternFileName ; \
    # get title
    \$titleMatchRaw = cat /PSScriptAnalyzer/PowerShellBestPractices.md | grep \$patternNameCamelCased ; \
    \$titleMatch = if(\$titleMatchRaw) { \$titleMatchRaw.split('[')[0].SubString(2) } ; \
    \$altPatternFile = '/PSScriptAnalyzer/Rules/' + \$patternNameCamelCased + '.cs' ; \
    \$grepPattern = '/// ' + \$patternNameCamelCased + ': ' ; \
    # the next instruction will sometimes output 'No such file or directory' from cat
    \$altTitleGrepResult = cat \$altPatternFile | grep \"\$grepPattern\" ; \
    \$altTitleMatch = if(\$altTitleGrepResult) { \$altTitleGrepResult.split(\":\")[1].SubString(1) } ; \
    \$title = if(\$titleMatch) { \$titleMatch } else { if(\$altTitleMatch) { \$altTitleMatch } else { \$patternNameCamelCased } } ; \
    # end get title
    \$description = \$pat.Description ;  \
    \$level = if(\$pat.Severity -eq 'Information') { 'Info' } else { \$pat.Severity.ToString() } ;   \
    \$category = if(\$level -eq 'Info') { 'CodeStyle' } else { 'ErrorProne' } ;  \
    \$parameters = @([ordered]@{name = \$patternId; default = 'vars'}) ; \
    \$codacyPatterns += [ordered] @{ patternId = \$patternId; level = \$level; category = \$category; parameters = \$parameters } ;   \
    \$codacyDescriptions += [ordered] @{ patternId = \$patternId; title = \$title; description = \$description } ;  \
}   \
\$patternFormat = [ordered] @{ name = 'psscriptanalyzer'; version = '1.17.1'; patterns = \$codacyPatterns} ;\
\$patternFormat | ConvertTo-Json -Depth 5 | Out-File /docs/patterns.json -Force -Encoding ascii; \
\$codacyDescriptions | ConvertTo-Json -Depth 5 | Out-File /docs/description/description.json -Force -Encoding ascii; \
\$newLine = [system.environment]::NewLine; \
\$testFileContent = \"##Patterns: psavoidusingcmdletaliases\$newLine function TestFunc {\$newLine  ##Warn: psavoidusingcmdletaliases\$newLine  gps\$newLine}\"; \
New-Item -ItemType Directory /docs/tests -Force | Out-Null ;\
\$testFileContent | Out-File /docs/tests/aliasTest.ps1 -Force ;\
\$testFileContent = \"##Patterns: psusecmdletcorrectly\$newLine##Warn: psusecmdletcorrectly\$newLine Write-Warning\$newLine Wrong-Cmd\$newLine Write-Verbose -Message 'Write Verbose'\$newLine Write-Verbose 'Warning' -OutVariable \`$"test"\$newLine Write-Verbose 'Warning' | PipeLineCmdlet\";\
\$testFileContent | Out-File /docs/tests/useCmdletCorrectly.ps1 -Force;"


FROM microsoft/powershell:ubuntu-16.04
ARG IMAGE_NAME=PSCodacy
LABEL maintainer="Aditya Patwardhan <adityap@microsoft.com>"
COPY --from=builder /docs /docs
RUN pwsh -c Install-Module PSScriptAnalyzer -RequiredVersion 1.17.1 -Force -Confirm:\$false
RUN useradd -ms /bin/bash -u 2004 docker
USER docker
WORKDIR /src
CMD pwsh -c \
    "if (Test-Path '/.codacyrc') { \
        \$config = Get-Content '/.codacyrc' -Raw | ConvertFrom-Json ; \
        Write-Verbose \"ConfigFiles (\$(\$config.files.count)): \$(\$config.files)\" -Verbose; \
        \$files = \$config.files | ForEach-Object { Join-Path '/src' -ChildPath \$_ }; \
        \$rules = \$config.tools | Where-Object { \$_.name -eq 'psscriptanalyzer'} | ForEach-Object { \$_.patterns.patternId }; \
    } \
    if (\$null -eq \$rules) { \
        \$rules = '*' \
    } \
    Write-Verbose -Verbose \"Rules: \$rules Files: \$files\"; \
    if (\$null -eq \$files) { \
        \$output = Invoke-ScriptAnalyzer -Path /src -IncludeRule \$rules -ExcludeRule PSUseDeclaredVarsMoreThanAssignments -Recurse; \
    } else { \
        \$output = \$files | ForEach-Object { Invoke-ScriptAnalyzer -Path \$_ -IncludeRule \$rules -ExcludeRule PSUseDeclaredVarsMoreThanAssignments -Recurse; } \
    } \
     \$output | % { \
        \$fileName = \$_.ScriptPath.Trim('/src/'); \
        \$message = \$_.message; \
        \$patternId = \$_.RuleName.ToLower(); \
        \$line = \$_.line; \
        \$result = [ordered] @{ filename = \$fileName; message = \$message; patternId = \$patternId; line = \$line }; \
        \$result | ConvertTo-Json -Compress \
        } \
    "
