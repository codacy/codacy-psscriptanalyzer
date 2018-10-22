#!/usr/bin/env powershell

if (Test-Path '/.codacyrc') {
    $config = Get-Content '/.codacyrc' -Raw | ConvertFrom-Json ;
    $files = $config.files | ForEach-Object { Join-Path '/src' -ChildPath $_ };
    $rules = $config.tools | Where-Object { $_.name -eq 'psscriptanalyzer'} | ForEach-Object { $_.patterns.patternId };
}
if ($null -eq $rules) {
    $rules = '*' ;
}
if ($null -eq $files) {
    $output = Invoke-ScriptAnalyzer -Path /src -IncludeRule $rules -ExcludeRule PSUseDeclaredVarsMoreThanAssignments -Recurse;
} else {
    $output = $files | ForEach-Object { Invoke-ScriptAnalyzer -Path $_ -IncludeRule $rules -ExcludeRule PSUseDeclaredVarsMoreThanAssignments -Recurse; }
}
$output | ForEach-Object {
    $fileName = $_.ScriptPath.subString(5, $_.ScriptPath.Length-5) ;
    $message = $_.message;
    $patternId = $_.RuleName.ToLower();
    $line = $_.line;
    $result = [ordered] @{ filename = $fileName; message = $message; patternId = $patternId; line = $line };
    $result | ConvertTo-Json -Compress
}