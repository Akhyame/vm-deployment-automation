<#
Fichier de fonctions pour le déploiement de VMs
#>

# Fonction de logging
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [ValidateSet("Info","Warning","Error","Debug","Success")]
        [string]$Level = "Info",
        
        [string]$LogFile
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$($Level.ToUpper())] $Message"
    
    # Écriture dans le fichier de log
    if (-not $LogFile) {
        $LogFile = $global:LogFile
    }
    
    Add-Content -Path $LogFile -Value $logEntry
    
    # Affichage console avec couleurs
    switch ($Level) {
        "Error"   { Write-Host $logEntry -ForegroundColor Red }
        "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
        "Success" { Write-Host $logEntry -ForegroundColor Green }
        "Debug"   { Write-Host $logEntry -ForegroundColor Gray }
        default   { Write-Host $logEntry }
    }
}

function Initialize-Logging {
    param(
        [string]$ConfigPath
    )
    
    $logDir = "$PSScriptRoot/../logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $logDate = Get-Date -Format "yyyyMMdd-HHmmss"
    $logFile = "$logDir/deployment_$logDate.log"
    
    # Création du fichier vide
    "" | Out-File -FilePath $logFile
    
    # Stockage dans une variable globale
    $global:LogFile = $logFile
    
    return $logFile
}

function Load-Configuration {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    try {
        if (-not (Test-Path $Path)) {
            throw "Fichier de configuration introuvable: $Path"
        }
        
        $config = Get-Content $Path -Raw | ConvertFrom-Json
        
        # Validation basique
        if (-not $config.vcenter.server) {
            throw "Configuration invalide: serveur vCenter non spécifié"
        }
        
        return $config
    } catch {
        Write-Log "Erreur lors du chargement de la configuration: $_" -Level Error
        throw
    }
}

function Connect-vCenter {
    param(
        [string]$Server,
        [string]$User,
        [string]$Password
    )
    
    try {
        Write-Log "Connexion à vCenter $Server..."
        $connection = Connect-VIServer -Server $Server -User $User -Password $Password -ErrorAction Stop
        
        Write-Log "Connecté à vCenter version $($connection.Version)" -Level Success
        return $connection
    } catch {
        Write-Log "Échec de la connexion à vCenter: $_" -Level Error
        throw
    }
}

function Test-DeploymentPrerequisites {
    param(
        [object]$Config
    )
    
    Write-Log "Vérification des prérequis..."
    
    # Vérification du template
    $template = Get-Template -Name $Config.vm_parameters.template -ErrorAction SilentlyContinue
    if (-not $template) {
        throw "Template '$($Config.vm_parameters.template)' introuvable"
    }
    
    # Vérification du datastore
    $datastore = Get-Datastore -Name $Config.infrastructure.datastore -ErrorAction SilentlyContinue
    if (-not $datastore) {
        throw "Datastore '$($Config.infrastructure.datastore)' introuvable"
    }
    
    Write-Log "Tous les prérequis sont satisfaits" -Level Success
}

function New-VMFromTemplate {
    param(
        [object]$Config
    )
    
    try {
        $vmParams = @{
            Template = $Config.vm_parameters.template
            Name = $Config.vm_parameters.name
            Location = (Get-Folder -Name $Config.vm_parameters.folder -ErrorAction Stop)
            VMHost = (Get-Cluster -Name $Config.infrastructure.cluster | Get-VMHost | Select-Object -First 1)
            Datastore = (Get-Datastore -Name $Config.infrastructure.datastore -ErrorAction Stop)
            ResourcePool = (Get-ResourcePool -Name $Config.infrastructure.resource_pool -ErrorAction Stop)
            ErrorAction = "Stop"
        }
        
        Write-Log "Début du clonage du template vers $($Config.vm_parameters.name)"
        $newVm = New-VM @vmParams
        
        Write-Log "VM créée avec succès" -Level Success
        return $newVm
    } catch {
        Write-Log "Erreur lors du clonage de la VM: $_" -Level Error
        throw
    }
}

function Configure-VM {
    param(
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]$VM,
        [object]$Config
    )
    
    try {
        Write-Log "Configuration de la VM $($VM.Name)"
        
        # Configuration CPU
        $cpuParams = @{
            VM = $VM
            NumCpu = $Config.vm_parameters.cpu.count
            CoresPerSocket = $Config.vm_parameters.cpu.cores_per_socket
            Confirm = $false
            ErrorAction = "Stop"
        }
        Set-VM @cpuParams
        
        # Configuration mémoire
        Set-VM -VM $VM -MemoryGB $Config.vm_parameters.memory_gb -Confirm:$false -ErrorAction Stop
        
        # Configuration réseau
        $networkAdapter = Get-NetworkAdapter -VM $VM
        Set-NetworkAdapter -NetworkAdapter $networkAdapter -NetworkName $Config.vm_parameters.network.name -Confirm:$false -ErrorAction Stop
        
        # Personnalisation supplémentaire (nécessite VMware Tools)
        if ($Config.customization) {
            $customSpec = New-OSCustomizationSpec -Config $Config
            Set-VM -VM $VM -OSCustomizationSpec $customSpec -Confirm:$false
        }
        
        Write-Log "Configuration terminée avec succès" -Level Success
    } catch {
        Write-Log "Erreur lors de la configuration de la VM: $_" -Level Error
        throw
    }
}