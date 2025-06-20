README - Script de Déploiement Automatisé de VMs VMware
📌 Description
Ce projet permet de déployer automatiquement des machines virtuelles (VMs) VMware à partir d'un template, en utilisant PowerShell et PowerCLI. Il est conçu pour :
✅ Standardiser les déploiements
✅ Économiser du temps en évitant les configurations manuelles
✅ Réduire les erreurs grâce à l'automatisation
📂 Structure du Projet :
vm-deployment/  
├── config/  
│   └── vm-config.json          # Configuration principale  
├── scripts/  
│   ├── deploy-vm.ps1           # Script principal  
│   └── functions.ps1           # Fonctions PowerShell  
├── templates/  
│   └── vm-template-config.json # Template de configuration  
└── logs/  
    └── deployment.log          # Fichier de logs généré automatiquement  
⚙️ Prérequis
VMware vCenter accessible

PowerShell 5.1+ (ou PowerShell Core)

Module PowerCLI (installable via Install-Module VMware.PowerCLI)
🚀 Utilisation
1. Configuration
📝 Modifier config/vm-config.json avec vos paramètres :
{
    "vcenter": {
        "server": "vcenter.mondomaine.com",
        "username": "admin",
        "password": "motdepasse"
    },
    "vm_parameters": {
        "template": "Template-Ubuntu-22.04",
        "name": "MaNouvelleVM",
        "cpu": { "count": 2, "cores_per_socket": 1 },
        "memory_gb": 4,
        "network": {
            "name": "VLAN_PROD",
            "ip_address": "192.168.1.100"
        }
    }
}
2. Exécution
▶ Lancer le script :
cd vm-deployment/scripts  
.\deploy-vm.ps1 -ConfigPath ..\config\vm-config.json
3. Résultats
✔ Une nouvelle VM est créée dans vCenter
✔ Les logs sont enregistrés dans logs/deployment_<DATE>.log
📝 Fonctionnalités Clés
🔹 Gestion des erreurs : Vérifie les prérequis avant déploiement
🔹 Logging détaillé : Trace toutes les étapes
🔹 Modulaire : Fonctions séparées pour maintenance facile
🔹 Sécurité : Déconnexion automatique de vCenter
