[CmdletBinding(DefaultParameterSetName = 'Seed')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Change')]
    [ValidateSet('Student', 'Trainer', 'Administrator')]
    [string] $Account,

    [Parameter(Mandatory, ParameterSetName = 'Change')]
    [ValidateSet('Student', 'Trainer', 'Administrator')]
    [string] $Role
)

$ErrorActionPreference = 'Stop'
$demoProject = 'demo-bjj-110'
$localAuth = 'http://127.0.0.1:19099/identitytoolkit.googleapis.com/v1'
$localRoles = "http://127.0.0.1:18080/v1/projects/$demoProject/databases/(default)/documents/user_roles"
$emulatorOwner = @{ Authorization = 'Bearer owner' }
$localPassword = 'BjjLocal110!'

function Find-LocalUser([string] $Email) {
    $lookup = Invoke-RestMethod -Method Post -MaximumRedirection 0 -Headers $emulatorOwner `
        -Uri "$localAuth/projects/${demoProject}/accounts:lookup" -ContentType 'application/json' `
        -Body (@{ email = @($Email) } | ConvertTo-Json -Compress)
    $lookup.users | Select-Object -First 1
}

function Set-LocalRole([string] $Uid, [string] $NewRole) {
    $roleUri = "$localRoles/$Uid"
    if ($NewRole -eq 'Student') {
        Invoke-RestMethod -Method Delete -MaximumRedirection 0 -Uri $roleUri -Headers $emulatorOwner | Out-Null
    } else {
        $roleValue = if ($NewRole -eq 'Administrator') { 'admin' } else { 'trainer' }
        $document = @{ fields = @{ role = @{ stringValue = $roleValue } } }
        Invoke-RestMethod -Method Patch -MaximumRedirection 0 -Uri $roleUri -Headers $emulatorOwner `
            -ContentType 'application/json' -Body ($document | ConvertTo-Json -Depth 4 -Compress) | Out-Null
    }
}

if ($PSCmdlet.ParameterSetName -eq 'Change') {
    $email = "$($Account.ToLowerInvariant())@bjj110.example.test"
    $user = Find-LocalUser $email
    if (-not $user) {
        throw "Local account $email does not exist. Run this script without arguments to seed the accounts."
    }
    Set-LocalRole $user.localId $Role
    Write-Output "$email now has $Role access in $demoProject."
    return
}

foreach ($accountName in 'Student', 'Trainer', 'Administrator') {
    $email = "$($accountName.ToLowerInvariant())@bjj110.example.test"
    $user = Find-LocalUser $email
    if (-not $user) {
        $credentials = @{ email = $email; password = $localPassword; displayName = $accountName }
        $user = Invoke-RestMethod -Method Post -MaximumRedirection 0 `
            -Uri "${localAuth}/accounts:signUp?key=demo-key" -ContentType 'application/json' `
            -Body ($credentials | ConvertTo-Json -Compress)
    }
    Set-LocalRole $user.localId $accountName
    Write-Output "$accountName  $email"
}
Write-Output "Password for all three seeded emulator accounts: $localPassword"
