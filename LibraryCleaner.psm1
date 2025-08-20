
# Library Cleaner
# Author: Rashad-07
# Version: 1.0.0

function Get-MissingGames {
    # Uses global $PlayniteApi
    $missingGames = New-Object System.Collections.Generic.List[Playnite.SDK.Models.Game]
    $allGames = $PlayniteApi.Database.Games
    $global:LC_Scanned = 0

    foreach ($game in $allGames) {
        $global:LC_Scanned++
        if (-not $game.IsInstalled) {
            continue
        }

        # Skip emulated games
        $isEmulated = $false
        if ($game.GameActions) {
            foreach ($action in $game.GameActions) {
                if ($action.Type -eq [Playnite.SDK.Models.GameActionType]::Emulator) {
                    $isEmulated = $true
                    break
                }
            }
        }
        if (-not $isEmulated -and $game.Roms -and $game.Roms.Count -gt 0) {
            $isEmulated = $true
        }
        if ($isEmulated) {
            continue
        }

        # Check InstallDirectory existence
        $dir = $game.InstallDirectory
        if ([string]::IsNullOrWhiteSpace($dir)) {
            continue
        }
        if (-not (Test-Path $dir)) {
            $missingGames.Add($game) | Out-Null
        }
    }

    return $missingGames
}

function GetMainMenuItems {
    param($args)
    $menuItem = New-Object Playnite.SDK.Plugins.ScriptMainMenuItem
    $menuItem.Description = "List Missing Games To Remove"
    $menuItem.FunctionName = "LibraryCleaner_RemoveMissingGames"
    $menuItem.MenuSection = "@Library Cleaner"
    return $menuItem
}

function LibraryCleaner_RemoveMissingGames {
    param($scriptArgs)

    $title = "Library Cleaner"
    $games = Get-MissingGames
    $count = $games.Count

    if ($count -eq 0) {
        $PlayniteApi.Dialogs.ShowMessage("Nothing to remove.", $title) | Out-Null
        return
    }

    $names = ($games | ForEach-Object { $_.Name }) -join "`n"
    $msg = "Found $count missing games to remove:`n`n$names`n`nDo you want to remove them?"
    $res = $PlayniteApi.Dialogs.ShowMessage($msg, $title, [System.Windows.MessageBoxButton]::YesNo)

    if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
        $removed = 0
        foreach ($g in $games) {
            try {
                $PlayniteApi.Database.Games.Remove($g.Id)
                $removed++
            } catch {
                $PlayniteApi.Log.Warn("Library Cleaner: failed to remove {0} ({1}) - {2}" -f $g.Name, $g.Id, $_.Exception.Message)
            }
        }
        $PlayniteApi.Dialogs.ShowMessage(("Scanned: {0}, Removed: {1}" -f $global:LC_Scanned, $removed), $title) | Out-Null
    }
}
