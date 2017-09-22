#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

# 引入package
use MHA::ManagerUtil;


#在远程主机上执行命令
#参数说明:
# 四个参数依次为:
# $ssh_host   远程主机IP
# $ssh_port   端口
# $ssh_cmd    命令
# $log_output 日志文件路径
#返回值说明:
# 正常的shell出错误的返回值为一个非0的数字,作者经过封装后,进一步把错误代码分别高8位($high)和低8位数字($low),下面一个完整的调用例子
my ( $high, $low ) = MHA::ManagerUtil::exec_ssh_cmd("192.168.0.202","22","/usr/local/mysql/bin/mysql --version","/tmp/mha_fun.log");

#高8位和低8位均为0,代表远程命令执行成功
if ( $high == 0 && $low == 0 ) {
    MHA::ManagerUtil::print_error("execute command successed.")
}else{
    #执行失败,原因会很多:如ip不对,port不对,mysql的路径不对,未作ssh无密码通道等等,具体的原因需要查看 /tmp/mha_fun.log 日志文件
    #从这里也可以看出一个日志系统的重要性,学习查看和分析日志的重要性
    MHA::ManagerUtil::print_error("execute command failed.")
}

#执行本机命令
#查看刚才(MHA::ManagerUtil::exec_ssh_cmd)的日志文件
MHA::ManagerUtil::exec_system("cat /tmp/mha_fun.log");

#查看mha node的版本
#先初始化一个$log对象,然后再作传 参数传给MHA::ManagerUtil::get_node_version,在MHA的代码类似的代码非常多
my $log = MHA::ManagerUtil::init_log("/tmp/mha_fun.log","debug");
my $node_version = MHA::ManagerUtil::get_node_version($log,"root",undef,"192.168.0.202","22");

print $node_version;

### END, Just run it,so easy,so fun. ###