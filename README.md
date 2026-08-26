# SmartThings Edge Driver — Tuya Soil Moisture Sensor (HOBEIAN `ZG-303Z`)

## 🔗 Install (click to add the driver to your hub)

# **[bestow-regional.api.smartthings.com/invite/gV2qwyDydYj9](https://bestow-regional.api.smartthings.com/invite/gV2qwyDydYj9)**

After accepting: SmartThings app → your soil sensor → `...` menu → **Driver**
→ **Select different driver** → pick **tuya-soil-moisture-hobeian-zg303z**.

---

![Zigbee Soil Tester listing](https://github.com/user-attachments/assets/36ffda18-0b68-4796-ae0e-e3aaf38182b8)

Fixes Tuya **3-in-1** Zigbee soil sensors (`HOBEIAN` / `ZG-303Z`, sold as
"Zigbee Soil Tester Moisture Sensor Temperature Humidity Meter Luminance
Fertility Detector") whose real Soil Moisture reading gets mislabeled as
plain room "Humidity" by SmartThings' generic driver.

**Buy it:** [AliExpress listing](https://a.aliexpress.com/_mPCfepD)

## What it fixes

The sensor reports two genuinely separate values that SmartThings'
generic driver can't tell apart:

| Real signal | Source | This driver maps it to |
|---|---|---|
| Air Humidity | Standard Zigbee humidity cluster (`0x0405`) | `relativeHumidityMeasurement` |
| **Soil Moisture** | Tuya proprietary datapoint 109 (`0x6D`) on cluster `0xEF00` | Custom **Soil Moisture** capability |
| Air Temperature | Standard Zigbee cluster | `temperatureMeasurement` |
| Battery | Standard Zigbee cluster | `battery` |

Verified against two real units: air humidity swung widely (16–51%) like
real room air, while the DP109 soil reading stayed stable (~75–76%) —
confirming these are two independent signals, not the same one mislabeled.

## Air Humidity calibration

This hardware's ambient humidity chip runs consistently **low** versus a
trusted reference sensor (confirmed via live raw Zigbee capture next to an
Airthings View Plus in the same room — not a driver bug, not a unit mixup).
There's no software fix for the sensor's own calibration, so the driver
exposes two Settings-tab sliders per device:

- **Air Humidity Calibration** — added to the raw humidity %, default `+46`
  (based on real-world calibration against Airthings; tune per-unit if yours
  reads differently)
- **Soil Moisture Calibration** — added to the raw soil moisture %, default
  `0` (soil moisture reads accurately out of the box on the units tested)

Changes apply instantly on save — no need to wait for the sensor's next
report. In the app: device → **⚙️ Settings**.

## Proof

![Soil Moisture 92%, separate from Humidity 15% / Temp 67.3°F](https://github.com/user-attachments/assets/2f905d48-5706-4116-8ec9-6a0f9253a28b)
![Real sensor installed in a potted plant](https://github.com/user-attachments/assets/b670e0d5-b88e-4d80-a5c8-0a7bb21db576)

*(Note: the custom Soil Moisture tile won't show a history chart — a
platform-wide SmartThings limit on all custom capabilities, not a bug
here. Temperature/Humidity still chart normally.)*

## Files

- `soil-sensor/config.yml`, `fingerprints.yml` — driver metadata + device match
- `soil-sensor/profiles/soil-moisture-sensor.yml` — capabilities + icon + calibration preferences
- `soil-sensor/src/init.lua` — the DP109 parsing/mapping logic + calibration offsets, commented

## Build your own channel instead

```
smartthings edge:channels:create
smartthings edge:drivers:package ./soil-sensor --channel <your-channel-id>
smartthings edge:drivers:install --hub <your-hub-id> --channel <your-channel-id> <driver-id>
```
You'll need your own custom `soilMoisture` capability + presentation first
(`smartthings capabilities:create` / `capabilities:presentation:create`) —
this repo's profile references the author's namespace
(`cablenature06678.soilMoisture`); swap it if forking.

## Disclaimer

Community-built, not official Tuya/SmartThings software. Only changes how
readings are labeled/displayed — doesn't alter the sensor's hardware.

## License

MIT — see [LICENSE](./LICENSE).
