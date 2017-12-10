# linux_server

把配置和修改，监控等内容整理记录一下


# 我想知道我的服务器都监听哪些端口

netstat查看正在监听的端口  
-l表示监听  
-t表示tcp   
-p表示显示程序名  
-n表示部将ip和端口转换成域名和服务名  
-u表示udp   

查看监听中的TCP  netstat -tlnp  
查看监听中的UDP  netstat -ulnp    
查看所有的TCP   netstat -aunp  
查看所有的UDP   netstat -aunp  

**意外的发现，我的Mysql 3306 竟然是对外网开放的**  

# netstat 的一些常用选项

netstat –s  #按照各个协议分别显示其统计数据    
netstat –e  #显示关于以太网的统计数据  
netstat –r  #关于路由表的信息  
netstat –a  #所有的有效连接信息列表  
netstat –n  #所有已建立的有效连接  


