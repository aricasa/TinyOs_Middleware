#ifndef TEMPERATURE_MONITOR_H
#define TEMPERATURE_MONITOR_H

#define AM_TEMPERATURE_MONITOR  6
//#define TIMER_PERIOD 61440
#define TIMER_PERIOD 1024

typedef nx_struct TemperatureMonitorMsg {
  nx_uint16_t node_id;
  nx_uint16_t temperature;
} TemperatureMonitorMsg;

#endif
