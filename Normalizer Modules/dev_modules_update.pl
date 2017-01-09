#!/usr/bin/perl

use strict;
use warnings;

binmode(STDOUT, ":encoding(utf8)");     #treat as if it is UTF-8
binmode(STDIN, ":encoding(utf8)");      #actually check if it is UTF-8W
binmode(STDERR, ":encoding(utf8)");

use open ':std', ':encoding(UTF-8)';

use v5.14;
use utf8;

use Cwd 'abs_path';
use Config;
use File::Copy;

## System-specific check
my ($environment, $output_folder);
if    ($Config{osname} eq 'MSWin32') { $environment = 'windows'; }
elsif ($Config{osname} eq 'cygwin')  { $environment = 'cygwin';  }
elsif ($Config{osname} eq 'freebsd') { $environment = 'freebsd'; }    # web space
elsif ($Config{osname} eq 'linux')   { $environment = 'linux';    }

my $data_folder;
if    ($environment eq 'windows') {  $output_folder = "C:\\Strawberry\\perl\\lib\\NormalizerDev\\"; }
elsif ($environment eq 'linux')   {  $output_folder = '/usr/local/lib/site_perl/NormalizerDev/'; }
elsif ($environment eq 'cygwin')  {  $output_folder = '/usr/lib/perl5/5.22/NormalizerDev/'; }

# clear the output file
my @outfiles = <$output_folder*>;
foreach my $o_f (@outfiles) {
    unlink $o_f;
}

my $script_location = abs_path($0);
$script_location =~ s/[\/\\][^\/\\]+$//;

my @files = <$script_location/*>;
foreach my $f (@files) {
    if ($f =~ /\.pm$/) {
        $f =~ m/([^\/\\]+)$/;
        say "Module: " . $1;
        my $destination = $output_folder . $1;
        say $destination;
        open my $output, '>', $destination;
        open my $input, '<', $f;
        
        while (<$input>) {
            $_ =~ s/Normalizer::/NormalizerDev::/g;
            print $output $_;
        }
    }
}

my $command = "chmod +x $output_folder*";
system($command);
