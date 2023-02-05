#Folder to scan for files (will also scan through subfolders):
$trackFolderLocation=""
#Folder to put the playlists in:
$playlistFolderLocation=""
#location of the CSV containing file/type list:
$trackCSV= ""
#Amount of playlists to create:
$amountOfPlaylists=15

##

$trackArray=Import-CSV $trackCSV

$playlistStartNumberCounter=1
#remove all previous playlists:
Get-ChildItem -Path $playlistFolderLocation -recurse | where { ! $_.PSIsContainer } | remove-Item -recurse 

$copiedTracks= @()


$files=Get-Childitem $trackfolderLocation -Recurse | where { ! $_.PSIsContainer }

 while ($playlistStartNumberCounter -le $amountOfPlaylists) {

    $playlistStartNumberString=$playliststartNumberCounter.ToString()
    $currentPlaylistLocation=$playlistFolderLocation + $playliststartNumberString
    
    
    foreach ($trackRow in $trackArray){

        $trackNumber=$trackRow.track
        $trackAmount=$trackRow.amount
        $numberedTracks=$files | where {$_.name -like "$tracknumber*"}

        DO {     

            $randomTracks = Get-Random -InputObject $numberedTracks -Count $trackAmount
            
           Write-Host "Random track selected: " $randomTracks.name
           } 
           until ($randomTracks.FullName -notin $copiedTracks)
     }
            }
    
    
    $playliststartNumberCounter ++
    }  
            foreach ($track in $randomTracks){
                Copy-Item -LiteralPath $track.FullName -Destination $currentPlaylistLocation
                $copiedTracks += $track.FullName
                
        
    Write-Host $copiedTracks.FullName

