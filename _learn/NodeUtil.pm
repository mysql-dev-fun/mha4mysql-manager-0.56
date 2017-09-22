#!/usr/bin/env perl

#  Copyright (C) 2011 DeNA Co.,Ltd.
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#  Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

# 声明包名
package MHA::NodeUtil;

# Perl 浪起来太可怕了,所以建议使用严格语法格式
use strict;
use warnings FATAL => 'all';

# 引入package,如果在Perl的lib路径中找不到相应的文件,则会报错
use Carp qw(croak);
use MHA::NodeConst;
use File::Path;
use Errno();

# 当目录不存时,创建此目录.
sub create_dir_if($) {
  my $dir = shift;
  #判断目录不存时才创建
  if ( !-d $dir ) {
    eval {
      print "Creating directory $dir.. ";
      mkpath($dir);
      print "done.\n";
    };
    # $@为eval命令的错误消息.如果为空,则表示上一次eval命令执行成功
    if ($@) {
      # 细节处理: $@ 是全局的,为了防止影响到其它程序,所有先把值赋给局部变量 $e 后,再 undef 进行重置
      my $e = $@;
      undef $@;
      # 目录已存在,这里逻辑有点问题,因为已经有判断目录不存在才会到这里
      if ( -d $dir ) {
        print "ok. already exists.\n";
      }
      else {
        # 输出错误信息,使用croak会输出脚本名称,代码位置等有用的调试信息,更方便的找到问题
        croak "failed to create dir:$dir:$e";
      }
    }
  }
}

# 对比本机和远程主机文件是否一致
# 参数1:本机文件
# 参数2:远程主机上的文件
# 参数3:ssh user
# 参数4:远程主机IP
# 参数5:远程主机port,默认为 22
# 返回值:
# 1:文件不存在
# 2:文件不一致
# 0:文件一致

# Compare file checksum between local and remote host
sub compare_checksum {
  my $local_file  = shift;
  my $remote_path = shift;
  my $ssh_user    = shift;
  my $ssh_host    = shift;
  my $ssh_port    = shift;
  # 默认端口号
  $ssh_port = 22 unless ($ssh_port);

  my $local_md5 = `md5sum $local_file`;
  return 1 if ($?);
  chomp($local_md5);
  $local_md5 = substr( $local_md5, 0, 32 );
  my $ssh_user_host = $ssh_user . '@' . $ssh_host;
  my $remote_md5 =
`ssh $MHA::NodeConst::SSH_OPT_ALIVE -p $ssh_port $ssh_user_host \"md5sum $remote_path\"`;
  return 1 if ($?);
  chomp($remote_md5);
  $remote_md5 = substr( $remote_md5, 0, 32 );
  return 2 if ( $local_md5 ne $remote_md5 );
  return 0;
}

# 本地文件复制到远程主机上
# 参数:略
sub file_copy {
  my $to_remote   = shift;
  my $local_file  = shift;
  my $remote_file = shift;
  my $ssh_user    = shift;
  my $ssh_host    = shift;
  my $log_output  = shift;
  my $ssh_port    = shift;
  $ssh_port = 22 unless ($ssh_port);

  my $ssh_user_host = $ssh_user . '@' . $ssh_host;
  my ( $from, $to );
  if ($to_remote) {
    $from = $local_file;
    $to   = "$ssh_user_host:$remote_file";
  }
  else {
    $to   = $local_file;
    $from = "$ssh_user_host:$remote_file";
  }

  my $max_retries = 3;
  my $retry_count = 0;
  my $copy_fail   = 1;
  my $copy_command =
    "scp $MHA::NodeConst::SSH_OPT_ALIVE -P $ssh_port $from $to";
  if ($log_output) {
    $copy_command .= " >> $log_output 2>&1";
  }

  while ( $retry_count < $max_retries ) {
    if (
      system($copy_command)
      || compare_checksum(
        $local_file, $remote_file, $ssh_user, $ssh_host, $ssh_port
      )
      )
    {
      my $msg = "Failed copy or checksum. Retrying..";
      if ($log_output) {
        system("echo $msg >> $log_output 2>&1");
      }
      else {
        print "$msg\n";
      }
      $retry_count++;
    }
    else {
      $copy_fail = 0;
      last;
    }
  }
  return $copy_fail;
}

# 拆分错误代码为高8位和低8位
sub system_rc($) {
  my $rc   = shift;
  my $high = $rc >> 8;
  my $low  = $rc & 255;
  return ( $high, $low );
}

# 当文件不存时,创建一个空文件
sub create_file_if {
  my $file = shift;
  if ( $file && ( !-f $file ) ) {
    open( my $out, ">", $file ) or croak "$!:$file";
    close($out);
  }
}

# 当文件存在时,删除一个文件
sub drop_file_if($) {
  my $file = shift;
  if ( $file && -f $file ) {
    unlink $file or croak "$!:$file";
  }
}

# 解析host的IP地址
sub get_ip {
  my $host = shift;
  my ( $bin_addr_host, $addr_host );
  if ( defined($host) ) {
    $bin_addr_host = gethostbyname($host);
    unless ($bin_addr_host) {
      croak "Failed to get IP address on host $host!\n";
    }
    $addr_host = sprintf( "%vd", $bin_addr_host );
    return $addr_host;
  }
  return;
}

# 获取系统当前时间,精确到秒
sub current_time() {
  my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime();
  $mon  += 1;
  $year += 1900;
  my $val = sprintf( "%d-%02d-%02d %02d:%02d:%02d",
    $year, $mon, $mday, $hour, $min, $sec );
  return $val;
}

# 检查manager的版本,低于node版本时,直接报错并退出.
sub check_manager_version {
  my $manager_version = shift;
  if ( $manager_version < $MHA::NodeConst::MGR_MIN_VERSION ) {
    croak
"MHA Manager version is $manager_version, but must be $MHA::NodeConst::MGR_MIN_VERSION or higher.\n";
  }
}

# 从字符串中解析出mysql的版本号,只取数字，便于比较版本大小
# $str = "SELECT VERSION() AS Value"
sub parse_mysql_version($) {
  my $str = shift;
  my $result = sprintf( '%03d%03d%03d', $str =~ m/(\d+)/g );
  return $result;
}

# 从字符串中解析出mysql的主版本号,只取数字，便于比较版本大小
# $str = "SELECT VERSION() AS Value"
sub parse_mysql_major_version($) {
  my $str = shift;
  my $result = sprintf( '%03d%03d', $str =~ m/(\d+)/g );
  return $result;
}

# 比较$my_version是否高于$target_version
# mysql 主从结构 从库版本要高于主库版本
sub mysql_version_ge {
  my ( $my_version, $target_version ) = @_;
  my $result =
    parse_mysql_version($my_version) ge parse_mysql_version($target_version)
    ? 1
    : 0;
  return $result;
}

# shell需转义的特殊字符数组
my @shell_escape_chars = (
  '"', '!', '#', '&', ';', '`', '|',    '*',
  '?', '~', '<', '>', '^', '(', ')',    '[',
  ']', '{', '}', '$', ',', ' ', '\x0A', '\xFF'
);

# 反转义shell的特殊字符
sub unescape_for_shell {
  my $str = shift;
  if ( !index( $str, '\\\\' ) ) {
    return $str;
  }
  foreach my $c (@shell_escape_chars) {
    my $x       = quotemeta($c);
    my $pattern = "\\\\(" . $x . ")";
    $str =~ s/$pattern/$1/g;
  }
  return $str;
}

# 转义shell的特殊字符
sub escape_for_shell {
  my $str = shift;
  my $ret = "";
  foreach my $c ( split //, $str ) {
    my $x      = $c;
    my $escape = 0;
    foreach my $e (@shell_escape_chars) {
      if ( $e eq $x ) {
        $escape = 1;
        last;
      }
    }
    if ( $x eq "'" ) {
      $x =~ s/'/'\\''/;
    }
    if ( $x eq "\\" ) {
      $x = "\\\\";
    }
    if ($escape) {
      $x = "\\" . $x;
    }
    $ret .= "$x";
  }
  $ret = "'" . $ret . "'";
  return $ret;
}

# 转义mysql_command的特殊字符
sub escape_for_mysql_command {
  my $str = shift;
  my $ret = "";
  foreach my $c ( split //, $str ) {
    my $x = $c;
    if ( $x eq "'" ) {
      $x =~ s/'/'\\''/;
    }
    $ret .= $x;
  }
  $ret = "'" . $ret . "'";
  return $ret;
}

# mysql終端命令的预处理
sub client_cli_prefix {
  my ( $exe, $bindir, $libdir ) = @_;
  croak "unexpected client binary $exe\n" unless $exe =~ /^mysql(?:binlog)?$/;
  my %env = ( LD_LIBRARY_PATH => $libdir );
  my $cli = $exe;
  if ($bindir) {
    if ( ref $bindir eq "ARRAY" ) {
      $env{'PATH'} = $bindir;
    }
    elsif ( ref $bindir eq "" ) {
      $cli = escape_for_shell("$bindir/$exe");
    }
  }
  for my $k ( keys %env ) {
    if ( my $v = $env{$k} ) {
      my @dirs = ref $v eq "ARRAY" ? @{$v} : ( ref $v eq "" ? ($v) : () );
      @dirs = grep { $_ && !/:/ } @dirs;
      if (@dirs) {
        $cli = "$k="
          . join( ":", ( map { escape_for_shell($_) } @dirs ), "\$$k" )
          . " $cli";
      }
    }
  }

  # $cli .= " --no-defaults";
  return $cli;
}

1;
