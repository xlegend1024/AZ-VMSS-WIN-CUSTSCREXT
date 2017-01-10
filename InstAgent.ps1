$omsagenturl='http://go.microsoft.com/fwlink/?LinkID=517476&clcid=0x409'
$workspaceid='28fe554d-50f5-4663-a1ba-cd17e0558c1d'
$key='WHPHXKXgKV+K6wCXjVNMiVSCckkDrR9e12iFd+FTH60oPDJfNf3zJenp7wiGBHt6vJK4e0epIHdaps0luxl3xg=='
$arg='/Q:A /R:N /C:"setup.exe /qn ADD_OPINSIGHTS_WORKSPACE=1 OPINSIGHTS_WORKSPACE_ID='+$workspaceid+' OPINSIGHTS_WORKSPACE_KEY='+$key+' AcceptEndUserLicenseAgreement=1"'

$storageDir = $env:TEMP
$webclient = New-Object System.Net.WebClient
$url = "https://go.microsoft.com/fwlink/?LinkID=517476"
$file = "$storageDir\MMASetup-AMD64.exe"
$webclient.DownloadFile($url,$file)

$p = Start-Process $file -ArgumentList $arg -wait -NoNewWindow -PassThru

$p.HasExited

$p.ExitCode
