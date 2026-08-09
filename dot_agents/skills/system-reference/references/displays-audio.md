# Displays & Audio

## Displays

| Monitor | Resolution | Refresh | Position | Primary |
|---------|-----------|---------|----------|---------|
| DP-1 | 1440x2560 | 143.91Hz | 0,0 | No |
| DP-2 | 1440x2560 | 59.91Hz | 1440,0 | No |
| HDMI-A-2 | 3840x2160 | 119.86Hz | 2880,0 | No |

## Audio Output

| Device | Description | Default |
|--------|-------------|---------|
| alsa_output.usb-Sennheiser_GSX_1000_Main_Audio_5698800039033011-00.analog-output-surround71 | GSX 1000 Main Audio analog-output-surround71 | No |
| alsa_output.usb-Sennheiser_GSX_1000_Main_Audio_5698800039033011-00.analog-chat-output | GSX 1000 Main Audio analog-chat-output | No |
| alsa_output.pci-0000_09_00.1.hdmi-stereo-extra2 | GA102 High Definition Audio Controller Digital Stereo (HDMI 3) | Yes |

## Audio Input

| Device | Description | Default |
|--------|-------------|---------|
| alsa_input.usb-EMEET_EMEET_SmartCam_C960_2K_SN20230302-02.analog-stereo | EMEET SmartCam C960 2K Analog Stereo | Yes |
| alsa_input.usb-Sennheiser_GSX_1000_Main_Audio_5698800039033011-00.analog-chat-input | GSX 1000 Main Audio analog-chat-input | No |

## Audio routing notes & quick fixes

Audio card (Nvidia GPU HDMI): `alsa_card.pci-0000_09_00.1`

| Port | Device | Notes |
|------|--------|-------|
| HDMI 2 | QCQ90 TV (main TV output) | профиль `output:hdmi-stereo-extra1`, поддержка PCM/AC3/EAC3/TrueHD |
| HDMI 1 | Lenovo L27q-10 | без динамиков, только PCM |
| USB | Sennheiser GSX 1000 | 7.1 surround |

**Quick fix — переключить звук на TV (HDMI 2):**
```bash
pactl set-card-profile alsa_card.pci-0000_09_00.1 output:hdmi-stereo-extra1
pactl set-default-sink alsa_output.pci-0000_09_00.1.hdmi-stereo-extra1
```

Частая проблема: выбран не тот HDMI-порт (1 vs 2) → нет звука на TV.