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
f = open("topology.txt", "r")

for line in f:
  s = line.split()
  if s:
    print " src", s[0], " dest", s[1], " gain", s[2];
    r.add(int(s[0]), int(s[1]), float(s[2]))

t.addChannel("Temp", sys.stdout)

noise = open("meyer-heavy.txt", "r")
for line in noise:
  str1 = line.strip()
  if str1:
    val = int(str1)
    for i in range(1, 4):
      t.getNode(i).addNoiseTraceReading(val)

for i in range(1, 4):
  print "Creating noise model for ",i;
  t.getNode(i).createNoiseModel()

t.getNode(1).bootAtTime(100001);
t.getNode(2).bootAtTime(800008);
t.getNode(3).bootAtTime(1800009);

t.runNextEvent();
time = t.time()
while time + 50000000000 > t.time():
  t.runNextEvent()

print "							END OF PROGRAM					"