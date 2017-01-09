package Normalizer::tests;

use strict;
use warnings;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        trace_initialize
        trace_run
    );
    %EXPORT_TAGS = ('all' => \@EXPORT_OK);
}

binmode(STDOUT, ":encoding(utf8)");     #treat as if it is UTF-8
binmode(STDIN, ":encoding(utf8)");      #actually check if it is UTF-8W
binmode(STDERR, ":encoding(utf8)");

use open ':std', ':encoding(UTF-8)';

use utf8;
use v5.14;

use Data::Dumper;

# TODO: bring major testing subroutines into this package
# TODO: add a way to turn tracing on or off. It can create huge trace files when used on a large run

# TODO: make this work with module-based normalizer


# ----------------------------------------------------------------------

sub trace_initialize {
    # TODO: temporary
    return;
    open my $trace_out, '>', 'trace.log';
    close $trace_out;
}

# ----------------------------------------------------------------------

sub trace_run {
    
    # TODO: temporary
    return;
    
    my ($subroutine, $string) = @_;
    open my $trace_out, '>>', 'trace.log';
    
    if ($string && $string eq 'HR') {
        print $trace_out "\n * * * * * * * * * * * * * * *\n\n";
        return;
    }
    
    print $trace_out $subroutine . "\t";
    if ($string) {
        if (ref($string) eq 'HASH') {
            print $trace_out Dumper $string;
        }
        else {
            print $trace_out $string;
        }
    }
    print $trace_out "\r\n";
    close $trace_out;
}

1;
