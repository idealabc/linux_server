# linux_server

把配置和修改，监控等内容整理记录一下


# 我想知道我的服务器都监听哪些端口

netstat查看正在监听的端口  
-l表示监听  
-t表示tcp   
-p表示显示程序名  
-n表示部将ip和端口转换成域名和服务名  
-u表示udp   

**netstat 的一些常用选项**

netstat –s  #按照各个协议分别显示其统计数据    
netstat –e  #显示关于以太网的统计数据  
netstat –r  #关于路由表的信息  
netstat –a  #所有的有效连接信息列表  
netstat –n  #所有已建立的有效连接  

```
netstat -tlnp   #查看监听中的TCP  
netstat -ulnp   #查看监听中的UDP  
netstat -aunp   #查看所有的TCP  
netstat -aunp   #查看所有的UDP  
```

**意外的发现，我的Mysql 3306 竟然是对外网开放的**  
 
 

查看我当前的mysql 用的是哪个配置

  ```  
  mysql --help | grep my.cnf

  vi /etc/my.cnf
  [mysqld]
   bind-address    = 127.0.0.1
  ```   


# 我想知道每个目录下的空间使用情况   


  du -h -d 1   

# 我想看看有多少IP探测了我服务器的ssh

```
grep -i 'invalid' /var/log/auth.log | grep -v 'Failed' | grep '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' >tmp.log

awk '{print $10}' tmp.log |sort|uniq -c|sort -nr |head -100
```

# ssh 改用证书登录

* 看了一下auth.log日志，扫ssh 22端口的人还真多，


1. 在客户端生成公钥和私钥,

```
ssh-keygen -t rsa
```

因为有多个服务器，我没有默认的名字，用s1,s2,s3

2. 拷贝公钥s1.pub 到服务器的 ~/.ssh/, 私钥拷贝到客户端的 .ssh/ 下

```
scp s1.pub username@ip:~/.ssh/
cp s1 ~/.ssh

```

3. 在服务端的.ssh/目录下创建 authorized_keys 文件，并把公钥的内存放进去

```
touch ~/.ssh/authorized_keys
cat ~/.ssh/s1.pub >> authorized_keys
#.ssh 文件夹里的目录文件是要有一定的权限要求
chmod 700 ~/.ssh/
chmod 600 authorized_keys

```
4. 配置服务器端的的sshd_config **是sshd_config,不是ssh_config**

```
vi /etc/ssh/sshd_config

Port 2022  #我把22 端口改成 2022了
RSAAuthentication yes  # 是否使用纯的 RSA 认证
PubkeyAuthentication yes #以Pubkey的形式登录
AuthorizedKeysFile      %h/.ssh/authorized_keys  

```
5. 重启sshd服务,我的是ubuntu

```
/etc/init.d/ssh /etc/init.d/ssh restart

#看一下监听是否变成2022端口了

netstat -nltp

```
6. 回到客户端测试一下证书是否有生效

```
ssh -i ~/.ssh/s1 username@ip -p 2022

```
7. 证书登录生效，关闭服务端的充许密码登录

```
vi /etc/ssh/sshd_config

UsePAM yes
UseDNS no
ChallengeResponseAuthentication no
PasswordAuthentication no

#重启sshd服务

/etc/init.d/ssh restart

```
8. 证书生效，每次加-i 也是麻烦， 修改客户端的ssh_config

```
vi /etc/ssh/ssh_config

IdentityFile ~/.ssh/id_rsa
IdentityFile ~/.ssh/s1
   
```
9. 体验一下不用输入密码的感觉吧

```
ssh username@ip -p 2022

```

# 我想分析一下我的web 访问日志 access.log

找到一个非常棒的公具[webalizer](http://www.webalizer.org/)
webalizer是一个高效的、免费的、开源的web服务器日志分析工具。 它产生非常详细的，易于配置使用HTML格式的报告，通过标准的Web浏览器查看。

安装

```
# 依赖  libgd、libpng等库,我的机器上没安装libgd

#libgd
wget https://github.com/libgd/libgd/releases/download/gd-2.2.5/libgd-2.2.5.tar.gz
tar -zxvf libgd-2.2.5.tar.gz 
libgd-2.2.5/ 
./configure
make
make install

#webalizer
wget ftp://ftp.mrunix.net/pub/webalizer/webalizer-2.23-05-src.tgz
tar xzf webalizer-2.23-05-src.tgz
cd webalizer-2.23-05-src
./configure --prefix=/home/user/webalizer
make
make install


#安装成功，开始分析

webalizer -o outDir access_log

```
webalizer 的一些使用示例

```

#想看指定IP或IP段
webalizer -o outDir --ip xxx.xxx.xxx.xxx access_log
webalizer -o outDir  --ip xxx.xx access_log
#想看指定时间段的
webalizer -o outDir --start 06:00:00 --end 07:00:00 access_log

```


# 发现我的服务器nptd 是对外开放的

* 查看我的nptd 版本  /usr/sbin/ntpd --version

* 加固 NTP 服务
把 NTP 服务器升级到 4.2.7p26
关闭现在 NTP 服务的 monlist 功能，在ntp.conf配置文件中增加`disable monitor`选项
在网络出口封禁 UDP 123 端口
 

# 配置ubuntu下的iptables  

具体配置在iptables.sh, 注意 ssh 端口我改成2022 了


iptables-save > /etc/iptables.rules  #保存当前的iptables 规则
iptables-restore < /etc/iptables.rules #使防火墙规则生效

# iptables开机启动
vi /etc/network/if-pre-up.d/iptables 
```
#!/bin/bash
iptables-restore < /etc/iptables.rules
```

chmod +x /etc/network/if-pre-up.d/iptables #添加执行权限
iptables -L -n #查看规则是否生效.


# 给网站配置https

其本上是按这个配置的，(https://coolshell.cn/articles/18094.html)[https://coolshell.cn/articles/18094.html]

1）首先，打开 https://certbot.eff.org 网页。

2）在那个机器上图标下面，你需要选择一下你用的 Web 接入软件 和你的 操作系统。比如，我选的，nginx 和 Ubuntu 14.04

3）然后就会跳转到一个安装教程网页。你就照着做一遍就好了。

```
sudo apt-get update
sudo apt-get install software-properties-common
sudo add-apt-repository ppa:certbot/certbot
sudo apt-get update
sudo apt-get install python-certbot-nginx
sudo certbot --nginx

```

安装好之后

```
sudo certbot --nginx

```
Certbot 会自动帮你注册账户，检测 Nginx 配置文件中的域名，询问你为哪些域名生成证书，是否将 Http 重定向到 Https 等等

修改后 web服务器配置，我的是nginx

```
        server {
                listen       443 ssl;
                server_name  server_Name;

				ssl_certificate      /etc/letsencrypt/live/sitename/fullchain.pem;
				ssl_certificate_key  /etc/letsencrypt/live/sitename/privkey.pem;
				ssl_trusted_certificate /etc/letsencrypt/live/sitename/chain.pem;
                ssl_session_cache    shared:SSL:1m;
                ssl_session_timeout  5m;

                ssl_ciphers  HIGH:!aNULL:!MD5;
                ssl_prefer_server_ciphers  on;

                location / {
                        root   html;
                        index  index.html index.htm;
                }
               }
                
 ```
 
 在http的server 里加一下重定向,把http映射到https
 
 ```
 rewrite ^(.*)$  https://$host$1 permanent;
 
 ```
 

 我的服务器上绑了多个域名
 
 ```

 sudo certbot certonly --webroot -w /usr/local/openresty/nginx/html/ -d domain.com -d domain.cn -d xxx.com -d xxx.cn
 
 ```
 
 
 证书只有三个月的有限期
 
 ```
 sudo certbot renew --dry-run
 
 ```
 
 更新证书,或者创建定时任务
 
 **最后注意一定要重启nginx**
 
 ```
nginx -s reload

 ```
 
 



