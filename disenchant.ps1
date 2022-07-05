add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3, [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12

function Disenchant {
  param (
    [string]$Auth,
    [string]$LootId,
    [string]$BaseURL,
    [int]$Repeat = 0  
  )

  $Headers = @{
    "Authorization" = $auth
    "Content-Type"  = "application/json"
  }

  Invoke-WebRequest -UseBasicParsing -Method Post -Uri "$BaseURL/lol-loot/v1/recipes/CHAMPION_RENTAL_disenchant/craft?repeat=$($Shard.count)" -Headers $Headers -Body $Body | Out-Null
}

function Get-ChampionShards {
  param (
    [string]$Auth,
    [string]$BaseURL
  )
  $Headers = @{
    "Authorization" = $Auth
  }

  $Response = Invoke-WebRequest -UseBasicParsing -Method Get -Uri "$BaseURL/lol-loot/v1/player-loot" -Headers $Headers
  $Data = ConvertFrom-Json $Response.Content
  return $Data | Where-Object { $_.disenchantLootName -eq "CURRENCY_champion" }
}

# begin script

$leagueoflegends = "C:\Riot Games\League of Legends"
$path = Join-Path -Path $leagueoflegends -ChildPath "lockfile"
$lockfile = Get-Content -Path $path

if ($null -eq $lockfile) {
  Read-Host "lockfile not found or league of legends is not started"
  Exit
}

$PName, $ProcId, $Port, $Password, $Protocol = $lockfile.Split(":")
$baseURL = "$($Protocol)://127.0.0.1:$Port"
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("riot:$Password"))
$auth = "Basic $encodedCreds"

$Shards = Get-ChampionShards -BaseURL $baseURL -Auth $auth | Select-Object -Property lootId, count, itemDesc | Sort-Object -Property itemDesc

foreach ($Shard in $Shards) {
  $Body = ConvertTo-Json @($Shard.lootId)

  $title = 'Disenchant Champion Shard'
  $msg = "Do you want to disenchant $($Shard.itemDesc)?"
  $options = '&Yes', '&No'
  $default = 0  # 0=Yes, 1=No

  $response = $Host.UI.PromptForChoice($title, $msg, $options, $default)
  if ($response -eq 0) {
    Disenchant -BaseURL $baseURL -Auth $auth -LootId $shard.lootId -Repeat $Shard.count
  }
}
