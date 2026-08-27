mapping-status: close
Disallowed SSH Connection Non Standard Port
# Что проверяет
alert если происходит ssh на [80, 8080, 88, 443, 8443, 53, 4444]
#  Как проверяет Falco?
outbound connection
AND proc.exe endswith ssh
AND TCP
AND server port ∈ [80, 8080, 88, 443, 8443, 53, 4444]

# Как проверяет v3.2
tcp_connect
+
current binary заканчивается на /ssh
+
destination port ∈
80, 8080, 88, 443, 8443, 53, 4444
+
destination address НЕ private/loopback

# В чем различия?
Falco еще проверяет что вернет connect(), если успещно или соеденение устанавоивается то MATCH
если была ошибка то не реагирует


| Falco                      | Tetragon v3.2                                 | Оценка              |
| -------------------------- | --------------------------------------------- | ------------------- |
| `outbound`                 | `tcp_connect`                                 | очень близко        |
| `proc.exe endswith ssh`    | `matchBinaries Postfix /ssh`                  | близко              |
| `fd.l4proto=tcp`           | `tcp_connect`                                 | фактически TCP      |
| `fd.sport in [80,...]`     | `DPort [80,...]`                              | близко для outbound |
| IPv4/IPv6                  | `sock` на `tcp_connect`                       | близко              |
| исключить loopback/RFC1918 | `NotDAddr 10/8, 172.16/12, 192.168/16, 127/8` | близко              |
