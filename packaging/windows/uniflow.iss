; Installeur Windows d'UniFlow Desktop : emballe le dossier `Release` produit par
; `flutter build windows --release` en un seul .exe autonome.
;
; Autonome veut dire « sans téléchargement » : la politique du Microsoft Store
; pour les installateurs EXE/MSI interdit les stubs qui vont chercher des bits
; au premier lancement, et winget exige la même chose. Tout doit être dans l'`.exe`.
;
; La CI appelle ISCC avec trois définitions (voir .github/workflows/ci.yml) :
;   /DVersion=1.0.0.1                 quatre segments, format Windows
;   /DWorkspace=<absolu>\Release      sortie de `flutter build windows`
;   /DOutput=<absolu>\dist\windows    dossier de l'installateur
; Les valeurs par défaut ci-dessous servent aux essais depuis Visual Studio.

#define AppName      "UniFlow"
#define AppPublisher "KERNEL FORGE"
#define AppExeName   "uniflow_app.exe"

; AppId n'est pas un texte décoratif : c'est la clé sous laquelle Windows range
; l'entrée de désinstallation et les pages « Applications et fonctionnalités ».
; Changer cette valeur ferait voir deux UniFlow installés après une mise à jour,
; et l'ancien ne se désinstallerait plus depuis le Panneau de configuration.
#define AppId "{{8F4C1D7B-5A62-4E9F-9C31-2D7E8B0A4F55}"

#ifndef Version
  #define Version "0.0.0.0"
#endif
#ifndef Workspace
  #define Workspace "..\..\build\windows\x64\runner\Release"
#endif
#ifndef Output
  #define Output "..\..\dist\windows"
#endif

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#Version}
AppVerName={#AppName} {#Version}
AppPublisher={#AppPublisher}
AppPublisherURL=https://uniflow.kernelforge.codes
AppSupportURL=https://uniflow.kernelforge.codes
AppUpdatesURL=https://github.com/KERNEL-FORGE-G/uniflow-desktop/releases/latest
DefaultDirName={autopf}\UniFlow
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableReports=yes
; Le chemin d'installation porte le nom long et l'architecture : un étudiant qui
; hésite entre les deux finds sait lequel il a téléchargé.
OutputDir={#Output}
OutputBaseFilename=uniflow-desktop-{#Version}-x64
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}
UninstallFilesDir={app}
; `x64compatible` (Inno 6.3+) couvre x64 et ARM64 sur Windows ARM ; l'application
; elle-même n'est compilée qu'en x64, donc le refus des x86 purs est voulu.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
; Admin par défaut (le Store lance l'installateur avec élévation, et UAC reste
; permis), mais `-ConfirmCommandLine:allusers`/dialog autorise un choix
; « seulement moi » sur un poste d'étudiant sans droit d'administrateur.
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
Compression=lzma2/ultra64
LZMADictionarySize=max
LZMACompressionThreads=inherit
SolidCompression=yes
WizardStyle=modern
VersionInfoVersion={#Version}
VersionInfoCompany={#AppPublisher}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#Version}
VersionInfoDescription={#AppName} {#Version} - installateur x64
; En cas de relance pendant que l'application tourne, Inno demande de la fermer
; plutôt que de laisser des .dll verrouillés à moitié écrasés.
CloseApplications=yes
RestartApplications=no

[Files]
; `ignoreversion` : le dossier Release est toujours celui de la version en cours,
; il n'y a rien à comparer. Sans ce drapeau Inno refuserait d'écraser un fichier
; dont il lit une version supérieure dans les ressources.
Source: "{#Workspace}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{group}\Désinstaller {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Créer un raccourci sur le Bureau"; GroupDescription: "Raccourcis supplémentaires:"; Flags: unchecked

[Run]
; `runascurrentuser` : installé en admin, l'application ne doit pas rester liée
; au jeton élevé (la visioconférence écrit dans %APPDATA% de l'utilisateur).
Filename: "{app}\{#AppExeName}"; Description: "Lancer {#AppName}"; Flags: nowait postinstall skipifsilent runascurrentuser

; ---- Signature ----------------------------------------------------------------
; Le Microsoft Store (voie EXE/MSI) exige que l'installateur ET tous les fichiers
; PE qu'il contient soient signés par une CA du programme « Microsoft Trusted
; Root ». L'order compte : signer chaque DLL/EXE du dossier Release AVANT ISCC,
; puis l'installateur, puis `SignedUninstaller` régénère un uninstall.exe signé
; à la désinstallation. Sans certificat, laisser SignTool vide : winget accepte
; un installeur non signé, le Store non.
;
; CI :  iscc /DSignTool=namescript ...  avec le certificat importé au préalable.
#ifdef SignTool
SignTool={#SignTool}
SignedUninstaller=yes
#endif
