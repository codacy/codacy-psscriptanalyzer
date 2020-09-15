#!/usr/bin/env pwsh
$visibilityRules = 'psavoidusingcomputernamehardcoded' ;
$cryptoRules = 'psavoidusingconverttosecurestringwithplaintext', 'psavoidusingplaintextforpassword', 'psusepscredentialtype' ;
$commandInjectionRules = 'psavoidusinginvokeexpression' ;
$authRules = 'psavoidusingusernameandpasswordparams' ;
$enabledRules = @(
    "psalignassignmentstatement",
    "psavoidassignmenttoautomaticvariable",
    "psavoiddefaultvalueformandatoryparameter",
    "psavoiddefaultvalueswitchparameter",
    "psavoidglobalaliases",
    "psavoidglobalfunctions",
    "psavoidglobalvars",
    "psavoidinvokingemptymembers",
    "psavoidshouldcontinuewithoutforce",
    "psavoidusingcomputernamehardcoded",
    "psavoidusingconverttosecurestringwithplaintext",
    "psavoidusingdeprecatedmanifestfields",
    "psavoidusingemptycatchblock",
    "psavoidusinginvokeexpression",
    "psavoidusingplaintextforpassword",
    "psavoidusingpositionalparameters",
    "psavoidusingusernameandpasswordparams",
    "psavoidusingwmicmdlet",
    "psavoidusingwritehost",
    "psdscdscexamplespresent",
    "psdscdsctestspresent",
    "psdscreturncorrecttypesfordscfunctions",
    "psdscstandarddscfunctionsinresource",
    "psdscuseidenticalmandatoryparametersfordsc",
    "psdscuseidenticalparametersfordsc",
    "psmisleadingbacktick",
    "psmissingmodulemanifestfield",
    "psplaceclosebrace",
    "psplaceopenbrace",
    "pspossibleincorrectcomparisonwithnull",
    "pspossibleincorrectusageofassignmentoperator",
    "pspossibleincorrectusageofredirectionoperator",
    "psreservedcmdletchar",
    "psreservedparams",
    "psshouldprocess",
    "psuseapprovedverbs",
    "psusebomforunicodeencodedfile",
    "psusecmdletcorrectly",
    "psusecompatiblecmdlets",
    "psuseliteralinitializerforhashtable",
    "psuseoutputtypecorrectly",
    "psusepscredentialtype",
    "psuseshouldprocessforstatechangingfunctions",
    "psusesupportsshouldprocess",
    "psusetoexportfieldsinmanifest"
)

$count = 0;
function getTitleFromBestPracticesFile {
    $titleMatchRaw = cat PSScriptAnalyzer/PowerShellBestPractices.md | grep $args[0] ;
    if($titleMatchRaw) { $titleMatchRaw.split('[')[0].SubString(2) } ;
}

function getTitleFromRuleFile {
    $patternNameCamelCased = $args[0] ;
    #--- get title from finding a rule file that has a name that matches part of a pattern name
    foreach($file in Get-ChildItem PSScriptAnalyzer/Rules/*) {
        $fileNameWithoutExtension = $file.name.split('.cs')[0]
        if($patternNameCamelCased.contains($fileNameWithoutExtension)){
            $ruleFileWithShortPatternName = 'PSScriptAnalyzer/Rules/' + $file.name;
            $shortPatternName = $fileNameWithoutExtension ;
        }
    } ;
    $commentPattern = '[\/]\{3\} [a-zA-Z0-9]*[: ] [.?]*' ;
    $titleFromShortNameGrepResult = if($ruleFileWithShortPatternName){ cat $ruleFileWithShortPatternName | grep "$commentPattern" };
    $titleFromShortNameMatch = if($titleFromShortNameGrepResult) { $titleFromShortNameGrepResult.split(':')[1].SubString(1).split('.')[0] } ;
    #--- get title from finding a rule file that has a name that matches full pattern name
    $ruleFileWithFullPatternName = 'PSScriptAnalyzer/Rules/' + $patternNameCamelCased + '.cs' ;
    # the next instruction will output 'No such file or directory' from cat when this file does not exist
    $titleFromFullNameGrepResult = cat $ruleFileWithFullPatternName | grep "$commentPattern" ;
    $titleFromFullNameMatch = if($titleFromFullNameGrepResult) { $titleFromFullNameGrepResult.split(':')[1].SubString(1).split('.')[0] } ;
    if($titleFromShortNameMatch) { $titleFromShortNameMatch } else { $titleFromFullNameMatch }
}

#resolve title by falling back from values retrieved from multiple sources
function getTitle {
    $patternNameCamelCased = $args[0] ;
    $titleFromRulesFile = getTitleFromRuleFile $patternNameCamelCased;
    $titleMatchFromBestPractices = getTitleFromBestPracticesFile $patternNameCamelCased;
    if($titleFromRulesFile) {
        $titleFromRulesFile ;
    } elseif($titleMatchFromBestPractices) {
        $titleMatchFromBestPractices ;
    } else {
        $patternNameCamelCased;
    };
}

# get pattern category
function getCategory {
    $level = $args[0]
    $patternId = $args[1]

    $subcategory = getSecuritySubcategory $patternId
    if($subcategory -ne '') { 
        @{ category='Security'; subcategory=$subcategory } ;
    }elseif($level -eq 'Info') { 
        @{ category='CodeStyle' } ;
    } else { 
        @{ category='ErrorProne' } ;
    };
}

# get security subcategory for pattern id
function getSecuritySubcategory {
    $patternId = $args[0]
    
    switch ($patternId) {
        {$visibilityRules -contains $_} { 'Visibility' }
        {$cryptoRules -contains $_} {'Cryptography'}
        {$commandInjectionRules -contains $_} {'CommandInjection'}
        {$authRules -contains $_} {'Auth'}
        default {''}
    }
}

$null = New-Item -Type Directory docs -Force ;
$patterns = Get-ScriptAnalyzerRule | Where-Object { $_.RuleName -ne 'PSUseDeclaredVarsMoreThanAssignments' } ;
$patternsLength = $patterns.Length ;
$codacyPatterns = @() ;
$codacyDescriptions = @();
New-Item -Type Directory docs/description -Force | Out-Null ;
foreach($pat in $patterns) {
    $patternId = $pat.RuleName.ToLower() ;
    $patternNameLowerCased = $patternId.SubString(2) ;
    # could not use pat.RuleName for filename because of a mismatch in the uppercase 'W' in AvoidUsingUserNameAndPassWordParams
    $patternNameCamelCased = (ls PSScriptAnalyzer/RuleDocumentation | grep -io $patternNameLowerCased).split("\n")[0] ;
    $originalPatternFileName = $patternNameCamelCased + '.md' ;
    $patternFileName = $patternId + '.md' ;
    cp PSScriptAnalyzer/RuleDocumentation/$originalPatternFileName docs/description/$patternFileName ;
    $title = getTitle $patternNameCamelCased ;
    if($title -eq $patternNameCamelCased) { Write-Output "$patternNameCamelCased"; $count = $count+1;}
    $description = $pat.Description ;
    $level = if($pat.Severity -eq 'Information') { 'Info' } else { $pat.Severity.ToString() } ;
    $category = getCategory $level $patternId;
    $enabledByDefault = $enabledRules -contains $patternId
    if($category.ContainsKey('subcategory')) {
        $codacyPatterns += [ordered] @{ patternId = $patternId; level = $level; category = $category.category; subcategory = $category.subcategory; enabled = $enabledByDefault } ;
    } else {
        $codacyPatterns += [ordered] @{ patternId = $patternId; level = $level; category = $category.category; enabled = $enabledByDefault } ;
    }
    $codacyDescriptions += [ordered] @{ patternId = $patternId; title = $title; description = $description } ;
}
Write-Output "UNMATCHED PATTERNS: $count";
$toolVersion = cat psscriptanalyzer.version | tr -d '\n';
$patternFormat = [ordered] @{ name = 'psscriptanalyzer'; version = $toolVersion; patterns = $codacyPatterns} ;
$patternFormat | ConvertTo-Json -Depth 5 | Out-File docs/patterns.json -Force -Encoding ascii;
$codacyDescriptions | ConvertTo-Json -Depth 5 | Out-File docs/description/description.json -Force -Encoding ascii;
$newLine = [system.environment]::NewLine;
