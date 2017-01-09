package Normalizer::normalize_flags;

use strict;
use warnings;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        set_continued_flag
        set_copy_flag
        set_letter_before_number_flag
        set_not_publ_flag
        set_ns_flag
        set_switch_flag
    );
    %EXPORT_TAGS = ('all' => \@EXPORT_OK);
}

binmode(STDOUT, ":encoding(utf8)");     #treat as if it is UTF-8
binmode(STDIN, ":encoding(utf8)");      #actually check if it is UTF-8W
binmode(STDERR, ":encoding(utf8)");

use open ':std', ':encoding(UTF-8)';

use utf8;
use v5.14;

use Normalizer::tests qw(:all);


# ----------------------------------------------------------------------


sub set_letter_before_number_flag {
    # v.A21 to v.21, then add the A back on in the end
    my ($string, $flags_ref) = @_;
    trace_run('set_number_letter_reverse_flag in', $string);
    if ($string =~ m/\bv\.? *[A-Z]\d+/) {
        while ($string =~ m/\bv\.? *[A-Z]\d+/) {
            $string =~ s/\bv\.? *([A-Z])(\d+)/v\.$2/;
            $flags_ref->{'letter_before_number'}{$2} = $1;
        }
        trace_run('set_number_letter_reverse_flag success', $string);
        return $string;
    }
    trace_run('set_number_letter_reverse_flag failed', $string);
    return $string;
}


# ----------------------------------------------------------------------


sub set_switch_flag {   
    
    my ($string, $numberofissues) = @_;
    trace_run('set_switch_flag', $string);
    
    if ( $numberofissues > 1 ) {
        trace_run('set_switch_flag failed', "$numberofissues issues");
        return 0;
    }
        
    # Looking for something like "no." at the beginning of the string, to indicate a leading number (without volume)
    if (   $string =~ m/^N|^n|no[^v]|No[^v]|Heft|Fasc|bull(?:etin)?\./
        && $string !~ m/V|[^o]v|^v|Anno|Jah|Ban|Tom|jaa|Band|Bd\.|^t\.|T|^[0-9]{1}/ )
    {
        if ( $numberofissues eq 0 || $numberofissues eq "" ) {
            return 1;
        }
    # Find evidence of numbers going higher than supposed number of issues per year.
    # This would indicate numbers constantly increasing (not reset to 1 every volume), calling for the switch flag.
        if ( $string =~ m/^n([0-9]{2,3})/ || $string =~ m/; n([0-9]{2,3})/ ) {
            if ( $1 > $numberofissues ) {
                trace_run('set_switch_flag on gt number of issues', "$numberofissues number of issues");
                return 1;
            }
        }
    }
    # NPF: special case of "Teil" ("part" in German) leading off the line
    return 1 if $string =~ m/^Teil/;
    
    trace_run('set_switch_flag failed', $string);
    return 0;
}


# ----------------------------------------------------------------------


sub set_continued_flag {
    my $string = shift;
    trace_run('set_continued_flag', $string);
    ## if an entry end with a hyphen mark the continued flag as true
    if ( $string =~ m/(-\s*$)/ ) {
        return 1;
    }
    trace_run('set_continued_flag failed', $string);
    return 0;
}


# ----------------------------------------------------------------------


sub set_copy_flag {
    my $string = shift;
    trace_run('set_copy_flag', $string);
    if    ( $string =~ m/2nd cop/)       { return 1; }
    elsif ( $string =~ m/second cop/)    { return 1; }
    elsif ( $string =~ m/2v\.d cop/)     { return 1; }
    elsif ( $string =~ m/secov\.d cop/)  { return 1; }
    trace_run('set_copy_flag failed', $string);
    return 0;
}


# ----------------------------------------------------------------------


sub set_not_publ_flag {
    trace_run('set_not_publ_flag');
    my ($string, $flags_ref) = shift;
    $flags_ref->{'not_publ'} = 0;
    if ( $string =~ m/none publ/
        || $string =~ m/not publ/
        || $string =~ m/never publ/
        || $string =~ m/publication suspended/
        || $string =~ m/publ\. suspended/ )
    {
        $string =~ s/none published//g;
        $string =~ s/none publ\.*//g;
        $string =~ s/not published//g;
        $string =~ s/not publ\.*//g;
        $string =~ s/never published//g;
        $string =~ s/never publ\.*//g;
        $string =~ s/publication suspended//g;
        $string =~ s/publ\.* suspended//g;
        $flags_ref->{'not_publ'} = 1;
    }
    return($string);
}

# ----------------------------------------------------------------------


sub set_ns_flag {
    my ($string, $flags_ref) = @_;
    trace_run('set_ns_flag in', $string);

    my $ns_regex = qr/^Neue Folge:?|\bns:?|nouv\.? sér\.? *:? *|\bn\.s\.:?|\bv\.s:?|\bv\.*s\.:?|\bn\.*f\.:?/;
    
    $string =~ s/$ns_regex/n\.s\./g;
    $flags_ref->{'ns_flag'} = 0;
    if (   $string =~ m/^Neue Folge/
        || $string =~ m/^\s*ns/
        || $string =~ m/^\s*n\.s\./
        || $string =~ m/^\s*v\.s/
        || $string =~ m/^\s*v\.*s\./
        || $string =~ m/^\s*n\.*f\./
        || $string =~ m/^\s*v\.*f\./ )
        {
            $flags_ref->{'ns_flag'} = 1;
        }

    # look for strings that have the same series info twice: "n.s. v.1-n.s. v.3"
    if ($string =~ /($ns_regex).+($ns_regex)/) {
        my $first_series = $1;
        my $second_series = $1;
        if ($first_series eq $second_series) {
            $string =~ s/$first_series//g;
        }
        else {
            # TODO: multi-series string? error message or fail?
        }
    }
    $string =~ s/$ns_regex//g;
    
    if ($flags_ref->{'ns_flag'}) {
        trace_run('set_ns_flag yes', $string);
    }
    else {
        trace_run('set_ns_flag no', $string);
    }
    return $string;    
}


# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
# ----------------------------------------------------------------------




1;
