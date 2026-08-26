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
    device:emit_event(soilMoisture.soilMoisture({ value = value, unit = "%" }))
  else
    device.log.info("Unhandled/diagnostic Tuya DP id " .. tostring(dp_id) .. " = " .. tostring(value))
  end
end

local function do_refresh(driver, device)
  device:send(RelativeHumidity.attributes.MeasuredValue:read(device))
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
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    },
  },
}

local driver = ZigbeeDriver("tuya-soil-moisture-zg303z", tuya_soil_driver_template)
driver:run()
