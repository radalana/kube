Falco ищет:
dup2(X, 0) - означает сделай дескриптор 0 ссылкой на тот де объект, что и X.
Пример почему security relevant:
0 → terminal
5 → network socket

dup2(5,0) будет означать, что процесс думаешь что читает input из стандартного input, хотя на самом деле читает из интернет-сокета.

Поэтому Falco security rule смотрит именно на 0, 1, 2
Если программа открыла FD 5 -> TCP socket, потом выполняет 
dup2(5, 0);
dup2(5, 1);
dup2(5, 2);

например shell получает по stdin а на самом деле из инерента команду id, и отправляет ее так же

## Tetragon
Как работаест v3.2 Tetragon 
dup2(source, destination)

destination = 0, 1 or 2?
        ↓
      MATCH

то есть не смотри является ли source интернет сокет

И цель чтобы Tetragon мог видеть что source это именно интернет сокет, так как сейчас он ловит pipe → stdin

inside container
AND
source = socket
AND
destination = stdin/stdout/stderr
→ MATCH

для этого используется kernel_function do_dup2 - что так можно использовать подврежденно https://github.com/cilium/tetragon/issues/3877 (я не проверила)

1. проверить что do_dup2 есть у меня в ядра на worker1 и потом на всеъ
k exec -n kube-system tetragon-vnc9n -c tetragon -- `
  sh -c 'grep -w "do_dup2" /proc/kallsyms | head'

Ответ: ffffffff9e9170f0 t do_dup2 -> ядро имеет функию 

do_dup2
   ↓
source object = socket
AND
new fd = 0, 1 или 2
   ↓
MATCHв

### Tests

#### Negative PASST
pipe → stdin
→ candidate должна дать 0


#### Positive PASST
socket → stdin
→ candidate должна дать match


Создается IPv4 TCP socket
      ↓
dup2(socket_fd, 0)
      ↓
stdin теперь указывает на socket

Однако просто Unix сокет, а ipv4, ipv6 как в Falco, т.е в тетрагоне даже с сокетом правило ширек
*Unix socket не использует IP-адрес вообще. Он служит для связи между процессами на одной Linux-системе.


И отдельная проверка срабаытвает ли на Unix socket, ожидается что не срабатывает, значит как и фалко только для ipv4 and ipv6 -> policy среагировала на unix socket

### Вывод:
Tetragon правильно видит сокет и отличает от пайпа или файла, но не видит какой конрктно это сокет, поэему matching Partial

объяснение почему будет сложно дальше отфилтровавать по типу сокетов:
Есть ещё один технически возможный шаг: Tetragon умеет фильтровать network argument по Family, например AF_INET или AF_INET6, но такой оператор работает с типами sock/socket. У do_dup2 исходный аргумент приходит как struct file *, поэтому просто добавить Family к нашей текущей type: file policy нельзя. Tetragon также поддерживает извлечение вложенных полей kernel structures через resolve, поэтому теоретически можно попытаться добраться от struct file до underlying socket и затем проверить family. Это уже более сложная kernel-specific mapping и её обязательно пришлось бы отдельно валидировать kernel-specific mapping
[text](https://github.com/cilium/tetragon/blob/main/docs/content/en/docs/concepts/tracing-policy/selectors.md?utm_source=chatgpt.com)

