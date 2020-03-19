#ifndef TEMPERATURE_MONITOR_H
#define TEMPERATURE_MONITOR_H

#define AM_TEMPERATURE_MONITOR  6

#define TIMER_PERIOD_THRESHOLD 13000
#define TIMER_PERIOD_MEASURE_TEMPERATURE 6000

#define MAX_TEMPERATURE_threshold 200
#define MIN_TEMPERATURE_threshold 150

#define MAX_TEMPERATURE_sensor 180
#define MIN_TEMPERATURE_sensor 0

#define QUEUE_LENGTH 10

/* DATA message : message sent by the node "node_id" to the sink node
 * containing the temperature "temperature" measured by the node "sender"
 */
typedef nx_struct DATAmsg
{
  nx_uint16_t node_id;
  nx_uint16_t temperature;
  nx_uint16_t sender;

} DATAmsg;

/* SETUP message : message sent by the node "node_id"
 * containing the new threshold "threshold" communicated by the father node "father"
 */
typedef nx_struct SETUPmsg
{
	nx_uint16_t progressiveNum;
	nx_uint16_t node_id;
	nx_uint16_t threshold;
	nx_uint16_t father;

} SETUPmsg;

#endif

