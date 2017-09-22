#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

# Perl日志系统 Log:Dispatch 使用实例代码
# Log::Dispatch,可以把日志信息输入到file,screen,email中,且使用起来非常的简单和方便;
# 以下代码来自CPAN的Log::Dispath项目:
# http://search.cpan.org/~drolsky/Log-Dispatch-2.66/lib/Log/Dispatch.pm

use Log::Dispatch;

# 初始化一个 $log 对象,同时绑定记录到File和输出到Screen,且指定了不同的level
my $log = Log::Dispatch->new(
    outputs => [
        [ 'File',   min_level => 'debug', filename => '/tmp/perl.log' ],
        [ 'Screen', min_level => 'info' ],
    ],
);

# 生成info日志
$log->info('Info:Blah, blah');

# 生成debug日志
$log->debug('Debug:Blah, blah');

# 生成error日志
$log->error('Error:Blah, blah');

# 运行这个程序后,观察一下Screen和/tmp/perl.log的内容,并思考一下如果使Screen和File的内容完全一样,需要如何修改代码.

# Log::Dispatch 总共有7个级别,具体可能参考文档,关于日志级别,简单总结一下:
# 1.在MHA中可以通过 log_level = [No|App/Global|info|debug] 配置 日志级别.
#    参考:https://raw.githubusercontent.com/wiki/yoshinorim/mha4mysql-manager/Parameters.md
# 2.debug是最低的日志级别,一般用于开发人员记录排错的相关信息.
# 3.程序在运行时,将忽略低于配置log_level的日志输出.如:配置log_level=info时,所有的 $log->debug('Blah, blah')信息都会被忽略.
# 4.log_level的主要作用是在不用修改代码的前提下,通过简单的配置就可以区分生成环境和开发环境日志内容.

### END, Just sun it,so easy,so fun. ###