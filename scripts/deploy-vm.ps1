# Importe les fonctions depuis functions.ps1
. "$PSScriptRoot/functions.ps1"

try {
    # Initialise le fichier de log
    $logFile = Initialize-Logging -ConfigPath $ConfigPath

    # Étape 1 : Charge la configuration JSON
    $config = Load-Configuration -Path $ConfigPath
    Write-Log "Configuration chargée depuis $ConfigPath"

    # Étape 2 : Connexion à vCenter
    Connect-vCenter -Server $config.vcenter.server `
                   -User $config.vcenter.username `
                   -Password $config.vcenter.password

    # Étape 3 : Vérifie que le template et les ressources existent
    Test-DeploymentPrerequisites -Config $config

    # Étape 4 : Clone le template pour créer la VM
    $vm = New-VMFromTemplate -Config $config

    # Étape 5 : Configure la VM (CPU, RAM, réseau)
    Configure-VM -VM $vm -Config $config

    # Étape 6 : Démarre la VM
    Start-VM -VM $vm -Confirm:$false
    Write-Log "VM démarrée avec succès" -Level Success

} catch {
    # Gestion des erreurs
    Write-Log "ERREUR: $_" -Level Error
    exit 1
} finally {
    # Déconnexion de vCenter même en cas d'erreur
    if ($global:DefaultVIServers) {
        Disconnect-VIServer -Server * -Confirm:$false
    }
}