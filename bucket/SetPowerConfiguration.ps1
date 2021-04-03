Write-Host 'Setting Power Configuration...'

# Battery
powercfg /change monitor-timeout-dc 5
powercfg /change standby-timeout-dc 10
powercfg /change hibernate-timeout-dc 60

# Plugged In
powercfg /change monitor-timeout-ac 10
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0

Write-Host @'
Power Configuration Updated:
    Battery
        monitor-timeout-dc: 5
        standby-timeout-dc: 10
        hibernate-timeout-dc: 60
    Plugged In
        monitor-timeout-ac: 10
        standby-timeout-ac: 0
        hibernate-timeout-ac: 0
'@