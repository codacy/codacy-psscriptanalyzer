function getTitleFromBestPracticesFile {
    $titleMatchRaw = cat /PSScriptAnalyzer/PowerShellBestPractices.md | grep $args[0] ;
    if($titleMatchRaw) { $titleMatchRaw.split('[')[0].SubString(2) } ;
}

function getTitleFromRuleFile {
    $patternNameCamelCased = $args[0] ;
    #--- get title from finding rule files that have a name that matches part of a pattern name
    foreach($file in (ls /PSScriptAnalyzer/Rules/).split('\n')) {
        if($patternNameCamelCased.contains($file.split('.cs')[0])){
            $ruleFileWithShortPatternName = '/PSScriptAnalyzer/Rules/' + $file;
            $shortPatternName = $file.split('.cs')[0] ;
        }
    } ;
    $grepPatternShortName = '/// ' + $shortPatternName + ': ' ;
    # the next instruction will sometimes output 'No such file or directory' from cat
    $titleFromShortNameGrepResult = cat $ruleFileWithShortPatternName | grep "$grepPatternShortName" ;
    $titleFromShortNameMatch = if($titleFromShortNameGrepResult) { $titleFromShortNameGrepResult.split(':')[1].SubString(1).split('.')[0] } ;
    #--- get title from finding rule files that have a name that matches full pattern name
    $ruleFileWithFullPatternName = '/PSScriptAnalyzer/Rules/' + $patternNameCamelCased + '.cs' ;
    $grepPatternFullName = '/// ' + $patternNameCamelCased + ': ' ;
    # the next instruction will sometimes output 'No such file or directory' from cat
    $titleFromFullNameGrepResult = cat $ruleFileWithFullPatternName | grep "$grepPatternFullName" ;
    $titleFromFullNameMatch = if($titleFromFullNameGrepResult) { $titleFromFullNameGrepResult.split(':')[1].SubString(1).split('.')[0] } ;
    if($titleFromShortNameMatch) { $titleFromShortNameMatch } else { $titleFromFullNameMatch }
}

#resolve title by falling back from values retrieved from multiple sources
function getTitle {
    $patternNameCamelCased = $args[0] ;
    $titleMatchFromBestPractices = getTitleFromBestPracticesFile $patternNameCamelCased;
    $titleFromRulesFile = getTitleFromRuleFile $patternNameCamelCased;
    if($titleFromRulesFile) {
        $titleFromRulesFile ;
    } else {
        if($titleMatchFromBestPractices) {
            $titleMatchFromBestPractices ;
        } else {
            $patternNameCamelCased;
        }
    };
}

$null = New-Item -Type Directory /docs -Force ;
$patterns = Get-ScriptAnalyzerRule | Where-Object { $_.RuleName -ne 'PSUseDeclaredVarsMoreThanAssignments' } ;
$patternsLength = $patterns.Length ;
$codacyPatterns = @() ;
$codacyDescriptions = @();
New-Item -Type Directory /docs/description -Force | Out-Null ;
foreach($pat in $patterns) {
    $patternId = $pat.RuleName.ToLower() ;
    $patternNameLowerCased = $patternId.SubString(2) ;
    # could not use pat.RuleName for filename because of a mismatch in the uppercase 'W' in AvoidUsingUserNameAndPassWordParams
    $patternNameCamelCased = (ls /PSScriptAnalyzer/RuleDocumentation | grep -io $patternNameLowerCased).split("\n")[0] ;
    $originalPatternFileName = $patternNameCamelCased + '.md' ;
    $patternFileName = $patternId + '.md' ;
    cp /PSScriptAnalyzer/RuleDocumentation/$originalPatternFileName /docs/description/$patternFileName ;
    $title = getTitle $patternNameCamelCased ;
    $description = $pat.Description ;
    $level = if($pat.Severity -eq 'Information') { 'Info' } else { $pat.Severity.ToString() } ;
    $category = if($level -eq 'Info') { 'CodeStyle' } else { 'ErrorProne' } ;
    $parameters = @([ordered] @{name = $patternId; default = 'vars'}) ;
    $codacyPatterns += [ordered] @{ patternId = $patternId; level = $level; category = $category; parameters = $parameters } ;
    $codacyDescriptions += [ordered] @{ patternId = $patternId; title = $title; description = $description } ;
}
$patternFormat = [ordered] @{ name = 'psscriptanalyzer'; version = '1.17.1'; patterns = $codacyPatterns} ;
$patternFormat | ConvertTo-Json -Depth 5 | Out-File /docs/patterns.json -Force -Encoding ascii;
$codacyDescriptions | ConvertTo-Json -Depth 5 | Out-File /docs/description/description.json -Force -Encoding ascii;
$newLine = [system.environment]::NewLine;
$testFileContent = "##Patterns: psavoidusingcmdletaliases$newLine function TestFunc {$newLine  ##Warn: psavoidusingcmdletaliases$newLine  gps$newLine}";
New-Item -ItemType Directory /docs/tests -Force | Out-Null ;
$testFileContent | Out-File /docs/tests/aliasTest.ps1 -Force ;
$testFileContent = "##Patterns: psusecmdletcorrectly$newLine##Warn: psusecmdletcorrectly$newLine Write-Warning$newLine Wrong-Cmd$newLine Write-Verbose -Message 'Write Verbose'$newLine Write-Verbose 'Warning' -OutVariable `$test$newLine Write-Verbose 'Warning' | PipeLineCmdlet\";
$testFileContent | Out-File /docs/tests/useCmdletCorrectly.ps1 -Force;