#!/bin/env python
import socket
import os

# micro-deamon
if os.fork() > 0 or os.fork() > 0:
    exit(0)

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind(('localhost', 6667))
s.listen(1)
conn, addr = s.accept()
print "Connection from", addr
nick = ''
of = open("fake_ircd.log", "w")

while 1:
    data = conn.recv(1024)
    if not data:
        break
    if data.startswith("NICK "):
        nick = data.split()[-1]
        conn.sendall(":locahost 001 %s Welcome\n" % nick)
    if data.startswith("JOIN "):
        conn.sendall(":%s JOIN :%s" % (nick, data.split()[-1]))
    of.write(data)
    of.flush()
    print data[:-1]

of.close()
conn.close()
