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
  }
}

implementation {

  uint16_t temperature;
  uint16_t threshold;
  uint16_t routeBackNode=1;
  
  message_t pkt;
  bool busy;
  
  //Data message
  uint16_t sender;
  uint16_t temp;
  

  task void sendDataMessage() {
    DATAmsg* msg;
    
    if(busy) 
    {
    	dbg("Temp", "I'm busy!\n");
    	return;
    }
    
    msg = (DATAmsg*) (call Packet.getPayload(&pkt, sizeof(DATAmsg)));
    if(msg==NULL) return;
    msg->node_id = TOS_NODE_ID;
    msg->temperature = temp;
    msg->sender = sender;
  
 	dbg("Temp", "Sending DATA msg: sender %d , measured value %d \n", msg->sender, msg->temperature);
    if (call AMSend.send(routeBackNode, &pkt, sizeof(DATAmsg))==SUCCESS) {
      
      //dbg("Temp", "Busy true \n");
      busy = TRUE;
    }
  }
  
  
  task void sendSetupMessage()
  {
  	SETUPmsg* msg;
    
    if(busy) 
    {
    	dbg("Temp", "I'm busy!\n");
    	return;
    }

    msg = (SETUPmsg*) (call Packet.getPayload(&pkt, sizeof(SETUPmsg)));
    if(msg==NULL) return;
    msg->node_id = TOS_NODE_ID;
    msg->threshold = threshold;
    msg->father = routeBackNode;
    
    dbg("Temp", "Sending SETUP msg: threshold = %d \n", msg->threshold);
  
    if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(SETUPmsg))==SUCCESS) {
      //dbg("Temp", "Busy true \n");
      busy = TRUE;
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t err) {
    if (&pkt==msg) {
      busy = FALSE;
     // dbg("Temp", "Busy false \n");
    }
  }

  event void Boot.booted() {
    
    temperature = 0;
    busy = FALSE;
 	if(TOS_NODE_ID==1)
 		sender=1;
    call AMControl.start();
    
  }

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      dbg("Temp", "Node %d started\n", TOS_NODE_ID);
      call TimerMeasureTemperature.startPeriodic(TIMER_PERIOD_MEASURE_TEMPERATURE);
      call TimerGenerateNewThreshold.startPeriodic(TIMER_PERIOD_THRESHOLD);
    } else {
      call AMControl.start();
    }
  }
  
  event void AMControl.stopDone(error_t err) {
    call TimerMeasureTemperature.stop();
    call TimerGenerateNewThreshold.stop();
    dbg("Temp", "Node %d stopped\n", TOS_NODE_ID);
  }
  
  event void TimerGenerateNewThreshold.fired()
  {
    if(TOS_NODE_ID==1)
    {
    	threshold = (rand() % (200 - 150 + 1)) + 150; 
    	//threshold = rand();
    	dbg("Temp", "New threshold value: %d %d \n", TOS_NODE_ID, threshold);
    	
    	
    	if (!busy)      		
    		post sendSetupMessage();
    	//else
    	//	dbg("Temp", "Busy true \n");
    }
   
  }
  
  event void TimerMeasureTemperature.fired() {
  
  	if(TOS_NODE_ID!=1) {
  
  		temperature = (rand() % (180 - 0 + 1)) + 0;
  		dbg("Temp", "Temperature found : %u \n", temperature);
  		sender=TOS_NODE_ID;
  		temp=temperature;
  		if(temperature >= threshold)
      		post sendDataMessage();
    	//call Temperature.read();
    }
  }

  event void Temperature.readDone(error_t result, uint16_t val) {
    
    if(result == SUCCESS) {
      temperature = val-3960;  // celsius = -39.6 + T*0.01
      dbg("Temp", "Temperature found : %u \n", temperature);
      //if(TOS_NODE_ID==3) temperature = (uint16_t) rintf(temperature + (2944.4-temperature)/55.76);
      if(temperature >= threshold)
      	post sendDataMessage();
    }
   
  }
  
    event message_t* Receive.receive(message_t* p, void* payload, uint8_t len) {
    
    if (len == sizeof(DATAmsg)) 
    {
      DATAmsg* msg = (DATAmsg *) payload;
      dbg("Temp", "Received from node %d the measured value %d of node %d \n", msg->node_id, msg->temperature, msg->sender);
      
      
      if(TOS_NODE_ID!=1)
      {
      	
      	sender= msg->sender;
      	temp= msg->temperature;
      	 
      	post sendDataMessage();
      }
      
      
    }
    else if(len == sizeof(SETUPmsg) && TOS_NODE_ID!=1 ) 
    {
    
      SETUPmsg* setupMsg = (SETUPmsg *) payload;
      
      if(TOS_NODE_ID!=setupMsg->father)
      {
	      dbg("Temp", "Received from node %d the new threshold %d \n", setupMsg->node_id, setupMsg->threshold);
	      dbg("Temp", "Setting route back to %d \n", setupMsg->node_id);
	      threshold=setupMsg->threshold;
	      routeBackNode=setupMsg->node_id;
	      
	      post sendSetupMessage();
      }
      
      
    }
    return p;
  } 
  
}
