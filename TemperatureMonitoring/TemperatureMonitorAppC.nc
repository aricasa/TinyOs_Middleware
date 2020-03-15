#include "TemperatureMonitor.h"
#include <message.h>

configuration TemperatureMonitorAppC {
}
implementation {

  components MainC;
  components new TimerMilliC() as TimerGenerateNewThreshold;
  components new TimerMilliC() as TimerMeasureTemperature;

  components ActiveMessageC, new AMSenderC(AM_TEMPERATURE_MONITOR), new AMReceiverC(AM_TEMPERATURE_MONITOR);

  components new DemoSensorC();
  //components new HamamatsuS1087ParC(), new HamamatsuS10871TsrC(), new SensirionSht11C(), new Msp430InternalVoltageC();
  
  //components PrintfC, SerialStartC;
  components TemperatureMonitorC as App;
  

  App.Boot -> MainC;
  App.TimerMeasureTemperature -> TimerMeasureTemperature;
  App.TimerGenerateNewThreshold -> TimerGenerateNewThreshold;

  App.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;
  App.Packet -> AMSenderC;
  App.AMPacket -> AMSenderC;
  App.AMControl -> ActiveMessageC;

  //App.Temperature -> SensirionSht11C.Temperature;
  App.Temperature -> DemoSensorC;
}
