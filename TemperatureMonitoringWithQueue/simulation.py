print "***************************************************************************************************"
print "                                                      "
print "				In-network data collection and processing with TinyOS.			"
print "                                                      "
print "***************************************************************************************************"

#! /usr/bin/python
from TOSSIM import *
import sys

nunNodes=14

t = Tossim([])
r = t.radio()

#Add routes between nodes from file
f = open("topology4.txt", "r")
for line in f:
  s = line.split()
  if s:
    print " src", s[0], " dest", s[1], " gain", s[2];
    r.add(int(s[0]), int(s[1]), float(s[2]))

t.addChannel("Temp", sys.stdout)
#t.addChannel("Boot", sys.stdout)
t.addChannel("Failures", sys.stdout)

#Add noise model from file
noise = open("noise.txt", "r")
for line in noise:
  str1 = line.strip()
  if str1:
    val = int(str1)
    for i in range(1, nunNodes+1):
      t.getNode(i).addNoiseTraceReading(val)

for i in range(1, nunNodes+1):
  print "Creating noise model for ",i;
  t.getNode(i).createNoiseModel()

#Add nodes
for i in range(1, nunNodes+1):
  t.getNode(i).bootAtTime(100001 + i*100000);

t.runNextEvent();
time = t.time()

#Show output of nodes
while time + 5000000000000 > t.time():
      t.runNextEvent()
      
  
print "							END OF PROGRAM					"