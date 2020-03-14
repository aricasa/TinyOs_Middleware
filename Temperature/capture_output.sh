#!/bin/bash
java net.tinyos.tools.PrintfClient -comm serial@/dev/ttyUSB0:telosb | awk -F '\n' '{ print strftime("%G/%m/%d-%H:%M:%S" , systime()), $0; fflush();}'

