# SmartThings Edge Driver — Tuya Soil Moisture Sensor (HOBEIAN `ZG-303Z`)

![Soil moisture sensor listing](https://github.com/user-attachments/assets/87b4d6f5-7540-43cb-929b-80b0a7351636)

> **Note on the photo above:** this is a listing image for a similar "3-in-1 Tuya
> Zigbee" soil/temperature/humidity sensor (same product family/behavior as the
> HOBEIAN ZG-303Z this driver targets) — included for a visual reference of what
> this class of sensor looks like and what it measures, not a guaranteed exact
> match to every seller's version. Always confirm your own unit's manufacturer/
> model (see below) before installing.

A working SmartThings Edge driver that fixes a real, confirmed bug in how
SmartThings displays data from Tuya-based Zigbee soil moisture sensors
(manufacturer `HOBEIAN`, model `ZG-303Z`, and clones sold under other
storefront names with the same hardware).

## The problem this fixes

These sensors have a real soil-moisture probe, but instead of using any
Tuya-proprietary datapoint for it, they report the live soil moisture reading
through the **standard Zigbee Relative Humidity Measurement cluster**
(`0x0405`) — the exact same cluster real ambient-humidity sensors use.
SmartThings' generic Zigbee humidity driver therefore (correctly, from its
own point of view) maps that cluster straight to the standard
`relativeHumidityMeasurement` capability. The result: every automation,
Routine, and dashboard reads the soil moisture number as if it were plain
room humidity — because as far as the platform is concerned, that's exactly
what a `0x0405` report always means.

**Verified 2026-08-25** against two real units, both live-logged while
physically triggering a moisture change: the value reported on the standard
humidity cluster exactly matched the sensor's own Tuya diagnostic datapoint
for soil moisture at the same instant, and both moved together in response
to a real moisture change — confirming this is genuinely the live soil
signal being reported on the "wrong" (standard) cluster, not a coincidence
or a separate hidden datapoint that needed to be hunted down.

## The fix

This driver still listens on the same standard `RelativeHumidity` cluster
(so it keeps working with the sensor's real, unmodifiable behavior), but
instead of mapping it to `relativeHumidityMeasurement`, it emits a
**dedicated custom "Soil Moisture" capability** — a fully separate tile,
so automations and dashboards can no longer confuse it with ambient
humidity. Temperature and Battery continue to use their standard Zigbee
clusters/capabilities exactly as before — only the mislabeled
humidity-that's-actually-soil-moisture cluster needed remapping.

The custom capability is intentionally **read-only** (no settable/editable
field) since the sensor's own hardware is the only real source of truth for
this value — there's nothing to "set" from the app.

## Install it on your own hub

1. Accept the driver channel invite (one-time, links your SmartThings account to this channel):
   **https://bestow-regional.api.smartthings.com/invite/gV2qwyDydYj9**
2. On that page, select your hub to enroll it in the channel.
3. In the SmartThings app: your soil sensor's device page → `...` menu →
   **Driver** → **Select different driver** → pick
   **tuya-soil-moisture-hobeian-zg303z**.
4. If it was previously stuck reporting soil moisture as "Humidity," it
   should now show a proper separate **Soil Moisture** tile instead.

## Files

- `soil-sensor/config.yml` — driver metadata, permissions, device type
- `soil-sensor/fingerprints.yml` — maps `HOBEIAN` / `ZG-303Z` to the profile
- `soil-sensor/profiles/soil-moisture-sensor.yml` — capabilities exposed (custom Soil Moisture, temperature, battery, refresh); uses the official `PlantGrower` device category so the app shows a plant icon instead of a generic sensor icon
- `soil-sensor/src/init.lua` — the actual remapping logic, fully commented

## Building/uploading it yourself (if you want your own channel instead)

Requires the official [SmartThings CLI](https://github.com/SmartThingsCommunity/smartthings-cli):

```
smartthings edge:channels:create
smartthings edge:drivers:package ./soil-sensor --channel <your-channel-id>
smartthings edge:drivers:install --hub <your-hub-id> --channel <your-channel-id> <driver-id>
```

You'll also need to create the custom `soilMoisture` capability once under
your own namespace (`smartthings capabilities:create`) and its display
presentation (`smartthings capabilities:presentation:create`) before your
driver can reference it — this repo's `profiles/soil-moisture-sensor.yml`
references a capability ID under this author's namespace
(`cablenature06678.soilMoisture`); swap it for your own if forking.

## The physical device

Targets Tuya Zigbee soil moisture sensors identifying over Zigbee as
manufacturer `HOBEIAN`, model `ZG-303Z` — commonly sold under various
generic/white-label storefront names (search "Tuya Zigbee soil moisture
sensor 3 in 1" on AliExpress or similar marketplaces) reporting soil
moisture, air temperature, and battery, requiring a Zigbee 3.0 hub
(SmartThings, or Home Assistant with a Zigbee coordinator).

## Disclaimer

This is a community-built driver, not official Tuya or SmartThings
software. It only affects how the reading is displayed/labeled in
SmartThings — it doesn't change or calibrate the sensor's underlying
hardware measurement in any way.

## License

MIT — see [LICENSE](./LICENSE).
