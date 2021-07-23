# Injection traffic

*network*

```
&"C:\Program Files\Wireshark\tshark.exe" -r .\traffic.pcap -T fields -e tds.query -e frame.len > query.sql
```