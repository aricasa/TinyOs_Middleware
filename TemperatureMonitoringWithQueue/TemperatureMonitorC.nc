#include "TemperatureMonitor.h"

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

  /* Last value of temperature measured */
  uint16_t temperature;
  
  /* Threshold value of temperature*/
  uint16_t threshold;
  
  /* Node used to forward DATA messages */
  uint16_t routeBackNode=1;
  
  /* Queue of outgoing messages */
  message_t packets[QUEUE_LENGTH];
  
  /* Represents the position in "packets" of the first packet to send */
  uint8_t start=0; 
  
  /* Represents the position in "packets" where the next packet to send is added */
  uint8_t end=0;
  
  /* Data message */
  uint16_t sender;
  uint16_t temp;
  
  /* Increment start counter every time a message in the queue is processed */
  task void incStart()
  {
  	if(start==QUEUE_LENGTH-1)
  		start=0;
  	else 
  		start++;
  }
  
  /* Increment end counter every time a message in the queue is added */
  task void incEnd()
  {
  	if(end==QUEUE_LENGTH-1)
  		end=0;
  	else 
  		end++;
  }
  
  /* Send a DATA message to routeBackNode */
  task void sendDataMessage() 
  {
    DATAmsg* msg;
    
    post incEnd();
    
    msg = (DATAmsg*) (call Packet.getPayload(&packets[end], sizeof(DATAmsg)));
    if(msg==NULL) return;
    msg->node_id = TOS_NODE_ID;
   	msg->temperature = temp;
    msg->sender = sender;
      
 	dbg("Temp", "Sending DATA msg: sender %d , measured value %d \n", msg->sender, msg->temperature);
    
    if (call AMSend.send(routeBackNode, &packets[end], sizeof(DATAmsg))!=SUCCESS) 
    	dbg("PacketsLoss", "FAILED TO SEND \n");	
    
  }
  
  /* Send a SETUP message in broadcast */
  task void sendSetupMessage()
  {
  	SETUPmsg* msg;
  	
  	post incEnd();
    
    msg = (SETUPmsg*) (call Packet.getPayload(&packets[end], sizeof(SETUPmsg)));
    if(msg==NULL) return;
    msg->node_id = TOS_NODE_ID;
    msg->threshold = threshold;
    msg->father = routeBackNode;
    
    
    dbg("Temp", "Sending SETUP msg: threshold = %d \n", msg->threshold);
  
    if (call AMSend.send(AM_BROADCAST_ADDR, &packets[end], sizeof(SETUPmsg))!=SUCCESS) 
    	dbg("PacketsLoss", "FAILED TO SEND \n");	
  }
  
  event void AMSend.sendDone(message_t* msg, error_t err) 
  {
  	dbg("PacketsLoss", "SENT \n");
  	post incStart();
  }

  event void Boot.booted() {
    
    temperature = 0;
    
 	if(TOS_NODE_ID==1)
 		sender=1;
    call AMControl.start();
    
  }

  event void AMControl.startDone(error_t err) 
  {
    if (err == SUCCESS) 
    {
      /* Start timers */
      dbg("Temp", "Node %d started\n", TOS_NODE_ID);
      call TimerMeasureTemperature.startPeriodic(TIMER_PERIOD_MEASURE_TEMPERATURE);
      call TimerGenerateNewThreshold.startPeriodic(TIMER_PERIOD_THRESHOLD);
    } 
    else 
    {
      call AMControl.start();
    }
  }
  
  event void AMControl.stopDone(error_t err) 
  {
    call TimerMeasureTemperature.stop();
    call TimerGenerateNewThreshold.stop();
    dbg("Temp", "Node %d stopped\n", TOS_NODE_ID);
  }
  
  /* Generate a new threshold value that will be spread to the other nodes */
  event void TimerGenerateNewThreshold.fired()
  {
  	/* check if node is the sink node */
    if(TOS_NODE_ID==1)
    {
    	threshold = (rand() % (MAX_TEMPERATURE_threshold - MIN_TEMPERATURE_threshold + 1)) + MIN_TEMPERATURE_threshold; 
 
    	dbg("Temp", "New threshold value: %d \n", threshold);
    	
    	post sendSetupMessage();
    }
  }
  
  /* Acquire a value from the sensor and send it in case is > threshold */
  event void TimerMeasureTemperature.fired() 
  {
  	/* check if the node is NOT the sink one (only non-sink node read from sensors) */
  	if(TOS_NODE_ID!=1) {
  
  		/* comment if you want that the temperature is randomly generated */
  		temperature = (rand() % (MAX_TEMPERATURE_sensor - MIN_TEMPERATURE_sensor + 1)) + MIN_TEMPERATURE_sensor;
  		dbg("Temp", "Temperature found : %u \n", temperature);
  		sender=TOS_NODE_ID;
  		temp=temperature;
  		if(temperature >= threshold)
      		post sendDataMessage();
      		
      	/* remove comment if you want that the temperature is read by the sensor */
    	//call Temperature.read();
    }
  }

  /* Once the value has been read, it's sent to the sink node in case is > threshold */
  event void Temperature.readDone(error_t result, uint16_t val) 
  {  
    if(result == SUCCESS) {
      dbg("Temp", "Temperature found : %u \n", temperature);
      if(temperature >= threshold)
      	post sendDataMessage();
    }
  }
  
    event message_t* Receive.receive(message_t* p, void* payload, uint8_t len) 
    {
    		/* In case of DATA message */
	    	if (len == sizeof(DATAmsg)) 
	    	{
	      		DATAmsg* msg = (DATAmsg *) payload;
	      		dbg("PacketsLoss", "RECEIVED \n");
	     		dbg("Temp", "Received from node %d the measured value %d of node %d \n", msg->node_id, msg->temperature, msg->sender);
	      	      
	      	    /* Process the message only if the current node is not the sink node */  
	      		if(TOS_NODE_ID!=1)
	     		{			      	
	      			sender= msg->sender;
	      			temp= msg->temperature;	      	 
	      			post sendDataMessage();
	      		}	     
	    	}
	    	/* In case of SETUP message */
	   		else if(len == sizeof(SETUPmsg)) 
	    	{	    	    		
	     		SETUPmsg* setupMsg = (SETUPmsg *) payload;
	     		
	     		/* Process the message only if the current node is not the sink node 
				 *  and the message hasn't already be processed, which means that
				 *  TOS_NODE_ID!=setupMsg->father */	      
	      		if(TOS_NODE_ID!=setupMsg->father && TOS_NODE_ID!=1 )
	      		{
	      			dbg("PacketsLoss", "RECEIVED \n");
		      		dbg("Temp", "Received from node %d the new threshold %d --> setting route back to %d \n", setupMsg->node_id, setupMsg->threshold, setupMsg->node_id);
		      		threshold=setupMsg->threshold;
		      		routeBackNode=setupMsg->node_id;		      
		     		post sendSetupMessage();
	      		}	      	      
	    	}
	    	else
	    		dbg("Temp", "Unknown packet received. \n");
	    	
	    	 return p; 
  	} 
  
}
