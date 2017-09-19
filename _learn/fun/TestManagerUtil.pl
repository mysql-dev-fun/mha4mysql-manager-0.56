#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

# 引入package
use MHA::ManagerUtil;


#以远程主机上执行命令
MHA::ManagerUtil::exec_ssh_cmd("192.168.0.202","22","/usr/local/mysql/bin/mysql --version","/tmp/mha_fun.log");

#执行本机命令
MHA::ManagerUtil::exec_system("cat /tmp/mha_fun.log");

#查看node的版本
my $log = MHA::ManagerUtil::init_log("/tmp/mha_fun.log","debug");
my $node_version = MHA::ManagerUtil::get_node_version($log,"root",undef,"192.168.0.202","22");

print $node_version;