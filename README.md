# Хранение бекапов в DataStorage

DataStorage - хранилище данных расположенное на хостинге https://www.netangels.ru/ , с которым можно работать по FTP/SFTP/RSYNC/SCP. 

Скрипты автоматизируют процесс создание инкрементального бекапа в DS используя SFTP. 
Схема хранения данных расчитана на цикл в две недели.   


Всё действия выполняются от пользователя root:

  - создать ssh-ключ с именем 'id_rsa_ds' и загрузить публичную часть в DS через панель управления
        
        ssh-keygen -f id_rsa_ds -P ''

  - запустить скрипт `env_install`, он создаст необходимое окружение для работы
  - в файл /root/.ds-backup/backup.list записать список каталогов, с полным путем, для бекапа
  - в файл /root/.ds-backup/excludes.list записать исключения из бекапа, если они есть
  - скрипты `backup-worker` `ds_clean` `ds_fullbackup` поместить в /usr/local/sbin/, `env_install` - удалить
  - добавить в cron выполнение backup-worker, пример:

        0 2 * * *   sleep $(shuf -i 0-240 -n 1)m && /usr/local/sbin/backup-worker $LOGIN 1>/var/log/backup-worker.log 2>&1

