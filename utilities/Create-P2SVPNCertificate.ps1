[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $Subject
)

$certificateHome = Join-Path $env:TEMP $Subject
$certificateInfo = [System.IO.Path]::ChangeExtension($certificateHome, ".txt")
Write-Host "Creating new self signed root and client certificate at $certificateHome"

# Remove certificate file and info if exists
New-Item -Path $certificateHome -Type Directory -ErrorAction SilentlyContinue | Out-Null
Remove-Item -Path $certificateInfo -Force -ErrorAction SilentlyContinue | Out-Null

$rootCert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object { $_.Subject -eq "CN=$Subject-ROOT" } | Select-Object -First 1

if (-not $rootCert) {
    $rootCert = New-SelfSignedCertificate -Type Custom -KeySpec Signature -Subject "CN=$Subject-ROOT" -KeyExportPolicy Exportable -HashAlgorithm sha256 -KeyLength 2048 -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign -KeyUsage CertSign
    $rootCert | Export-Certificate -FilePath (Join-Path $certificateHome "root.cer") | Out-Null
}

$rootBytes = [System.IO.File]::ReadAllBytes($(Join-Path $certificateHome "root.cer"))

$clientCert = New-SelfSignedCertificate -Type Custom -KeySpec Signature -Subject "CN=$Subject" -KeyExportPolicy Exportable -HashAlgorithm sha256 -KeyLength 2048 -CertStoreLocation "Cert:\CurrentUser\My" -Signer $rootCert -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")
$clientCert | Export-PfxCertificate -Password (ConvertTo-SecureString -String $($clientCert.Thumbprint) -AsPlainText -Force) -FilePath (Join-Path $certificateHome "$($clientCert.Thumbprint).pfx") | Out-Null

"Root Certificate Subject: $($rootCert.Subject)"                                            | Out-File -FilePath $certificateInfo -Append
"Root Certificate Thumbprint: $($rootCert.Thumbprint)"                                      | Out-File -FilePath $certificateInfo -Append
"========================================================================================"  | Out-File -FilePath $certificateInfo -Append
$([System.Convert]::ToBase64String($rootBytes))                                             | Out-File -FilePath $certificateInfo -Append
""                                                                                          | Out-File -FilePath $certificateInfo -Append
"Client Certificate Thumbprints:"                                                           | Out-File -FilePath $certificateInfo -Append
"========================================================================================"  | Out-File -FilePath $certificateInfo -Append
Get-ChildItem -Path $certificateHome -Filter "*.pfx" | % { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) } | Out-File -FilePath $certificateInfo -Append

notepad $certificateInfo