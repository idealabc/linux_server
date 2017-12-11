# linux_server

把配置和修改，监控等内容整理记录一下


### 我想知道我的服务器都监听哪些端口

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


### 我想知道每个目录下的空间使用情况   


  du -h -d 1   

### 我想看看有多少IP探测了我服务器的ssh

```
grep -i 'invalid' /var/log/auth.log | grep -v 'Failed' | grep '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' >tmp.log

awk '{print $10}' tmp.log |sort|uniq -c|sort -nr |head -100
```

### ssh 改用证书登录

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







