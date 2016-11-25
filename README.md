# ceph_osd_iometer
An IO meter for ceph osd


root@zosd3:/home/inwin# ./ceph_osd_iometer.sh -osd=0,1,2 -o=/tmp/output -t=30
[ID] [PID] [Read Bytes]  [Write Bytes]  [Total Read Bytes]  [Total Write Bytes]
0    2383             0              0                   0           39,550,976
2    2037             0              0                   0           68,198,400
1    2165             0      1,545,011                   0           46,751,744

17:06:50.732, start at 17:06:33.650, exit after 13 seconds.
