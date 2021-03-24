# Biwako Acami 

Param(
    $WormholeMass
    , $RollingBattleshipMass
    , $RollingSupportMass
    , [Switch]$SupportPropHiggs=$false
    , $DeviationMinimum = 0
    , [Switch]$NoConsoleOutput=$false
)

Begin {

    # 0 - Rolling Mass
    # 1 - OUT/IN
    # 2 - Remaining Mass
    $CallingFormat = '{2} left after {0} {1}'
    
    # 0 - Working Wormhole Mass
    # 1 - Working Wormhole Deviation
    # 2 - Battleship Mass
    # 3 - Support Mass
    # 4 - Success
    $ReportFormat = 'Mass: {0} | Deviation: {1} | Battleship Mass: {2} | Support Mass: {3} | Success: {4}'
    $SimulationFormat = '{0}, {1}, {2}, {3}, {4}'

    $HeadingFormat =  'Wormhole Mass: {0} | Deviation: {1} | Battleship Mass: {2} | Support Mass: {3}'

    $Timestamp = (Get-Date -Format "yyyyMMddHHmmss")
    $FailuresFile = 'failures-{0}.log' -f $Timestamp
    $SimulationFile = 'simulation-{0}.csv' -f $Timestamp
    $DetailsFile = 'details-{0}.txt' -f $Timestamp
    "Mass, Deviation, BattleshipMass, IndustrialMass, Success" | Out-File -FilePath $SimulationFile -Force
    "" | Out-File -FilePath $FailuresFile -Force
    "" | Out-File -FilePath $DetailsFile -Force

    $VarianceLow = $WormholeMass * 0.9
    $VarianceHigh = $WormholeMass * 1.1

    function Roll-Wormhole {
        Param(
            $WormholeMass   
            , $Deviation
            , $RollingBattleshipMass
            , $RollingSupportMass
            , [Switch]$SupportPropHiggs=$false
        )
        
        Begin {
            $Script:ShrinkPoint = $WormholeMass * 0.5
            $Script:CritPoint = $WormholeMass * 0.1
            $Script:RemainingMass = $WormholeMass - $Deviation
            $Script:PropulsionMassHiggs = 100
            $Script:PropulsionMassNoHiggs = 50
            
            $Script:WayIn = $False
            $Script:ShrinkCalled = $False
            $Script:CritCalled = $False
            $LastJump = $False

            $Script:Plan = @("")
            $Script:Nutshell = ""

            if($Script:SupportPropHiggs) {
                $Script:SupportPropulsionMass = $Script:PropulsionMassHiggs
            } else {
                $Script:SupportPropulsionMass = $Script:PropulsionMassNoHiggs
            }

            function Jump-Wormhole {
                Param(
                    $Mass
                )
                
                $Script:RemainingMass = $Script:RemainingMass - $Mass
                if ($Script:WayIn) { 
                    $Script:Plan += ($CallingFormat -f $Mass, "IN", $Script:RemainingMass) 
                    $Script:Nutshell += ("{0} ({1}) > " -f $Script:RemainingMass, $Mass)
                }
                else { 
                    $Script:Plan += ($CallingFormat -f $Mass, "OUT", $Script:RemainingMass) 
                    $Script:Nutshell += ("{0} ({1}) > " -f $Script:RemainingMass, $Mass)
                }
                $Script:WayIn = -not $Script:WayIn
        
                if(-not $Script:ShrinkCalled -and $Script:RemainingMass -le $Script:ShrinkPoint) {
                    $Script:Plan += "SHRINK!"
                    $Script:Nutshell += ("SHRINK" + " > ")
                    $Script:ShrinkCalled = $True
                }
                if(-not $Script:CritCalled -and $Script:RemainingMass -le $Script:CritPoint) {
                    $Script:Plan += "CRIT!"
                    $Script:Nutshell += ("CRIT" + " > ")
                    $Script:CritCalled = $True
                }

                if($Script:RemainingMass -le 0) {
                    if($Script:WayIn) {
                        throw 'ROLLED OUT!'
                    } else {
                        throw 'PHEW!'
                    }
                }
            }
        }

        Process {
            $Success = "No"

            $Script:Nutshell += ("{0} > " -f $Script:RemainingMass)
            try {
                # Roll till shrink
                while ($Script:RemainingMass -gt $Script:ShrinkPoint) {
                    #Write-Host ('{0};{1};{2}' -f $Script:RemainingMass, $Script:ShrinkPoint, ($Script:RemainingMass -gt $Script:ShrinkPoint))
                    Jump-Wormhole -Mass ($Script:RollingBattleshipMass + $Script:PropulsionMassHiggs)
                }

                # Roll remaining
                if(-not $Script:WayIn) {
                    for($i = 0; $i -lt 3; $i++) {
                        Jump-Wormhole -Mass $Script:RollingBattleshipMass
                    }
                } else {
                    for($i = 0; $i -lt 2; $i++) {
                        Jump-Wormhole -Mass ($Script:RollingBattleshipMass + $Script:PropulsionMassHiggs)
                    }
                }

                # Jump something to adjust mass
                while ($Script:RemainingMass -gt $Script:CritPoint) {
                    #Xanne Rolling
                    Jump-Wormhole -Mass $Script:RollingSupportMass + $Script:SupportPropulsionMass
                    #Danny Rolling
                    if($Script:RemainingMass -gt $Script:CritPoint) {
                        Jump-Wormhole -Mass ($Script:RollingSupportMass + $Script:SupportPropulsionMass)
                    } else {
                        Jump-Wormhole -Mass $Script:RollingSupportMass
                    }
                    
                }
                $LastJump = $True

                # Final Roll
                Jump-Wormhole -Mass ($Script:RollingBattleshipMass + $Script:PropulsionMassHiggs)
            } catch {
                if($_.FullyQualifiedErrorId -eq 'PHEW!') {
                    if($LastJump) {
                        $Success = "Yes"
                        $Script:Plan += "Planned Close."
                        $Script:Nutshell += ("Planned Close.")
                    } else {
                        $Success = "Maybe"
                        $Script:Plan += "Closed Early!"
                        $Script:Nutshell += ("Closed Early!")
                    }
                } elseif ($_.FullyQualifiedErrorId -eq 'ROLLED OUT!') {
                    $Script:Plan += "Rolled OUT!`n"
                    $Script:Nutshell += ("Rolled OUT!")
                }
            }

            New-Object -TypeName PSObject -Property @{
                Success = $Success
                Plan = $Script:Plan
                Nutshell = $Script:Nutshell
            }
        }
    }

    
}

Process {

    $VarianceLow..$VarianceHigh | ForEach-Object {
        $CurrentWormholeMass = $_
        $DeviationHigh = ($_ * 0.5) - 1 
        $DeviationMinimum..$DeviationHigh | ForEach-Object {
            $Deviation = $_
            $Heading = ($HeadingFormat -f $CurrentWormholeMass, $Deviation, $RollingBattleshipMass, $RollingSupportMass)
            if(-not $NoConsoleOutput) {
                Write-Host $Heading
            }
            $Heading | Out-File -FilePath $DetailsFile -Append

            $Status = Roll-Wormhole `
                -WormholeMass $CurrentWormholeMass `
                -Deviation $Deviation `
                -RollingBattleshipMass $RollingBattleshipMass `
                -RollingSupportMass $RollingSupportMass
            
            $Result = $ReportFormat -f $CurrentWormholeMass `
                , $Deviation `
                , $RollingBattleshipMass `
                , $RollingSupportMass `
                , $Status.Success

            $SimulationFormat -f $CurrentWormholeMass `
            , $Deviation `
            , $RollingBattleshipMass `
            , $RollingSupportMass `
            , $Status.Success | Out-File -FilePath $SimulationFile -Append

            $Status.Nutshell | Out-File -FilePath $DetailsFile -Append

            if($Status.Success -ne 'Yes') {
                $Result | Out-File -FilePath $FailuresFile -Append
                $Status.Plan | Out-File -FilePath $FailuresFile -Append
                if(-not $NoConsoleOutput) {
                    Write-Host $Result
                    Write-Host "Here's how it happened:"
                    Write-Host $Status.Nutshell
                }
            }
        }
    }
}
