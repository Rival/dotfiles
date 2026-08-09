# Known System Issues

> Active bugs and workarounds specific to this machine. Check here before debugging GUI/system anomalies.

---

## Pacman signature "marginal trust" / "unknown trust" errors

**Symptom:** Установка/sync падает с `signature from "..." is marginal trust` или `... is unknown trust`, пакет считается corrupted. Причина — устаревшая/битая gpg trustdb keyring.

**Fix (по возрастанию тяжести):**

1. **Простейший (решил 2026-06-16):**
   ```
   sudo pacman -Sy archlinux-keyring
   ```
   Тянет свежий keyring + сам пересобирает trust. Пробовать первым.

2. Пересборка trustdb без reinit:
   ```
   sudo pacman-key --populate archlinux && sudo pacman-key --updatedb
   ```

3. Ядерный reinit (стирает всю gpg-базу):
   ```
   sudo rm -rf /etc/pacman.d/gnupg
   sudo pacman-key --init
   sudo pacman-key --populate archlinux
   ```

**CachyOS gotcha (зуб даю):** полный reinit стирает trust и для CachyOS-ключей тоже. После reinit нужно популейтить **оба** keyring, иначе repos (`cachyos-v3` и т.п.) падают с `unknown trust` от `CachyOS <admin@cachyos.org>`:
```
sudo pacman-key --populate archlinux
sudo pacman-key --populate cachyos
```

**Точечный фикс одного ключа:** `sudo pacman-key --lsign-key <KEYID>` — подписывает ключ локальным master-ключом (ultimate trust) → validity станет full.

**Замечание:** `sudo` требует реального tty — Claude Bash и `!`-префикс оба без tty, команды с sudo юзер запускает в своём терминале.

---

## GTK4 Wayland apps hang at startup (since 2026-04-25)

**Symptom:** Любая GTK4 app (Lumux, минимальный native gtk4 C-tест, etc.) запускается, выводит первые сообщения, потом виснет на 99% CPU. `activate` сигнал GApplication никогда не fires, окна нет в `hyprctl clients` / `wmctrl`. Воспроизводится **и в Hyprland, и в KDE Plasma Wayland session** — значит проблема не в compositor.

**Root cause (зуб даю):** `wayland 1.25.0-1.1` обновление от 2026-04-25 регрессировало handshake с GTK4 4.22.3.

`pacman.log` 2026-04-25:
```
upgraded glibc      (2.43-r4 → 2.43-r22)
upgraded wayland    (1.24.0-1.1 → 1.25.0-1.1)   ← виновник
upgraded gtk4       (4.22.2 → 4.22.3)
```

Wayland trace (`WAYLAND_DEBUG=1`) обрывается сразу после:
```
wl_registry#2.bind(60, "xdg_wm_base", 6, new id [unknown]#43)
```
xdg_wm_base v6 поддерживается compositor (KWin даёт v6). После bind тишина — async dispatch не получает ответа. **Не GPU/nvidia** (software renderers cairo/ngl/vulkan все висят одинаково).

**Workarounds:**

1. **X11 backend** для конкретного app:
   ```
   GDK_BACKEND=x11 <app>
   ```
   Native GTK4 app работает (CPU 6%, окно есть). Для flatpak нужен также `--socket=x11` (см. ниже flatpak issue).

2. **Downgrade wayland**:
   ```
   sudo downgrade wayland
   ```
   Выбрать `wayland-1.24.0-1.1`. Добавить `IgnorePkg = wayland` в `/etc/pacman.conf` чтобы не вернулось.

3. Альтернатива — downgrade gtk4 до 4.22.2.

---

## Flatpak x11 socket bind broken на KDE Wayland session (Plasma 6.x + flatpak 1.16.6)

**Symptom:** Внутри flatpak sandbox `/tmp/.X11-unix/` пустой, `DISPLAY` env не установлен — несмотря на `sockets=x11;wayland;fallback-x11` в metadata. Делает невозможным `GDK_BACKEND=x11` workaround для flatpak GTK4 apps.

```
flatpak run --command=env io.github.enginkirmaci.lumux | grep DISPLAY
# (пусто)
flatpak run --command=ls io.github.enginkirmaci.lumux /tmp/.X11-unix/
# (пусто)
```

`flatpak override --user --env=DISPLAY=:0` тоже не пробрасывает. Hyprland session при этом нормально пробрасывал ранее. Проявляется именно на KDE Wayland session.

**Workaround:** для flatpak GTK4 apps использовать downgrade wayland (см. выше) вместо x11 fallback. Или запускать app не через flatpak, а нативно.

---

## XDG_DESKTOP_PORTAL_DIR пустой ломает xdg-desktop-portal Settings (исправлено)

**Symptom (был):** `gdbus call ... Settings.Read` возвращал `org.freedesktop.DBus.Error.UnknownMethod: No such interface "org.freedesktop.portal.Settings"`. Adwaita apps виснули в startup ожидая Settings portal.

В `systemctl --user show-environment` была установлена пустая `XDG_DESKTOP_PORTAL_DIR=` — она перезаписывала hardcoded дефолт `/usr/share/xdg-desktop-portal/portals`, и portal загружал backends "из пустоты":
```
load portals from         ← пустой путь
providing portal org.freedesktop.portal.Settings  ← НЕ появлялось
```

**Fix:** `systemctl --user unset-environment XDG_DESKTOP_PORTAL_DIR` (применено). Источник установки переменной не локализован — кандидаты: gamescope-session, KDE/SDDM autostart. После reboot переменная не возвращается, но если вернётся — искать в `/etc/profile.d/`, `~/.config/hypr/`, `~/.config/uwsm/`.

Дополнительный override-файл `~/.config/systemd/user/xdg-desktop-portal.service.d/debug.conf` оставлен — даёт `G_MESSAGES_DEBUG=all` и `StandardOutput=journal`. Можно удалить после стабилизации.

`~/.config/xdg-desktop-portal/hyprland-portals.conf` расширен явным mapping для Settings/FileChooser/Notification на `gtk;kde` (was: `org.freedesktop.impl.portal.* = hyprland;gtk;kde` wildcard).

---

## NVIDIA RTX 3080 GSP heartbeat timeouts → HDMI-A-2 freezes

**GPU:** RTX 3080 LHR (PCI 0000:09:00), driver nvidia-open 595.45.04

**Symptom:** GSP (GPU System Processor) heartbeat timeouts каждые 3-5 часов → фриз Samsung QCQ90 (HDMI-A-2). В kernel log Xid 56/69.

**Fix (применён 2026-03-26):** отключён GSP firmware:
- `/etc/modprobe.d/nvidia-gsp.conf` → `options nvidia NVreg_EnableGpuFirmware=0`
- нужен `sudo mkinitcpio -P` + reboot

> ⚠️ **2026-06-22 ОПРОВЕРЖЕНИЕ:** на `nvidia-open` модулях флаг `NVreg_EnableGpuFirmware=0` — **no-op**. Open-модули требуют GSP и грузят его всегда. Доказано: в логах краша полно `GspRmFree_GSP` / `rpcRmApiFree_GSP` RPC при выставленном флаге. Значит этот «фикс» был **плацебо** — GSP не отключался. Файл переименован в `nvidia-gsp.conf.disabled-20260622`. Если Xid 56/69 вернутся — флаг их не лечил, ищи другое (driver downgrade, мониторинг heartbeat, проверка контакта в слоте).

**«Перейти на проприетарный» больше не вариант:** CachyOS выпилил проприетарные kernel-модули для ветки 610 — в репах только `nvidia-open` / `nvidia-open-dkms`. Проприетарь = AUR/сборка руками.

---

## NVIDIA Xid 79 «GPU has fallen off the bus» → форс-ребут (контакт в слоте)

**GPU:** RTX 3080 (PCI 0000:09:00), nvidia-open 610.43.02

**Symptom (2026-06-22 15:31:57):** `NVRM Xid 79: GPU has fallen off the bus` + `Xid 154: recovery action → OS Reboot`. Карта исчезла с шины PCIe, драйвер сдался, лечит только перезагрузка. Следом — каскад `FULLCHIP_RESET` assertions и (через 5с) `mmuWalkUnmap` / `Flip event timeout` — это **посмертные** ошибки, не причина. Утянул Hyprland (watchdog SIGABRT) → Xwayland/hyprsunset/zen.

**Диагностика:** PCIe AER ошибок НЕТ — карта просто пропала. Класс события = железо/питание/контакт, не софт/конфиг.

**Вероятная причина:** видяха подушла/окислилась в слоте (Andrei: «такое частенько бывает»). **Лечение — реseat карты** (выключить, вынуть-вставить, при окислении почистить контакты ластиком/изопропанолом). Проверить также PCIe-power коннекторы (8-pin) — они тоже дают off-the-bus.

**Отличать от Xid 56/69 HDMI-фризов выше** — это другой баг. При зависании сразу снять `journalctl -b -1 -k | grep Xid` чтобы понять который.

---

## HDR washed-out colors после cold boot (HDMI-A-2)

**Symptom:** После холодной загрузки HDR на HDMI-A-2 (4K@120, RTX 3080, 595.x) выглядит выцветшим. `hyprctl reload` / toggle SDR↔HDR **не** помогает.

**Fix:** только полный suspend/resume GPU — `systemctl suspend` + wake. NVIDIA не инициализирует HDR metadata корректно при первом modeset; восстанавливает только teardown/rebuild GPU state (S3 с `NVreg_PreserveVideoMemoryAllocations=1`).

**НЕ предлагать** `hyprctl reload` / toggle монитора при жалобе «цвета бледные/выцвели» — бесполезно. Альтернативы (не пробованы): DPMS off/on, reload nvidia_drm.

Старый workaround `~/.config/hypr/scripts/fix-hdr-colors.sh` (toggle SDR→HDR через 0.5с) отключён 2026-04-25 — не лечил washed-out, а вызывал DRM page-flip storm + краш Hyprland через ~60с после cold boot.
