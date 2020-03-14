#include "TemperatureMonitor.h"

#include <printf.h>
#define PRINTF(...) printf(__VA_ARGS__); printfflush()

module TemperatureMonitorC {
  uses {
    interface Boot;
    interface Timer<TMilli> as TimerGenerateNewThreshold;
    interface Timer<TMilli> as TimerMeasureTemperature;
    interface Packet;
    interface AMPacket;
    interface AMSend;
    interface Receive;
    interface SplitControl as AMControl;
    interface Read<uint16_t> as Temperature;
    interface StdControl as DisseminationControl;
    interface DisseminationValue<uint16_t> as Value;
  	interface DisseminationUpdate<uint16_t> as Update;
  }
}

implementation {
  uint8_t readings_to_collect, collected_readings;
  uint16_t temperature;
  uint16_t threshold;
  
  message_t pkt;
  bool busy;

  task void sendMsg() {
    TemperatureMonitorMsg* msg;
    
    if(busy) return;
    
    dbg("Temp", "Sending msg: %d %d \n", TOS_NODE_ID, temperature);
    //PRINTF("Sending msg: %d %d \n", TOS_NODE_ID, temperature);

    msg = (TemperatureMonitorMsg*) (call Packet.getPayload(&pkt, sizeof(TemperatureMonitorMsg)));
    if(msg==NULL) return;
    msg->node_id = TOS_NODE_ID;
    msg->temperature = temperature;
  
    //if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(TemperatureMonitorMsg))==SUCCESS) {
    if (call AMSend.send(1, &pkt, sizeof(TemperatureMonitorMsg))==SUCCESS) {
      //dbg("Temp", "Message sent \n");
      busy = TRUE;
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t err) {
    if (&pkt==msg) {
      busy = FALSE;
    }
  }

  event void Boot.booted() {
    readings_to_collect = collected_readings = 0;
    temperature = 0;
    busy = FALSE;
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      dbg("Temp", "Node %d started\n", TOS_NODE_ID);
      //PRINTF("Node %d started\n", TOS_NODE_ID);
      call DisseminationControl.start();
      call TimerMeasureTemperature.startPeriodic(TIMER_PERIOD);
      call TimerGenerateNewThreshold.startPeriodic(TIMER_PERIOD);
    } else {
      call AMControl.start();
    }
  }
  
  event void AMControl.stopDone(error_t err) {
    call TimerMeasureTemperature.stop();
    call TimerGenerateNewThreshold.stop();
    dbg("Temp", "Node %d stopped\n", TOS_NODE_ID);
    //PRINTF("Node %d stopped\n", TOS_NODE_ID);
  }
  
  event void TimerGenerateNewThreshold.fired()
  {
    if(TOS_NODE_ID==1)
    {
    	//uint16_t threshold = int num = (rand() % (upper - lower + 1)) + lower; 
    	threshold = rand();
    	dbg("Temp", "New threshold value: %d %d \n", TOS_NODE_ID, threshold);
    	call Update.change(&threshold);
    }
   
  }
  
  event void TimerMeasureTemperature.fired() {
  
  	if(TOS_NODE_ID!=1) {
    	collected_readings = readings_to_collect = 0;
    	if(call Temperature.read()==SUCCESS) readings_to_collect++;
    }
  }

  event void Temperature.readDone(error_t result, uint16_t val) {
    collected_readings++;
    if(result == SUCCESS) {
      temperature = val-3960;  // celsius = -39.6 + T*0.01
      dbg("Temp", "Temperature found : %u \n", temperature);
      //PRINTF("Temperature found : %u \n", temperature);
      if(TOS_NODE_ID==3) temperature = (uint16_t) rintf(temperature + (2944.4-temperature)/55.76);
    }
    if(collected_readings==readings_to_collect) {
      post sendMsg();
    }
  }

  event message_t* Receive.receive(message_t* p, void* payload, uint8_t len) {
    if (len == sizeof(TemperatureMonitorMsg)) {
      TemperatureMonitorMsg* msg = (TemperatureMonitorMsg *) payload;
      dbg("Temp", "Received from node %d the measured value %d \n", msg->node_id, msg->temperature);
      //PRINTF("%d %d \n", msg->node_id, msg->temperature);
    }
    return p;
  }  
  
  event void Value.changed() {
  
  	if(TOS_NODE_ID!=1)
  	{
	    const uint16_t* newVal = call Value.get();
	    //show new counter in leds
	    threshold = *newVal;
	    dbg("Temp", "Received change of threshold %u \n", threshold);
    }
  }
  
  
  
  
  
}
