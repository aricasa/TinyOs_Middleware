print "***************************************************************************************************"
print "                                                      "
print "				In-network data collection and processing with TinyOS.			"
print "                                                      "
print "***************************************************************************************************"

#! /usr/bin/python
from TOSSIM import *
import sys

t = Tossim([])
r = t.radio()

#Add routes between nodes from file
f = open("topology.txt", "r")
for line in f:
  s = line.split()
  if s:
    print " src", s[0], " dest", s[1], " gain", s[2];
    r.add(int(s[0]), int(s[1]), float(s[2]))

t.addChannel("Temp", sys.stdout)

#Add noise model from file
noise = open("meyer-heavy.txt", "r")
for line in noise:
  str1 = line.strip()
  if str1:
    val = int(str1)
    for i in range(1, 15):
      t.getNode(i).addNoiseTraceReading(val)

for i in range(1, 15):
  print "Creating noise model for ",i;
  t.getNode(i).createNoiseModel()

#Add nodes
t.getNode(1).bootAtTime(100001);
t.getNode(2).bootAtTime(800008);
t.getNode(3).bootAtTime(1800009);
t.getNode(4).bootAtTime(2500009);
t.getNode(5).bootAtTime(3000009);
t.getNode(6).bootAtTime(3000009);
t.getNode(7).bootAtTime(3000009);
t.getNode(8).bootAtTime(3000009);
t.getNode(9).bootAtTime(3000009);
t.getNode(10).bootAtTime(3000009);
t.getNode(11).bootAtTime(3000009);
t.getNode(12).bootAtTime(3000009);
t.getNode(13).bootAtTime(3000009);
t.getNode(14).bootAtTime(3000009);

t.runNextEvent();
time = t.time()

#Show output of nodes
while time + 5000000000000 > t.time():
      t.runNextEvent()
      
  
print "							END OF PROGRAM					"