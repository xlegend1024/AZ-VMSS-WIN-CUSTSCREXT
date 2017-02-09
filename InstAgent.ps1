Param(
    [string] $workspaceid,
    [string] $key
)
#need id and key like following
$workspaceid='d2710c19-0e42-4079-a731-b7cd5bf3fb05'
$key='9UWx7FssTv4XCwHp7igTIFcANjQdSD9mtYtC/wVOVfYf/bLikIOYod7dZBP2z+Sa96SdY8XD6XXdlpB1E8K3pA=='

$omsagenturl='http://go.microsoft.com/fwlink/?LinkID=517476&clcid=0x409'
$arg='/Q:A /R:N /C:"setup.exe /qn ADD_OPINSIGHTS_WORKSPACE=1 OPINSIGHTS_WORKSPACE_ID='+$workspaceid+' OPINSIGHTS_WORKSPACE_KEY='+$key+' AcceptEndUserLicenseAgreement=1"'

$storageDir = $env:TEMP
$webclient = New-Object System.Net.WebClient
$url = "https://go.microsoft.com/fwlink/?LinkID=517476"
$file = "$storageDir\MMASetup-AMD64.exe"
$webclient.DownloadFile($url,$file)

$p = Start-Process $file -ArgumentList $arg -wait -NoNewWindow -PassThru

$p.HasExited

$p.ExitCode
