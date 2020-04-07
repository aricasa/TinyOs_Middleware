#! /usr/bin/python

from TOSSIM import *
import sys

numNodes = 0
topologyFile = ""
noiseFile = ""


if len(sys.argv) != 4:
  print("Usage: python %s <nodes_amount> <topology_file> <noise_file>" % sys.argv[0])
  sys.exit(1)
else:
  numNodes = int(sys.argv[1])
  topologyFile = sys.argv[2]
  noiseFile = sys.argv[3]

try:
	topology = open(topologyFile, "r")
except IOError as e:
    print("Can't open topology file '%s'" % topologyFile)
    sys.exit(1)

try:
	noise = open(noiseFile, "r")
except IOError as e:
    print("Can't open noise file '%s'" % noiseFile)
    sys.exit(1)

print("******************************************************************************")
print("*                                                                            *")
print("*           In-network data collection and processing with TinyOS            *")
print("*                                                                            *")
print("******************************************************************************")

t = Tossim([])
r = t.radio()

# Add routes between nodes from file
for line in topology:
  s = line.split()
  if s:
    print(" src" + s[0] + ", dest" + s[1] + ", gain" + s[2]);
    r.add(int(s[0]), int(s[1]), float(s[2]))

t.addChannel("Temp", sys.stdout)
#t.addChannel("Boot", sys.stdout)
t.addChannel("Failures", sys.stdout)

# Add noise model from file
for line in noise:
  str1 = line.strip()
  if str1:
    val = int(str1)
    for i in range(1, numNodes + 1):
      t.getNode(i).addNoiseTraceReading(val)

for i in range(1, numNodes + 1):
  print("Creating noise model for node " + str(i));
  t.getNode(i).createNoiseModel()

# Add nodes
for i in range(1, numNodes + 1):
  t.getNode(i).bootAtTime(100001 + i*100000);

t.runNextEvent();
time = t.time()

# Show output of nodes
while time + 5000000000000 > t.time():
      t.runNextEvent()
