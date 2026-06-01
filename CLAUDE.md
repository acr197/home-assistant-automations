# CLAUDE.md — Home Assistant project instructions

These rules apply to the home-assistant-automations repo only. They extend the global CLAUDE.md and take precedence for HA-specific behavior.

## Output behavior

Never edit files directly. Always output the full updated code block for the user to copy and paste. Do not use file editing tools unless explicitly asked.

## Repo behavior

git_push.sh force-pushes intentionally. The Pi is the source of truth. Do not change this to a normal push.

This repo syncs to a Raspberry Pi 4 running Home Assistant OS. Changes pushed to GitHub are pulled to the Pi via the GitHub Sync add-on.

## Dashboard and Lovelace rules

Do not modify card height, min_height, aspect_ratio, or layout dimensions on any dashboard or Lovelace YAML unless the task explicitly asks for it.

When editing dashboard YAML, output the full updated file or section, not a diff. The user will copy and paste it into Studio Code Server on the Pi.

## Config structure

- /config — root HA config directory on the Pi
- /config/dashboards — Lovelace dashboard YAML files
- /config/automations.yaml — all automations
- /config/scenes.yaml — scenes
- /config/scripts.yaml — scripts
- /config/appdaemon — AppDaemon Python scripts
- /config/custom_components — custom integrations
- /config/www — static assets (images, etc.)

## Integrations in use

- Hue lights via Philips Hue integration
- Sonos speakers
- Nest thermostat
- Govee sensors
- Hatch Rest (nursery)
- ESPHome devices
- AppDaemon for Python-based automations

## Sensitive files

secrets.yaml exists and contains API keys and tokens. Never output its contents. Never suggest hardcoding values that should live in secrets.yaml.
