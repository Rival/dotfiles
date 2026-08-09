# Storage Map

## Disks

| Device | Size | Type | Model |
|--------|------|------|-------|
| sda | 1,8T | SSD/NVMe | Samsung |
| sdb | 476,9G | SSD/NVMe | Patriot |
| sdc | 931,5G | SSD/NVMe | WDC |
| zram0 | 62,7G | SSD/NVMe | 0 |
| nvme1n1 | 3,6T | SSD/NVMe | Samsung |
| nvme0n1 | 3,6T | SSD/NVMe | CT4000P3PSSD8 |

## Mount Points

| Mount | Device | FS | Size | Used | Avail | Use% |
|-------|--------|-----|------|------|-------|------|
| / | /dev/nvme1n1p5[/@] | btrfs | 1000,7G | 719,6G | 273,3G | 72% |
| /srv | /dev/nvme1n1p5[/@srv] | btrfs | 1000,7G | 719,6G | 273,3G | 72% |
| /root | /dev/nvme1n1p5[/@root] | btrfs | 1000,7G | 719,6G | 273,3G | 72% |
| /home | /dev/nvme1n1p5[/@home] | btrfs | 1000,7G | 719,6G | 273,3G | 72% |
| /mnt/mint | /dev/nvme1n1p4 | ext4 | 530,1G | 306,3G | 196,8G | 58% |
| /mnt/Patriot512GB | /dev/sdb2 | fuseblk | 476,9G | 213,8G | 263,1G | 45% |
| /mnt/WD1TB | /dev/sdc1 | ext4 | 915,8G | 361,8G | 507,4G | 40% |
| /mnt/Windows | /dev/nvme1n1p2 | fuseblk | 1,9T | 1T | 862,4G | 55% |
| /mnt/Downloads2TB | /dev/sda1 | fuseblk | 1,8T | 1,7T | 122,7G | 93% |
| /mnt/Crucial4TB | /dev/nvme0n1p2 | fuseblk | 3,6T | 2,5T | 1,1T | 69% |

## Key Directories

### /home/andrei

| Directory | Purpose |
|-----------|---------|
| `Applications/` | |
| `BiglyBT Downloads/` | |
| `Builds/` | |
| `Desktop/` | |
| `Documents/` | |
| `Downloads/` | |
| `Games/` | |
| `Library/` | |
| `Music/` | |
| `Pictures/` | |
| `Projects/` | |
| `Public/` | |
| `Repositories/` | |
| `Templates/` | |
| `Unity/` | |
| `Unity user templates/` | |
| `UnityBuildReports/` | |
| `Videos/` | |
| `Work/` | |
| `cli/` | |

### /home

| Directory | Purpose |
|-----------|---------|
| `andrei/` | |

### /mnt/mint

| Directory | Purpose |
|-----------|---------|
| `SteamLibrary/` | |
| `Unity/` | |

### /mnt/Patriot512GB

| Directory | Purpose |
|-----------|---------|
| `$RECYCLE.BIN/` | |
| `Backup/` | |
| `Movies/` | |
| `System Volume Information/` | |
| `Tiers/` | |

### /mnt/WD1TB

| Directory | Purpose |
|-----------|---------|
| `Downloads/` | |
| `Movies/` | |
| `emudeck/` | |
| `lost+found/` | |
| `wii_u_roms/` | |

### /mnt/Windows

| Directory | Purpose |
|-----------|---------|
| `$GetCurrent/` | |
| `$Recycle.Bin/` | |
| `AMD/` | |
| `Config.Msi/` | |
| `Documents and Settings/` | |
| `Hobby/` | |
| `Intel/` | |
| `Keys/` | |
| `Logs/` | |
| `OneDriveTemp/` | |
| `Program Files/` | |
| `Program Files (x86)/` | |
| `ProgramData/` | |
| `Recovery/` | |
| `SSH/` | |
| `System Volume Information/` | |
| `Total Commander Extended/` | |
| `TotalCmdExt/` | |
| `Users/` | |
| `Windows/` | |
| `Work/` | |
| `XboxGames/` | |
| `boot/` | |
| `inetpub/` | |

### /mnt/Downloads2TB

| Directory | Purpose |
|-----------|---------|
| `Downloads/` | |
| `Porn/` | |
| `System Volume Information/` | |

### /mnt/Crucial4TB

| Directory | Purpose |
|-----------|---------|
| `$RECYCLE.BIN/` | |
| `4DefaultTempSaveScan/` | |
| `Backup/` | |
| `Documents/` | |
| `Downloads/` | |
| `Emulation/` | |
| `Family/` | |
| `Games/` | |
| `Photo/` | |
| `Recover/` | |
| `Soft/` | |
| `Steam/` | |
| `System Volume Information/` | |
| `emudeck/` | |
| `promet/` | |


## Knowledge Zones

| Domain | Path | Type | Load Rule | Description |
|--------|------|------|----------|-------------|
| keymaps | `/home/andrei/.config/keymaps` | 🏠 domain+storage | **ALWAYS** | Cross-app keyboard layout mappings (prometeus ↔ ru) and twin-binding generators |
| emulation | `/mnt/Crucial4TB/Emulation` | 🏠 domain+storage | **ALWAYS** | Emulation collection |
