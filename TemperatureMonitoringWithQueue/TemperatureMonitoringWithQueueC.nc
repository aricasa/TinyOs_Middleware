#include "Timer.h"
#include "TemperatureMonitoringWithQueue.h"


module TemperatureMonitoringWithQueueC @safe()
{
  uses 
  {
    // Interfaces for initialization:
    interface Boot;
    interface SplitControl as RadioControl;
    
    // Interfaces for communication:
    interface Receive;
    interface AMSend;
    interface Packet;
    interface AMPacket;
    interface Queue<message_t *> as UARTQueue;
    interface Queue<uint8_t> as packetsLengthQueue;
    interface Pool<message_t> as UARTMessagePool;

	//Interfaces for temperature monitoring logic:
    interface Timer<TMilli> as TimerGenerateNewThreshold;
    interface Timer<TMilli> as TimerMeasureTemperature;
    interface Read<uint16_t> as Temperature;
  }
}

implementation 
{
  //Prototypes
  task void uartSendTask();
  static void startTimer();
  void sendSETUPMessage(uint16_t node_id , uint16_t thresholdNew , uint8_t father);
  void sendDATAMessage(uint16_t node_id , uint16_t temperatureMsg, uint16_t senderMsg);
  void manageReceivedSETUPMessage(message_t* msg, void *payload);
  void manageReceivedDATAMessage(message_t* msg, void *payload);

  /* Temporary variable used when sending messages */
  message_t sendBuffer;
  
  /* Variable which is TRUE if there's already a message in sending phase */
  bool sendBusy;
  
  /* Node used to forward DATA messages */
  uint16_t routeBackNode;
  
  /* Last value of temperature measured */
  uint16_t temperature;
  
  /* Threshold value of temperature*/
  uint16_t threshold;
  

  /* On bootup, initialize radio communications, and some state variables. */
  event void Boot.booted() 
  {
    // Beginning our initialization phases:
    if (call RadioControl.start() == SUCCESS)
      dbg("Boot", "Application booted \n");
      
    //Initialize variables  
    routeBackNode=1;
    sendBusy=FALSE;
    
    //Start the timers
    startTimer();
  }

  event void RadioControl.startDone(error_t error) 
  {
    if (error != SUCCESS)
      call RadioControl.start();
  }
  
  event void RadioControl.stopDone(error_t error) { }

  static void startTimer() 
  {
    call TimerGenerateNewThreshold.startPeriodic(TIMER_PERIOD_THRESHOLD);
    call TimerMeasureTemperature.startPeriodic(TIMER_PERIOD_MEASURE_TEMPERATURE);
  }
 
  event void TimerGenerateNewThreshold.fired() 
  {
	/* check if node is the sink node */
    if(TOS_NODE_ID==1)
    {
	    threshold = (rand() % (MAX_TEMPERATURE_threshold - MIN_TEMPERATURE_threshold + 1)) + MIN_TEMPERATURE_threshold; 
	 
	    dbg("Temp", "New threshold value: %d \n", threshold);
	    	
	    sendSETUPMessage(TOS_NODE_ID,threshold,routeBackNode);
    }
  }
	
  event void TimerMeasureTemperature.fired() 
  {
  	/* check if the node is NOT the sink one (only non-sink node read from sensors) */
  	if(TOS_NODE_ID!=1) 
  	{
  		/* comment if you want that the temperature is randomly generated */
  		temperature = (rand() % (MAX_TEMPERATURE_sensor - MIN_TEMPERATURE_sensor + 1)) + MIN_TEMPERATURE_sensor;
  		dbg("Temp", "Temperature measured : %d \n", temperature);
  		sender=TOS_NODE_ID;
  		temp=temperature;
  		if(temperature >= threshold)
      		sendDATAMessage(TOS_NODE_ID,temperature,TOS_NODE_ID);
      	
      	/* remove comment if you want that the temperature is read by the sensor */
    	//call Temperature.read();
    }
  }


  event void Temperature.readDone(error_t result, uint16_t data) 
  {
    if (result != SUCCESS) 
    {
      data = 0xffff;
      dbg("Temp" , "Temperature measure : %d \n", data);
    }
  }
  
  /* The sink node sends a SETUP message in broadcast to all other nodes informing them
   * about the new threshold */
  void sendSETUPMessage(uint16_t node_id , uint16_t thresholdNew , uint8_t father)
  {
  	SETUPmsg* msg;
	msg = (SETUPmsg*) (call Packet.getPayload(&sendBuffer, sizeof(SETUPmsg)));
  	
  	if(!sendBusy)
  	{  		
		if(msg==NULL) return;
		    
		msg->node_id = node_id;
		msg->threshold = thresholdNew;
		msg->father = father;
		        
		dbg("Temp", "Sending SETUP msg: threshold = %d \n", msg->threshold);
		    
		if (call AMSend.send(AM_BROADCAST_ADDR, &sendBuffer, sizeof(SETUPmsg)) == SUCCESS)
		{
			sendBusy = TRUE;
		}
	    else
	    {
	         dbg("Failures", "SETUP message failed to send . \n");
	    }
  	}
  	else
  	{
  		dbg("Temp", "Busy -> put in queue SETUP msg: threshold = %d \n", msg->threshold);
  		sendLaterSETUPMessage(node_id ,thresholdNew , father);
  	}
  }
  
  /* Enqueue a SETUP message when a message is already in sending */
  void sendLaterSETUPMessage(uint16_t node_id , uint16_t thresholdNew , uint8_t father)
  {
  	SETUPmsg* msg;
	message_t *newmsg = call UARTMessagePool.get();
		 
	if (newmsg == NULL) 
	{
		// drop the message on the floor if we run out of queue space.
		dbg("Failures", "Drop SETUP message -> run out of space in queue. \n");
		return;
	}
		    
    msg = (SETUPmsg*) (call Packet.getPayload(newmsg, sizeof(SETUPmsg)));
	if(msg==NULL) return;
		    
	msg->node_id = node_id;
	msg->threshold = thresholdNew;
	msg->father = father;

	if (call UARTQueue.enqueue(newmsg) != SUCCESS || call packetsLengthQueue.enqueue(sizeof(SETUPmsg)) != SUCCESS) 
	{
		call UARTMessagePool.put(newmsg);		       
		return;
	}
  }
  
  /* The (non) sink nodes send a DATA message addressed to the route back node 
   * to inform the sink node about the new measured value */
  void sendDATAMessage(uint16_t node_id , uint16_t temperatureMsg, uint16_t senderMsg)
  {
	DATAmsg* msg;		    
	msg = (DATAmsg*) (call Packet.getPayload(&sendBuffer, sizeof(DATAmsg)));
		
	if(!sendBusy)
	{
		if(msg==NULL) return;
		    
		msg->node_id = node_id;
		msg->temperature = temperatureMsg;
		msg->sender = senderMsg;
		      
		dbg("Temp", "Sending DATA msg: sender %d , measured value %d \n", msg->sender, msg->temperature);
			
		if (call AMSend.send(routeBackNode, &sendBuffer, sizeof(DATAmsg)) == SUCCESS)
		{
		  	sendBusy = TRUE;
		}
	    else
	    {
	        dbg("Temp" , "DATA message failed to send. \n");
	    }
	}
	else
	{
		dbg("Temp", "Busy -> put in queue DATA msg: sender %d , measured value %d \n", msg->sender, msg->temperature);
		sendLaterDATAMessage(node_id , temperatureMsg, senderMsg);
	}
  }

  /* Enqueue a DATA message when a message is already in sending */
  void sendLaterDATAMessage(uint16_t node_id , uint16_t temperatureMsg, uint16_t senderMsg)
  {
	DATAmsg* msg;
	message_t *newmsg = call UARTMessagePool.get();
	if (newmsg == NULL) 
	{
		// drop the message on the floor if we run out of queue space.
		dbg("Failures", "Drop DATA message -> run out of space in queue. \n");
		return;
	}
		    
	msg = (DATAmsg*) (call Packet.getPayload(newmsg, sizeof(DATAmsg)));
	if(msg==NULL) return;
		    
	msg->node_id = node_id;
	msg->temperature = temperatureMsg;
	msg->sender = senderMsg;

	if (call UARTQueue.enqueue(newmsg) != SUCCESS || call packetsLengthQueue.enqueue(sizeof(DATAmsg)) != SUCCESS) 
	{
		call UARTMessagePool.put(newmsg);		        
		return;
	}
  }
	
  /* After a message has been sent, check if the queue of outgoing messages is empty
   * if not empty the first message is dequeued and uploaded in a buffer */
  event void AMSend.sendDone(message_t *msg, error_t error) 
  {	  
	if(error!=SUCCESS)
		dbg("Temp" , "SendDone is a FAILURE \n");
	sendBusy = FALSE;
	if (call UARTQueue.empty() == FALSE) 
	{
		// We just finished a send, and the uart queue is
	    // non-empty.  Let's start a new one.
	    message_t *queuemsg = call UARTQueue.dequeue();
	    if (queuemsg == NULL) 
	    {
	    	dbg("Failures", "SendDone : message failed to send \n");
	        return;
	    }
	    
	    //Upload the message dequeued in a buffer
	    memcpy(&sendBuffer, queuemsg, sizeof(message_t));
	    if (call UARTMessagePool.put(queuemsg) != SUCCESS) 
	    {
	    	dbg("Failures", "SendDone : message failed to send \n");
	        return;
	    }
	    
	    //Send the message in the buffer
	    post uartSendTask();
	}
  }
  
  /* Send message uploaded in buffer */
  task void uartSendTask() 
  { 
  	uint8_t length = call packetsLengthQueue.dequeue();
  	
  	if(length == sizeof(DATAmsg))
  	{
  		dbg("Temp", "Forward DATA msg from queue \n");
  		if (call AMSend.send(routeBackNode, &sendBuffer, length) != SUCCESS) 
	    {
	      dbg("Failures", "DATA message failed to send \n");
	    } 
	    else 
	    {
	      sendBusy = TRUE;
	    }
  	}
  	else if (length == sizeof(SETUPmsg))
  	{
  		dbg("Temp", "Forward SETUP msg from queue \n");
  		if (call AMSend.send(AM_BROADCAST_ADDR, &sendBuffer, length) != SUCCESS) 
	    {
	      dbg("Failures", "SETUP message failed to send \n");
	    } 
	    else 
	    {
	      sendBusy = TRUE;
	    }
  	}
  }
  
  /* Event triggered when receiving a message 
   * the incoming message is processed depending on the type message */
  event message_t* Receive.receive(message_t* msg, void *payload, uint8_t len) 
  {  	
    if (len == sizeof(DATAmsg)) 
    {    	
    	manageReceivedDATAMessage(msg,payload);      
    }
   	else if(len == sizeof(SETUPmsg)) 
    {    	
    	manageReceivedSETUPMessage(msg,payload);   		     
    }
    return msg;
  }

  /* When receiving a DATA msg, the message is forwarded to the route back node */
  void manageReceivedDATAMessage(message_t* msg, void *payload)
  {
	DATAmsg* in = (DATAmsg*)payload;
	dbg("Temp", "Received DATA msg : from node %d the measured value %d of node %d \n", in->node_id, in->temperature, in->sender);			
	if(TOS_NODE_ID!=1)
		sendDATAMessage(TOS_NODE_ID, in->temperature,in->sender);
  }
	
  /* When receiving a SETUP msg, the message is forwarded in broadcast */	
  void manageReceivedSETUPMessage(message_t* msg, void *payload)
  {
	SETUPmsg* in = (SETUPmsg*)payload; 		
		
	if(TOS_NODE_ID!=1 && TOS_NODE_ID!=in->father)
    {
    	dbg("Temp" , "Received SETUP msg : from node %d with threshold %d \n", in->node_id ,  in->threshold);
	   	threshold = in->threshold;
	   	routeBackNode =	in->node_id;   
	   	sendSETUPMessage(TOS_NODE_ID,in->threshold,in->node_id);	    			    	
	 }
   }

}
