# Хранение бекапов в DataStorage

DataStorage (далее DS) - хранилище данных расположенное на хостинге https://www.netangels.ru/ , с которым можно работать по FTP/SFTP/RSYNC/SCP.

Скрипты автоматизируют процесс создание инкрементального tar-бекапа в DS используя SFTP.
Схема хранения данных расчитана на цикл в две недели и минимум два полных бекапа. Для удобства загрузки файлы разбиваются на чанки в 2gb через split.

## Настройка бакапов
Всё действия выполняются от пользователя root.

1. Создать ssh-ключ с именем `id_rsa_ds` и загрузить публичную часть в DS через панель управления:
```
    ssh-keygen -f id_rsa_ds -P ''
```
2. Запустить скрипт `install-env.sh`, он создаст необходимое окружение для работы. Внимание, разбитый файл сохраняется в каталоге `/root/.ds-backup/split_files`.

3. Указать в файле `/root/.ds-backup/backup.list` список каталогов с полным путем. Это листинг каталогов, который будет сохранен в tar-бекапе.

4. Указать в файл `/root/.ds-backup/excludes.list` список исключений из бекапа, если они есть. В ином случае оставляем файл пустым.

5. Скрипты `worker-backup.sh`, `clean-backup.sh`, `full-backup.sh` поместить в `/usr/local/sbin/`.

6. Добавить в cron задание для запуска `worker-backup.sh`, пример:
```
    # Создание бекапа в DataStorage. LOGIN - логин услуги DataStorage
    LOGIN='u123'
    0 2 * * *   sleep $(shuf -i 0-240 -n 1)m && /usr/local/sbin/worker-backup.sh $LOGIN 14 1>/var/log/backup-worker.log 2>&1
```
## Зависимости
Для работы скриптов требуется поставить пакеты:

    - lzop
    - bc
    - mawk
    - coreutils (команда csplit)

## Восстановление файлов из бекапа
Файл разбит на чанки по 2gb, поэтому перед восстановлением их нужно объединить.
Команды:
```
    # листинг
    ls -1 backup/
    user-20231107-full.tar.lzo.split_aa
    user-20231107-full.tar.lzo.split_ab
    user-20231107-full.tar.lzo.split_ac
    user-20231107-full.tar.lzo.split_ad

    # объединение скачанных файлов
    for F in $(ls -1 | sort); do cat "$F" >> full.tar.lzop; done

    # распаковка
    mkdir RESTORE
    cat full.tar.lzop | lzop -d | tar -xf - -C RESTORE/

    # листинг
    ls -ls RESTORE/
    итого 8
    4 drwxr-xr-x 77 root root 4096 Nov  7 18:15 etc
    4 drwxr-xr-x  4 root root 4096 Nov  7 18:14 home
```
