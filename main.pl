#!/usr/bin/perl
# use ExtUtils::testlib;
use strict;
use warnings;
# use FFI;

package DirEntry;

use FFI::Platypus::Record;
record_layout_1(
    'uint64' => 'inumber',
    'string(256)' => 'name',
    'uint8' => 'namelen',
    'uint8' => 'ftype'
);

package main;

use FFI::Platypus 1.00;
my $ffi = FFI::Platypus->new(api => 1);
$ffi->lib('mylib/cmake-build-debug/libmylib.so');
$ffi->load_custom_type('::Enum', 'error_t',
    'NONE',
    'FM_XFS_ERR_NOT_SUPPORTED',
    'NOT_FOUND',
    'ERROR_WITH_DEVICE',
    'FM_XFS_ERR_OUT_DEVICE',
    'ERROR_WITH_MAGIC',
    'ERROR_WITH_FORMAT',
    'FILENAME_NOT_FOUND',
    'NOT_A_FILE',
    'NOT_A_DIRECTORY');
$ffi->type('record(DirEntry)' => 'DirEntry');
$ffi->type('(opaque,opaque)->int' => 'callback_t');
$ffi->attach(print_devices => ['int'] => 'void');
$ffi->attach(xfs_ls => ['opaque', 'opaque', 'callback_t'] => 'error_t');
$ffi->attach(xfs_cd => ['opaque', 'string', 'size_t'] => 'error_t');
$ffi->attach(xfs_cp => ['opaque', 'string', 'string'] => 'error_t');
$ffi->attach(xfs_cat => ['opaque', 'string', 'size_t'] => 'error_t');
$ffi->attach(xfs_alloc => ['string'] => 'opaque');
$ffi->attach(xfs_dealloc => ['opaque'] => 'error_t');
$ffi->attach(xfs_pwd => ['opaque'] => 'string');

if (@ARGV >= 1 && $ARGV[0] eq 'list') {
  if (@ARGV >= 2) {
    device_list($ARGV[1]);
  } else {
    device_list(-1);
  }
} elsif (@ARGV >= 2 && $ARGV[0] eq 'open') {
  start_ui($ARGV[1]);
} else {
  print_usage();
}

sub device_list {
  print_devices($_[0]);
  # FFI::print_devices($_[0]);
}

sub start_ui {
  my $fm = xfs_alloc($_[0]);
  return until $fm;

  print xfs_pwd($fm), ">";
  LOOP:
  while (my $line = <STDIN>) {
    $line =~ s/[\r\n]+$//;
    my $result = 'NONE';
    if ($line =~ /^ls/) {
      $result = call_ls($fm, $line);
    } elsif ($line =~ /^cd/) {
      $line =~ s/^cd\s?//;
      $result = call_cd($fm, $line);
    } elsif ($line =~ /^cp/) {
      $line =~ s/^cp\s*//;
      $result = call_cp($fm, $line);
    } elsif ($line =~ /^cat/) {
      $line =~ s/^cat\s*//;
      $result = call_cat($fm, $line);
    } elsif ($line =~ /^exit/) {
      last LOOP
    } else {
      print "Unknown command '$line'\n"
    }
    print $result, "\n" if $result ne 'NONE';
    print xfs_pwd($fm), ">";
  }

  fm_xfs_dealloc($fm);
}

sub call_ls {
  return xfs_ls($_[0], 0, $ffi->closure(sub {
    my $rec = $ffi->cast('opaque' => 'DirEntry *', $_[1]);
    if ($rec->ftype == 1) {
      print "f ";
    } elsif ($rec->ftype == 2) {
      print "d ";
    } else {
      print "? ";
    }
    print substr($rec->name, 0, $rec->namelen), "\n";
  }));
  my $result = FFI::fm_xfs_ls($_[0]);
}

sub call_cd {
  #$_[1] =~ /^\s?(\S+)\s?$/;
  $_[1] =~ /^\s?([.\s]+)\s?$/;
  # if (!$1) {
  #   return fm_xfs_cd($_[0], ' ', 1);
  # }
  print '"' . $1 . "\"\n";
  # return fm_xfs_cd($_[0], ' ', 1);
  # my $test = shift @ARGV;
  # print $test;
  return fm_xfs_cd($_[0], $1, length $1);
}

sub call_cp {
  $_[1] =~ /^\s*(\S+)\s+(\S+)\s*$/;
  print $1, $2;
  print "\n";
  return xfs_cp($_[0], $1, $2);
}

sub call_cat {
  $_[1] =~ /^\s*(\S+)\s*$/;
  return xfs_cat($_[0], $1, length $1);
}


sub print_usage {
  print "Try it:
\t./main.pl list -- list of all devices\n
\t./main.pl open <some device> -- open an xfs filesystem\n";
}
