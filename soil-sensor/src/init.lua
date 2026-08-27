-- Tuya HOBEIAN ZG-303Z Soil Moisture Sensor driver (3-in-1: soil moisture,
-- air temperature, air humidity)
--
-- CORRECTED 2026-08-26 after further testing: the sensor is genuinely a
-- "3 in 1" device (soil moisture + air temperature + air humidity), not a
-- 2-in-1 as originally assumed. An earlier version of this driver
-- incorrectly remapped the STANDARD Zigbee "Relative Humidity Measurement"
-- cluster (0x0405) to "Soil Moisture" -- that cluster genuinely reports
-- real ambient/air humidity (its value fluctuated widely, 16%-51%, over a
-- short window, consistent with real room-air behavior, not stable soil
-- moisture retention).
--
-- The REAL soil moisture channel is a separate Tuya proprietary datapoint
-- sent over the private 0xEF00 cluster: datapoint id 109 (0x6D). This
-- matches the community-documented mapping for this same Tuya soil-sensor
-- hardware family (see zigbee-herdsman-converters / ZHA quirks for the
-- related ZG-303Z / C3007 devices, which use DP 109 for soil_moisture).
-- VERIFIED against two real units: DP 109 stayed steady (~75-76%) over the
-- same window where the standard humidity cluster (real air humidity)
-- swung significantly -- exactly the stability difference expected between
-- soil moisture (changes slowly, over hours/days) and air humidity
-- (changes quickly, minute to minute).
--
-- Final mapping used by this driver:
--   Standard ZCL Temperature cluster        -> temperatureMeasurement (Air Temperature) -- unchanged, always worked
--   Standard ZCL RelativeHumidity cluster    -> relativeHumidityMeasurement (Air Humidity) -- reverted to its correct standard capability
--   Tuya EF00 cluster, datapoint 109 (0x6D)  -> custom Soil Moisture capability (NEW -- this is the fix)
--   Standard Battery cluster                 -> battery -- unchanged

local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local ZigbeeDriver = require "st.zigbee"
local RelativeHumidity = zcl_clusters.RelativeHumidity

local soilMoisture = capabilities["cablenature06678.soilMoisture"]

local TUYA_CLUSTER = 0xEF00
local TUYA_DP_SOIL_MOISTURE = 109 -- 0x6D

-- CALIBRATION (2026-08-26): added after confirming, via live raw-wire capture,
-- that this hardware's humidity reading is a genuine, consistent low bias
-- (~35-40 points below a trusted reference sensor in the same room) -- not a
-- driver bug, not a unit mixup, not a reversed value. Since there's no
-- software fix for the sensor's own calibration, we expose a per-device
-- "Air Humidity Calibration" and "Soil Moisture Calibration" offset setting
-- (Settings tab in the SmartThings app) so each physical unit can be
-- corrected to match a reference sensor. Offset is added AFTER the standard
-- ZCL scaling, so it's always a plain "+/- percentage points" adjustment.
-- SPIKE FILTER (2026-08-27): found via analysis of real report history from
-- both physical units that the "40-point-off" behavior we kept chasing was
-- never a single stable bias -- the readings are actually BIMODAL. Each
-- sensor normally reports a believable, fairly stable value (this hardware's
-- real range, before calibration), but occasionally reports an impossible
-- 97-100% for one brief burst before returning to its normal range.
-- Correlating timestamps: these garbage bursts on BOTH physical sensors
-- lined up almost exactly with times we reloaded/reinstalled this very
-- driver -- strongly suggesting this hardware sends a stale/cached "reset"
-- value near its max range immediately after any Zigbee-level
-- re-init/rejoin (driver reload forces this at the hub level; the same
-- thing likely also happens after any real radio dropout+rejoin in normal
-- use, not just our own redeploys).
--
-- Real indoor air humidity essentially never reaches 90%+ in a normal home
-- (that's swamp-cooler/bathroom-during-a-shower territory), so we treat any
-- raw reading above this threshold as a known-bad post-init artifact and
-- discard it rather than emit/calibrate off of it. This is what let a
-- fixed offset keep "working, then breaking" all day -- some of the
-- "current" values I was calibrating against were themselves garbage.
local HUMIDITY_SANITY_MAX_RAW_PERCENT = 90

local function get_offset(device, pref_name)
  local prefs = device.preferences
  local v = prefs and prefs[pref_name]
  if v == nil then
    return 0
  end
  return v
end

local function parse_tuya_dp_report(driver, device, zb_rx)
  -- Tuya 0xEF00 "data report" payloads are a custom binary format:
  -- byte 0-1: seq number, byte 2: dp id, byte 3: dp type, byte 4-5: dp len,
  -- byte 6..: dp value (big-endian).
  local bytes = zb_rx.body.zcl_body.body_bytes
  if bytes == nil or #bytes < 7 then
    device.log.warn("Tuya DP report too short to parse: " .. tostring(bytes))
    return
  end

  local dp_id = bytes:byte(3)
  local dp_len = bytes:byte(5) * 256 + bytes:byte(6)
  local value = 0
  for i = 1, dp_len do
    value = value * 256 + bytes:byte(6 + i)
  end

  if dp_id == TUYA_DP_SOIL_MOISTURE then
    device.log.info("Soil moisture (Tuya DP 109): " .. tostring(value))
    device:set_field("last_soil_moisture_raw", value, { persist = true })
    local calibrated = value + get_offset(device, "soilMoistureOffset")
    device:emit_event(soilMoisture.soilMoisture({ value = calibrated, unit = "%" }))
  else
    device.log.info("Unhandled/diagnostic Tuya DP id " .. tostring(dp_id) .. " = " .. tostring(value))
  end
end

-- NOTE (2026-08-26): originally tried to make Refresh / Settings-save
-- instantly re-apply a new calibration offset using a cached "last raw
-- value" persisted with device:set_field(..., {persist = true}). Verified
-- live via logcat that this persisted field does NOT survive a driver
-- update -- get_field returns nil right after reinstalling the driver, even
-- immediately after using it successfully seconds before. Rather than ship
-- a feature that only sometimes works, this was removed. The offset is
-- still applied correctly and unconditionally at the moment of each real
-- humidity/soil-moisture report (see humidity_attr_handler and
-- parse_tuya_dp_report below) -- changing the Settings offset takes effect
-- starting with the sensor's next report, same as any other reading from
-- this hardware (which only reports every few hours on its own schedule).
local function do_refresh(driver, device)
  device:send(RelativeHumidity.attributes.MeasuredValue:read(device))
end

local function humidity_attr_handler(driver, device, value, zb_rx)
  local raw = value.value
  local raw_percent = raw / 100.0
  device.log.info(string.format(
    "DIAGNOSTIC raw RelativeHumidity.MeasuredValue = %s (raw uint16 from device, ZCL spec says value/100 = %%)",
    tostring(raw)
  ))
  if raw_percent > HUMIDITY_SANITY_MAX_RAW_PERCENT then
    device.log.warn(string.format(
      "Rejecting implausible humidity report of %.1f%% (likely post-init/rejoin artifact, not a real reading)",
      raw_percent
    ))
    return
  end
  local calibrated = raw_percent + get_offset(device, "humidityOffset")
  device:emit_event(capabilities.relativeHumidityMeasurement.humidity({ value = calibrated, unit = "%" }))
end

local tuya_soil_driver_template = {
  supported_capabilities = {
    soilMoisture,
    capabilities.temperatureMeasurement,
    capabilities.relativeHumidityMeasurement,
    capabilities.battery,
    capabilities.refresh,
  },
  zigbee_handlers = {
    cluster = {
      [TUYA_CLUSTER] = {
        [0x01] = parse_tuya_dp_report, -- command id 0x01 = data report
        [0x02] = parse_tuya_dp_report, -- some firmwares use 0x02 for reports
      },
    },
    attr = {
      [RelativeHumidity.ID] = {
        [RelativeHumidity.attributes.MeasuredValue.ID] = humidity_attr_handler,
      },
    },
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    },
  },
}

local driver = ZigbeeDriver("tuya-soil-moisture-zg303z", tuya_soil_driver_template)
driver:run()
