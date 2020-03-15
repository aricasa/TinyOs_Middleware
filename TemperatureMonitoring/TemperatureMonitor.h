#ifndef TEMPERATURE_MONITOR_H
#define TEMPERATURE_MONITOR_H

#define AM_TEMPERATURE_MONITOR  6
//#define TIMER_PERIOD 61440
#define TIMER_PERIOD_THRESHOLD 1300
#define TIMER_PERIOD_MEASURE_TEMPERATURE 600

typedef nx_struct DATAmsg
{
  nx_uint16_t node_id;
  nx_uint16_t temperature;
  nx_uint16_t sender;
} DATAmsg;

typedef nx_struct SETUPmsg
{
	nx_uint16_t node_id;
	nx_uint16_t threshold;
	nx_uint8_t father;
} SETUPmsg;

#endif
