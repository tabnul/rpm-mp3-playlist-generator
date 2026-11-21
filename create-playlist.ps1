<#
.SYNOPSIS
  Generates random RPM class playlists from numbered tracks.

.DESCRIPTION
  Picks random tracks per track slot (as defined in the CSV) and either writes
  .m3u playlists referencing them (for Lyrion Media Server) or copies them into
  a folder per playlist. A track is never used twice within one run.

.EXAMPLE
  .\create-playlist.ps1 -TrackFolder "\\data.localdomain\media\music\RPM" -PlaylistFolder "\\data.localdomain\media\music\Playlists" -TrackCsv .\tracks.csv -ServerTrackFolder "/music/RPM"

.EXAMPLE
  .\create-playlist.ps1 -Mode copy -TrackFolder D:\RPM -PlaylistFolder D:\Out -TrackCsv .\tracks.csv -Count 5
#>
[CmdletBinding()]
param(
  #Folder to scan for tracks (including subfolders)
  [Parameter(Mandatory)][string]$TrackFolder,
  #Folder to write the playlists / playlist folders to
  [Parameter(Mandatory)][string]$PlaylistFolder,
  #CSV with columns: track,amount
  [Parameter(Mandatory)][string]$TrackCsv,
  #"playlist" = write .m3u files, "copy" = copy tracks into folders
  [ValidateSet("playlist","copy")][string]$Mode="playlist",
  #Number of playlists to create
  [ValidateRange(1,999)][int]$Count=15,
  #Name prefix, results in e.g. "RPM 01.m3u" / folder "RPM 01"
  [string]$Prefix="RPM",
  #playlist mode: path of -TrackFolder as seen by Lyrion (e.g. "/music/RPM").
  #Empty = LMS sees the same paths as this PC.
  #Lyrion docker mounts \\data.localdomain\media\music as /music.
  [string]$ServerTrackFolder=""
)

$ErrorActionPreference="Stop"

$trackArray=Import-CSV -LiteralPath $TrackCsv
New-Item -ItemType Directory -Force -Path $PlaylistFolder | Out-Null

#remove previous output (only items with our prefix):
if ($Mode -eq "playlist") {
  Get-ChildItem -LiteralPath $PlaylistFolder -Filter "$Prefix *.m3u" -File | Remove-Item
} else {
  Get-ChildItem -LiteralPath $PlaylistFolder -Filter "$Prefix *" -Directory | Remove-Item -Recurse
}

$usedTracks=@()
$files=Get-ChildItem -LiteralPath $TrackFolder -Recurse -File
$trackRoot=(Resolve-Path -LiteralPath $TrackFolder).ProviderPath.TrimEnd('\')
$utf8NoBom=New-Object System.Text.UTF8Encoding($false)

function Get-ServerPath($fullName) {
  if ([string]::IsNullOrEmpty($ServerTrackFolder)) { return $fullName }
  $relative=$fullName.Substring($trackRoot.Length).TrimStart('\') -replace '\\','/'
  return $ServerTrackFolder.TrimEnd('/') + '/' + $relative
}

for ($playlistNumber=1; $playlistNumber -le $Count; $playlistNumber++) {

  $playlistName="$Prefix {0:D2}" -f $playlistNumber
  $lines=@('#EXTM3U')

  if ($Mode -eq "copy") {
    $currentPlaylistLocation=Join-Path $PlaylistFolder $playlistName
    New-Item -ItemType Directory -Force -Path $currentPlaylistLocation | Out-Null
  }

  foreach ($trackRow in $trackArray){
    $trackNumber=$trackRow.track
    $trackAmount=[int]$trackRow.amount
    $numberedTracks=@($files | Where-Object {$_.Name -match "^$trackNumber(\D|$)" -and $_.Name -notin $usedTracks})

    if ($numberedTracks.Count -lt $trackAmount) {
      Write-Warning "$playlistName, track $trackNumber : only $($numberedTracks.Count) unused tracks left (need $trackAmount)"
    }
    if ($numberedTracks.Count -eq 0) { continue }

    $randomTracks=@(Get-Random -InputObject $numberedTracks -Count $trackAmount)
    foreach ($track in $randomTracks){
      if ($Mode -eq "copy") {
        Copy-Item -LiteralPath $track.FullName -Destination $currentPlaylistLocation
      } else {
        $lines += "#EXTINF:-1,$($track.BaseName)"
        $lines += Get-ServerPath $track.FullName
      }
      $usedTracks += $track.Name
      Write-Host "$playlistName - track $trackNumber : $($track.Name)"
    }
  }

  if ($Mode -eq "playlist") {
    $playlistFile=Join-Path $PlaylistFolder "$playlistName.m3u"
    [System.IO.File]::WriteAllLines($playlistFile, [string[]]$lines, $utf8NoBom)
  }
}
