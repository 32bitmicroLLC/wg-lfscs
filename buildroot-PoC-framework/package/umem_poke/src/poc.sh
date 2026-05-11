#!/bin/sh
echo running without corruption
/usr/umem_poke/umem_poke_victim
echo
echo running again with corruption
insmod /usr/umem_poke/umem_poke.ko
rm -f stdout_
mkfifo stdout_
/usr/umem_poke/umem_poke_victim >stdout_ &
pid=$!
sleep 1
payload='corrupted                 '
read -r str <stdout_
echo $str
addr=$(echo $str | cut -d" " -f3)
echo "${pid}:$addr:1074707572726F63" > /proc/umem_poke
read -r str <stdout_
echo $str
wait $pid
