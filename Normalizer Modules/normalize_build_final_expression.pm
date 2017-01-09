package Normalizer::normalize_build_final_expression;

use strict;
use warnings;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        build_final_expression
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

use  Normalizer::normalize_transforms qw(:all);

# TODO: deal with all of the warnings of uninitialized variables, etc
no warnings 'uninitialized';

use Data::Dumper;

sub build_final_expression {   

    my ($elements_ref, $flags_ref, $newthis) = @_;
    trace_run('build_final_expression in newthis', $newthis);
    trace_run('build_final_expression in', $elements_ref);
    my ($final);

    if ( !$flags_ref->{'vol'} && !$flags_ref->{'no'} ) {
        $final = _no_vol_no_num($elements_ref, $flags_ref, $newthis);
    }
    elsif ( $flags_ref->{'vol'} && !$flags_ref->{'no'} && $flags_ref->{'onevol'} ) {
        $final = _vol_no_num_onevol($elements_ref, $flags_ref, $newthis);
    }
    elsif ( $flags_ref->{'vol'} && !$flags_ref->{'no'} && !$flags_ref->{'onevol'} ) {
        $final = _vol_no_num_no_onevol($elements_ref, $flags_ref, $newthis);
    }
    elsif ($flags_ref->{'vol'}
        && $flags_ref->{'no'}
        && !$flags_ref->{'onevol'}
        && $flags_ref->{'oneno'} )
    {
        $final = _vol_num_no_onevol_onenum($elements_ref, $flags_ref, $newthis);
    }
    elsif ($flags_ref->{'vol'}
        && $flags_ref->{'no'}
        && $flags_ref->{'onevol'}
        && !$flags_ref->{'oneno'} )
    {
        $final = _vol_num_onevol_no_onenum($elements_ref, $flags_ref, $newthis);
    }
    elsif ($flags_ref->{'vol'}
        && $flags_ref->{'no'}
        && !$flags_ref->{'onevol'}
        && !$flags_ref->{'oneno'} )
    {
        $final = _vol_num_no_onevol_no_onenum($elements_ref, $flags_ref, $newthis);
    }
    elsif ($flags_ref->{'vol'}
        && $flags_ref->{'no'}
        && $flags_ref->{'onevol'}
        && $flags_ref->{'oneno'} )
    {
        $final = _vol_num_onevol_onenum($elements_ref, $flags_ref, $newthis);
    }
    elsif ( !$flags_ref->{'vol'} && $flags_ref->{'no'} && $flags_ref->{'oneno'} ) {
        $final = _no_vol_num_onenum($elements_ref, $flags_ref, $newthis);
    }
    elsif ( !$flags_ref->{'vol'} && $flags_ref->{'no'} && !$flags_ref->{'oneno'} ) {
        $final = _no_vol_num_no_onenum($elements_ref, $flags_ref, $newthis);
    }
    else {
        $final = _other_expressions($elements_ref, $flags_ref, $newthis);
    }

    # NPF: to deal with things like v.1, v.3, v.4 that fail at the moment
    if (_check_vol_or_num_only($newthis)) {
        $final = $newthis;
        trace_run('_check_vol_or_num_only success', $final);
    }

    $final = final_transform($final, $flags_ref, $elements_ref->{'number_of_issues'});

    ## if the expression originally ended with a - add -current to the expression
    if ( $flags_ref->{'continued'} ) {
        $final = continued($final);
    }

    # CT: commented out to add to all cases (below), not just the final else
    #if ($flags_ref->{'ns'}) {
    # $final = "n.s. " . $final;
    #}

    if ( $flags_ref->{'not_publ'} ) {
        $final = '$z' . $final . " not published";
    }
    ## create array of multiple volumes descriptions from one 866
    trace_run('build_final_expression out', $final);
    return $final;
}


# ----------------------------------------------------------------------

sub _no_vol_no_num {

    my $final;
    my ($elements_ref, $flags_ref, $newthis) = @_;
    trace_run('_no_vol_no_num in');
    
    if (!$elements_ref->{'secondnumexp'}) {
        $elements_ref->{'secondnumexp'} = '';
    }

    if ( !$elements_ref->{'lastyearexp'} || $elements_ref->{'lastyearexp'} eq "" ) {
        $final =
            $elements_ref->{'finalser'} . " "
          . $elements_ref->{'firstnumexp'} . "-"
          . $elements_ref->{'secondnumexp'}
          . $elements_ref->{'finalpt'} . "("
          . $elements_ref->{'firstchron'} . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'firstyearexp'} . ")";
        if ( $flags_ref->{'monthmatch'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'firstnumexp'} . "-"
              . $elements_ref->{'secondnumexp'}
              . $elements_ref->{'finalpt'}
              . $elements_ref->{'comboexp'};
        }
    }
    else {
        $final =
            $elements_ref->{'finalser'} . " "
          . $elements_ref->{'firstnumexp'} . "-"
          . $elements_ref->{'secondnumexp'}
          . $elements_ref->{'finalpt'} . "("
          . $elements_ref->{'firstchron'} . " "
          . $elements_ref->{'firstyearexp'} . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'lastyearexp'} . ")";
        if ( $flags_ref->{'monthmatch'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'firstnumexp'} . "-"
              . $elements_ref->{'secondnumexp'}
              . $elements_ref->{'finalpt'}
              . $elements_ref->{'comboexp'};
        }
    }
    return $final;
}

# ----------------------------------------------------------------------

sub _vol_no_num_onevol {

    trace_run('_vol_no_num_onevol');

    my $final;
    my ($elements_ref, $flags_ref, $newthis) = @_;

    if ( !$elements_ref->{'lastyearexp'} || $elements_ref->{'lastyearexp'} eq "" ) {
        $final =
            $elements_ref->{'finalser'} . " "
          . $elements_ref->{'finalvol'} . "-v."
          . $elements_ref->{'firstnumexp'} . ":"
          . $elements_ref->{'finalpt'} . "("
          . $elements_ref->{'firstchron'} . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'firstyearexp'} . ")";
        if ( $flags_ref->{'monthmatch'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . "-v."
              . $elements_ref->{'firstnumexp'} . ":"
              . $elements_ref->{'finalpt'}
              . $elements_ref->{'comboexp'};
        }
        ## now associates year with appropriate volume
        if (   $newthis =~ m/\)-/
            && $newthis !~ m/\)($| )/
            && $newthis !~ m/no\./ )
        {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . " ("
              . $elements_ref->{'firstchron'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'firstyearexp'} . ")" . "-v."
              . $elements_ref->{'firstnumexp'} . ":"
              . $elements_ref->{'finalpt'};
            if ( $flags_ref->{'monthmatch'} ) {
                $final =
                    $elements_ref->{'finalser'} . " "
                  . $elements_ref->{'finalvol'}
                  . $elements_ref->{'comboexp'} . "-v."
                  . $elements_ref->{'firstnumexp'} . ":"
                  . $elements_ref->{'finalpt'};
            }
        }
    }
    else {
        $final =
            $elements_ref->{'finalser'} . " "
          . $elements_ref->{'finalvol'} . "-v."
          . $elements_ref->{'firstnumexp'} . ":"
          . $elements_ref->{'finalpt'} . "("
          . $elements_ref->{'firstchron'} . " "
          . $elements_ref->{'firstyearexp'} . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'lastyearexp'} . ")";
        if ( $flags_ref->{'monthmatch'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . "-v."
              . $elements_ref->{'firstnumexp'} . ":"
              . $elements_ref->{'finalpt'}
              . $elements_ref->{'comboexp'};
        }
    }
    if ( $newthis =~ m/no\./ && $newthis =~ m/v\./ ) {
        $final =~ s/[A-Za-z]{3,6}//g;
    }
    return $final;
}


# ----------------------------------------------------------------------


sub _vol_no_num_no_onevol {

    trace_run('_vol_no_num_no_onevol');
    my $final;
    my ($elements_ref, $flags_ref, $newthis) = @_;

    if ( !$elements_ref->{'lastyearexp'} || $elements_ref->{'lastyearexp'} eq "" ) {
        $final =
            $elements_ref->{'finalser'} . " "
          . $elements_ref->{'finalvol'} . ":"
          . $elements_ref->{'finalpt'} . "("
          . $elements_ref->{'firstchron'} . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'firstyearexp'} . ")";
        if ( $flags_ref->{'monthmatch'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . ":"
              . $elements_ref->{'finalpt'}
              . $elements_ref->{'comboexp'};
        }
    }
    else {
        $final =
            $elements_ref->{'finalser'} . " "
          . $elements_ref->{'finalvol'} . ":"
          . $elements_ref->{'finalpt'} . "("
          . $elements_ref->{'firstchron'} . " "
          . $elements_ref->{'firstyearexp'} . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'lastyearexp'} . ")";
        if ( $flags_ref->{'monthmatch'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . ":"
              . $elements_ref->{'finalpt'}
              . $elements_ref->{'comboexp'};
        }
    }
    return $final;
}




# ----------------------------------------------------------------------

sub _vol_num_no_onevol_onenum {

    trace_run('_vol_num_no_onevol_onenum');
    my $final;
    my ($elements_ref, $flags_ref, $newthis) = @_;
    if ( $elements_ref->{'subno'} && $elements_ref->{'firstnumexp'} && $elements_ref->{'subno'} == $elements_ref->{'firstnumexp'} ) {
        if ( !$elements_ref->{'lastyearexp'} || $elements_ref->{'lastyearexp'} eq "" ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . ":"
              . $elements_ref->{'finalno'}
              . $elements_ref->{'finalpt'} . "("
              . $elements_ref->{'firstchron'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'firstyearexp'} . ")";
            if ( $newthis =~ m/no\..*-/ && $newthis !~ m/-.*no\./ )
            {
                $final =~
s/(v\.[0-9]{1,3}\/*[0-9]{0,3})(-v\.[0-9]{1,3}\/*[0-9]{0,3})(:no\.[0-9]{1,3}\/*[0-9]{0,3})/$1$3$2/g;
            }
        }
        else {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . ":"
              . $elements_ref->{'finalno'}
              . $elements_ref->{'finalpt'} . "("
              . $elements_ref->{'firstchron'} . " "
              . $elements_ref->{'firstyearexp'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'lastyearexp'} . ")";
            if ( $newthis =~ m/no\..*-/ && $newthis !~ m/-.*no\./ )
            {
                $final =~
s/(v\.[0-9]{1,3}\/*[0-9]{0,3})(-v\.[0-9]{1,3}\/*[0-9]{0,3})(:no\.[0-9]{1,3}\/*[0-9]{0,3})/$1$3$2/g;
            }
            if ( $flags_ref->{'monthmatch'} ) {
                $final =
                    $elements_ref->{'finalser'} . " "
                  . $elements_ref->{'finalvol'} . ":"
                  . $elements_ref->{'finalno'}
                  . $elements_ref->{'finalpt'}
                  . $elements_ref->{'comboexp'};
                if (   $newthis =~ m/no\..*-/
                    && $newthis !~ m/-.*no\./ )
                {
                    $final =~
s/(v\.[0-9]{1,3}\/*[0-9]{0,3})(-v\.[0-9]{1,3}\/*[0-9]{0,3})(:no\.[0-9]{1,3}\/*[0-9]{0,3})/$1$3$2/g;
                }
            }
        }
    }
    else {
        if ( !$elements_ref->{'lastyearexp'} || $elements_ref->{'lastyearexp'} eq "" ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . ":"
              . $elements_ref->{'finalno'} . "-"
              . $elements_ref->{'firstnumexp'}
              . $elements_ref->{'finalpt'} . "("
              . $elements_ref->{'firstchron'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'firstyearexp'} . ")";
            if ( $newthis =~ m/no\..*-/ && $newthis !~ m/-.*no\./ )
            {
                $final =~
s/(v\.[0-9]{1,3}\/*[0-9]{0,3})(-v\.[0-9]{1,3}\/*[0-9]{0,3})(:no\.[0-9]{1,3}\/*[0-9]{0,3})/$1$3$2/g;
            }
        }
        else {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . ":"
              . $elements_ref->{'finalno'} . "-"
              . $elements_ref->{'firstnumexp'}
              . $elements_ref->{'finalpt'} . "("
              . $elements_ref->{'firstchron'} . " "
              . $elements_ref->{'firstyearexp'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'lastyearexp'} . ")";
            if ( $newthis =~ m/no\..*-/ && $newthis !~ m/-.*no\./ )
            {  
                # NPF: added optional hyphen at end of line; found $elements_ref->{'finalno'} of "no.3-"
                $final =~
s/(v\.[0-9]{1,3}\/*[0-9]{0,3})(-v\.[0-9]{1,3}\/*[0-9]{0,3})(:no\.[0-9]{1,3}\/*[0-9]{0,3})-?/$1$3$2/g; 
            }
            if ( $flags_ref->{'monthmatch'} ) {
                $final =
                    $elements_ref->{'finalser'} . " "
                  . $elements_ref->{'finalvol'} . ":"
                  . $elements_ref->{'finalno'} . "-"
                  . $elements_ref->{'firstnumexp'}
                  . $elements_ref->{'finalpt'}
                  . $elements_ref->{'comboexp'};
                if (   $newthis =~ m/no\..*-/
                    && $newthis !~ m/-.*no\./ )
                {
                    $final =~ s/(v\.[0-9]{1,3}\/*[0-9]{0,3})(-v\.[0-9]{1,3}\/*[0-9]{0,3})(:no\.[0-9]{1,3}\/*[0-9]{0,3})/$1$3$2/g;
                }
            }
        }
    }
    if (   $final =~ m/v\.[0-9]{1,3}\/*[0-9]{0,3}-v\./
        && $elements_ref->{'number_of_issues'} && $elements_ref->{'number_of_issues'} > 0 )
    {
        $final =~ s/:no\.$elements_ref->{'number_of_issues'}//;
    }

    return $final;
}

# ----------------------------------------------------------------------

sub _vol_num_onevol_no_onenum {

    trace_run('_vol_num_onevol_no_onenum');
    my $final;
    my ($elements_ref, $flags_ref, $newthis) = @_;
    my @finalno = split( /-/, $elements_ref->{'finalno'} );
    my $stringfirstno = $finalno[0];
    if ($stringfirstno eq "no.1"
        && $elements_ref->{'firstnumexp'} ne ""
        && $elements_ref->{'firstchron'} eq "Jan" )
    {
        $stringfirstno = "";
    }
    elsif ($stringfirstno eq "no.1"
        && $elements_ref->{'firstnumexp'} ne ""
        && $elements_ref->{'firstchron'} eq "" )
    {
        $stringfirstno = "";
    }
    my $stringsecondno = $finalno[1];
    if ( !$elements_ref->{'lastyearexp'} || $elements_ref->{'lastyearexp'} eq "" ) {
        $final =
            $elements_ref->{'finalser'} . " "
          . $elements_ref->{'finalvol'} . ":"
          . $stringfirstno . "-v."
          . $elements_ref->{'firstnumexp'} . ":no."
          . $stringsecondno
          . $elements_ref->{'finalpt'} . "("
          . $elements_ref->{'firstchron'} . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'firstyearexp'} . ")";
        if ( $elements_ref->{'finalvol'} =~ m/v\.$elements_ref->{'firstnumexp'}/ ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . ":"
              . $stringfirstno . "-"
              . $stringsecondno
              . $elements_ref->{'finalpt'} . "("
              . $elements_ref->{'firstchron'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'firstyearexp'} . ")";
        }
        if ( $flags_ref->{'monthmatch'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . ":"
              . $stringfirstno . "-v."
              . $elements_ref->{'firstnumexp'} . ":no."
              . $stringsecondno
              . $elements_ref->{'finalpt'}
              . $elements_ref->{'comboexp'};
            if ( $elements_ref->{'finalvol'} =~ m/v\.$elements_ref->{'firstnumexp'}/ ) {
                $final =
                    $elements_ref->{'finalser'} . " "
                  . $elements_ref->{'finalvol'} . ":"
                  . $stringfirstno . "-"
                  . $stringsecondno
                  . $elements_ref->{'finalpt'}
                  . $elements_ref->{'comboexp'};
            }
        }
    }
    else {
        $final =
            $elements_ref->{'finalser'} . " "
          . $elements_ref->{'finalvol'} . ":"
          . $stringfirstno . "-v."
          . $elements_ref->{'firstnumexp'} . ":no."
          . $stringsecondno
          . $elements_ref->{'finalpt'} . "("
          . $elements_ref->{'firstchron'} . " "
          . $elements_ref->{'firstyearexp'} . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'lastyearexp'} . ")";
        if ( $elements_ref->{'finalvol'} =~ m/v\.$elements_ref->{'firstnumexp'}/ ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . ":"
              . $stringfirstno . "-"
              . $stringsecondno
              . $elements_ref->{'finalpt'} . "("
              . $elements_ref->{'firstchron'} . " "
              . $elements_ref->{'firstyearexp'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'lastyearexp'} . ")";
        }
        if ( $flags_ref->{'monthmatch'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . ":"
              . $stringfirstno . "-v."
              . $elements_ref->{'firstnumexp'} . ":no."
              . $stringsecondno
              . $elements_ref->{'finalpt'}
              . $elements_ref->{'comboexp'};
            if ( $elements_ref->{'finalvol'} =~ m/v\.$elements_ref->{'firstnumexp'}/ ) {
                $final =
                    $elements_ref->{'finalser'} . " "
                  . $elements_ref->{'finalvol'} . ":"
                  . $stringfirstno . "-"
                  . $stringsecondno
                  . $elements_ref->{'finalpt'}
                  . $elements_ref->{'comboexp'};
            }
        }
    }
    if ( $elements_ref->{'firstnumexp'} eq "" ) {
        $final =~ s/-v\.:no\./-/g;
    }
    if ( $elements_ref->{'number_of_issues'} && $elements_ref->{'number_of_issues'} > 0 ) {
        $final =~
          s/:no\.1\/*[0-9]{0,3}-*[0-9]{0,3}\/*$elements_ref->{'number_of_issues'}//;
    }
    return $final;
}


# ----------------------------------------------------------------------

sub _vol_num_no_onevol_no_onenum {

    trace_run('_vol_num_no_onevol_no_onenum');
    my $final;
    my ($elements_ref, $flags_ref, $newthis) = @_;
    my @finalno = split( /-/, $elements_ref->{'finalno'} );
    my $stringfirstno = $finalno[0];
    if ( $stringfirstno eq "no.1" && $elements_ref->{'firstchron'} eq "Jan" ) {
        $stringfirstno = "";
    }
    elsif ( $stringfirstno eq "no.1" && $elements_ref->{'firstchron'} eq "" ) {
        $stringfirstno = "";
    }
    my $stringsecondno = $finalno[1];
    $stringsecondno = "no." . $stringsecondno;
    my @finalvol        = split( /-/, $elements_ref->{'finalvol'} );
    my $stringfirstvol = $finalvol[0];
    my $stringsecondvol = $finalvol[1];
    if ( !$elements_ref->{'lastyearexp'} || $elements_ref->{'lastyearexp'} eq "" ) {
        $final =
            $elements_ref->{'finalser'} . " "
          . $stringfirstvol . ":"
          . $stringfirstno . "-"
          . $stringsecondvol . ":"
          . $stringsecondno . ":"
          . $elements_ref->{'finalpt'} . "("
          . $elements_ref->{'firstchron'} . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'firstyearexp'} . ")";
        if ( $flags_ref->{'monthmatch'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $stringfirstvol . ":"
              . $stringfirstno . "-"
              . $stringsecondvol . ":"
              . $stringsecondno . ":"
              . $elements_ref->{'finalpt'}
              . $elements_ref->{'comboexp'};
        }
        ## new associates year with appropriate volume
        if ( $newthis =~ m/\)-/ && $newthis !~ m/\)($| )/ ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $stringfirstvol . ":"
              . $stringfirstno . " ("
              . $elements_ref->{'firstchron'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'firstyearexp'} . ")" . "-"
              . $stringsecondvol . ":"
              . $stringsecondno . ":"
              . $elements_ref->{'finalpt'};
            if ( $flags_ref->{'monthmatch'} ) {
                $final =
                    $elements_ref->{'finalser'} . " "
                  . $stringfirstvol . ":"
                  . $stringfirstno
                  . $elements_ref->{'comboexp'} . "-"
                  . $stringsecondvol . ":"
                  . $stringsecondno . ":"
                  . $elements_ref->{'finalpt'};
            }
        }
    }
    else {
        $final =
            $elements_ref->{'finalser'} . " "
          . $stringfirstvol . ":"
          . $stringfirstno . "-"
          . $stringsecondvol . ":"
          . $stringsecondno . ":"
          . $elements_ref->{'finalpt'} . "("
          . $elements_ref->{'firstchron'} . " "
          . $elements_ref->{'firstyearexp'} . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'lastyearexp'} . ")";
        if ( $flags_ref->{'monthmatch'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $stringfirstvol . ":"
              . $stringfirstno . "-"
              . $stringsecondvol . ":"
              . $stringsecondno . ":"
              . $elements_ref->{'finalpt'}
              . $elements_ref->{'comboexp'};
        }
    }
    $final =~ s/:\(/ \(/g;
    $final =~ s/:-/-/g;
    return $final;
}

# ----------------------------------------------------------------------

sub _vol_num_onevol_onenum {

    trace_run('_vol_num_onevol_onenum');
    my $final;
    my ($elements_ref, $flags_ref, $newthis) = @_;    
    if ( !$elements_ref->{'lastyearexp'} || $elements_ref->{'lastyearexp'} eq "" ) {
        $final =
            $elements_ref->{'finalser'} . " "
          . $elements_ref->{'finalvol'} . "-v."
          . $elements_ref->{'firstnumexp'} . ":"
          . $elements_ref->{'finalno'} . ":"
          . $elements_ref->{'finalpt'} . "("
          . $elements_ref->{'firstchron'} . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'firstyearexp'} . ")";
        if ( $flags_ref->{'monthmatch'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . "-v."
              . $elements_ref->{'firstnumexp'} . ":"
              . $elements_ref->{'finalno'} . ":"
              . $elements_ref->{'finalpt'}
              . $elements_ref->{'comboexp'};
        }
        ## new associates year with appropriate volume
        if ( $newthis =~ m/\)-/ && $newthis !~ m/\)($| )/ ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . " ("
              . $elements_ref->{'firstchron'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'firstyearexp'} . ")" . "-v."
              . $elements_ref->{'firstnumexp'} . ":"
              . $elements_ref->{'finalno'} . ":"
              . $elements_ref->{'finalpt'};
            if ( $flags_ref->{'monthmatch'} ) {
                $final =
                    $elements_ref->{'finalser'} . " "
                  . $elements_ref->{'finalvol'}
                  . $elements_ref->{'comboexp'} . "-v."
                  . $elements_ref->{'firstnumexp'} . ":"
                  . $elements_ref->{'finalno'} . ":"
                  . $elements_ref->{'finalpt'};
            }
        }
        if ( $newthis =~ m/no\..*-/ && $newthis !~ m/-.*no\./ ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . ":"
              . $elements_ref->{'finalno'} . "-v."
              . $elements_ref->{'firstnumexp'} . ":"
              . $elements_ref->{'finalpt'} . "("
              . $elements_ref->{'firstchron'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'firstyearexp'} . ")";
            if ( $flags_ref->{'monthmatch'} ) {
                $final =
                    $elements_ref->{'finalser'} . " "
                  . $elements_ref->{'finalvol'} . ":"
                  . $elements_ref->{'finalno'} . "-v."
                  . $elements_ref->{'firstnumexp'}
                  . $elements_ref->{'finalpt'}
                  . $elements_ref->{'comboexp'};
            }
            if ( $newthis =~ m/\)-/ && $newthis !~ m/\)($| )/ ) {
                $final =
                    $elements_ref->{'finalser'} . " "
                  . $elements_ref->{'finalvol'} . ":"
                  . $elements_ref->{'finalno'} . " ("
                  . $elements_ref->{'firstchron'} . "-"
                  . $elements_ref->{'lastchron'} . " "
                  . $elements_ref->{'firstyearexp'} . ")" . "-v."
                  . $elements_ref->{'firstnumexp'} . ":"
                  . $elements_ref->{'finalpt'};
                if ( $flags_ref->{'monthmatch'} ) {
                    $final =
                        $elements_ref->{'finalser'} . " "
                      . $elements_ref->{'finalvol'} . ":"
                      . $elements_ref->{'finalno'}
                      . $elements_ref->{'comboexp'} . "-v."
                      . $elements_ref->{'firstnumexp'};
                }
            }
        }
    }
    else { 
        $final =
            $elements_ref->{'finalser'} . " "
          . $elements_ref->{'finalvol'} . "-v."
          . $elements_ref->{'firstnumexp'} . ":"
          . $elements_ref->{'finalno'} . ":"
          . $elements_ref->{'finalpt'} . "("
          . $elements_ref->{'firstchron'} . " "
          . $elements_ref->{'firstyearexp'} . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'lastyearexp'} . ")";
        if ( $newthis =~ m/no\..*-/ && $newthis !~ m/-.*no\./ ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . ":"
              . $elements_ref->{'finalno'} . "-v."
              . $elements_ref->{'firstnumexp'} . ":"
              . $elements_ref->{'finalpt'} . "("
              . $elements_ref->{'firstchron'} . " "
              . $elements_ref->{'firstyearexp'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'lastyearexp'} . ")";
            $final =~ s/:no\.1-/-/g;
        }
        if ( $flags_ref->{'monthmatch'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . "-v."
              . $elements_ref->{'firstnumexp'} . ":"
              . $elements_ref->{'finalno'} . ":"
              . $elements_ref->{'finalpt'}
              . $elements_ref->{'comboexp'};
            if ( $newthis =~ m/no\..*-/ && $newthis !~ m/-.*no\./ )
            {
                $final =
                    $elements_ref->{'finalser'} . " "
                  . $elements_ref->{'finalvol'} . ":"
                  . $elements_ref->{'finalno'} . "-v."
                  . $elements_ref->{'firstnumexp'} . ":"
                  . $elements_ref->{'finalpt'}
                  . $elements_ref->{'comboexp'};
                $final =~ s/:no\.1-/-/g;
            }
        }
    }
    return $final;
}

# ----------------------------------------------------------------------

sub _no_vol_num_onenum {

    trace_run('_no_vol_num_onenum');
    my $final;
    my ($elements_ref, $flags_ref, $newthis) = @_;
    if ( $elements_ref->{'subno'} == $elements_ref->{'firstnumexp'} ) {
        if ( !$elements_ref->{'lastyearexp'} || $elements_ref->{'lastyearexp'} eq "" ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'firstchron'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'firstyearexp'} . ":"
              . $elements_ref->{'finalno'} . ":"
              . $elements_ref->{'finalpt'};
            my $justno = substr( $elements_ref->{'finalno'}, 3 );
            if ( $justno > $elements_ref->{'number_of_issues'} ) {
                $final =
                    $elements_ref->{'finalser'} . " "
                  . $elements_ref->{'finalno'} . ":"
                  . $elements_ref->{'finalpt'} . "("
                  . $elements_ref->{'firstchron'} . "-"
                  . $elements_ref->{'lastchron'} . " "
                  . $elements_ref->{'firstyearexp'} . ")";
            }
        }
        else {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'firstchron'} . " "
              . $elements_ref->{'firstyearexp'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'lastyearexp'} . ":"
              . $elements_ref->{'finalno'} . ":"
              . $elements_ref->{'finalpt'};
            my $justno = substr( $elements_ref->{'finalno'}, 3 );
            if ( $justno > $elements_ref->{'number_of_issues'} ) {
                $final =
                    $elements_ref->{'finalser'} . " "
                  . $elements_ref->{'finalno'} . ":"
                  . $elements_ref->{'finalpt'} . "("
                  . $elements_ref->{'firstchron'} . " "
                  . $elements_ref->{'firstyearexp'} . "-"
                  . $elements_ref->{'lastchron'} . " "
                  . $elements_ref->{'lastyearexp'} . ")";
            }
        }
    }
    else {
        my ($numbcheck);
        if ( !$elements_ref->{'lastyearexp'} || $elements_ref->{'lastyearexp'} eq "" ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'firstchron'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'firstyearexp'} . ":"
              . $elements_ref->{'finalno'} . "-"
              . $elements_ref->{'firstnumexp'} . ":"
              . $elements_ref->{'finalpt'};
            if ( $elements_ref->{'firstnumexp'} =~ m/\// ) {
                my @firstnumsplit = split( /\//, $elements_ref->{'firstnumexp'} );
                $numbcheck = $firstnumsplit[1];
            }
            else {
                $numbcheck = $elements_ref->{'firstnumexp'};
            }
            if ( $numbcheck == $elements_ref->{'number_of_issues'} ) {
                $final =
                    $elements_ref->{'finalser'}
                  . $elements_ref->{'finalpt'} . " ("
                  . $elements_ref->{'firstchron'} . "-"
                  . $elements_ref->{'lastchron'} . " "
                  . $elements_ref->{'firstyearexp'} . ")";
            }
            if ( $numbcheck > $elements_ref->{'number_of_issues'} ) {
                $final =
                    $elements_ref->{'finalser'}
                  . $elements_ref->{'finalno'} . "-no."
                  . $elements_ref->{'firstnumexp'} . ":"
                  . $elements_ref->{'finalpt'} . " ("
                  . $elements_ref->{'firstchron'} . "-"
                  . $elements_ref->{'lastchron'} . " "
                  . $elements_ref->{'firstyearexp'} . ")";
                if ( $newthis =~ m/\)-/ && $newthis !~ m/\)($| )/ )
                {
                    $final =
                        $elements_ref->{'finalser'}
                      . $elements_ref->{'finalno'} . " ("
                      . $elements_ref->{'firstchron'} . "-"
                      . $elements_ref->{'lastchron'} . " "
                      . $elements_ref->{'firstyearexp'} . ") " . "-no."
                      . $elements_ref->{'firstnumexp'} . ":"
                      . $elements_ref->{'finalpt'};
                }
                if ( $flags_ref->{'monthmatch'} ) {
                    $final =
                        $elements_ref->{'finalser'}
                      . $elements_ref->{'finalno'} . "-no."
                      . $elements_ref->{'firstnumexp'} . ":"
                      . $elements_ref->{'finalpt'}
                      . $elements_ref->{'comboexp'};
                    if (   $newthis =~ m/\)-/
                        && $newthis !~ m/\)($| )/ )
                    {
                        $final =
                            $elements_ref->{'finalser'}
                          . $elements_ref->{'finalno'}
                          . $elements_ref->{'comboexp'} . "-no."
                          . $elements_ref->{'firstnumexp'} . ":"
                          . $elements_ref->{'finalpt'};
                    }
                }
            }
        }
        else {
            my ($numbcheck);
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'firstchron'} . " "
              . $elements_ref->{'firstyearexp'} . ":"
              . $elements_ref->{'finalno'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'lastyearexp'} . ":no."
              . $elements_ref->{'firstnumexp'}
              . $elements_ref->{'finalpt'};
            if ( $elements_ref->{'firstnumexp'} =~ m/\// ) {
                my @firstnumsplit = split( /\//, $elements_ref->{'firstnumexp'} );
                $numbcheck = $firstnumsplit[1];
            }
            else {
                $numbcheck = $elements_ref->{'firstnumexp'};
            }
            if ( $numbcheck == $elements_ref->{'number_of_issues'} ) {
                $final =
                    $elements_ref->{'finalser'}
                  . $elements_ref->{'finalpt'} . " ("
                  . $elements_ref->{'firstchron'} . " "
                  . $elements_ref->{'firstyearexp'} . "-"
                  . $elements_ref->{'lastchron'} . " "
                  . $elements_ref->{'lastyearexp'} . ")";
            }
            if ( $numbcheck > $elements_ref->{'number_of_issues'} ) {
                $final =
                    $elements_ref->{'finalser'}
                  . $elements_ref->{'finalno'} . "-no."
                  . $elements_ref->{'firstnumexp'} . ":"
                  . $elements_ref->{'finalpt'} . " ("
                  . $elements_ref->{'firstchron'} . " "
                  . $elements_ref->{'firstyearexp'} . "-"
                  . $elements_ref->{'lastchron'} . " "
                  . $elements_ref->{'lastyearexp'} . ")";
                if ( $newthis =~ m/\)-/ && $newthis !~ m/\)($| )/ )
                {
                    $final =
                        $elements_ref->{'finalser'}
                      . $elements_ref->{'finalno'} . " ("
                      . $elements_ref->{'firstchron'} . " "
                      . $elements_ref->{'firstyearexp'} . "-"
                      . $elements_ref->{'lastchron'} . " "
                      . $elements_ref->{'lastyearexp'} . ")" . "-no."
                      . $elements_ref->{'firstnumexp'} . ":"
                      . $elements_ref->{'finalpt'};
                }
                if ( $flags_ref->{'monthmatch'} ) {
                    $final =
                        $elements_ref->{'finalser'}
                      . $elements_ref->{'finalno'} . "-no."
                      . $elements_ref->{'firstnumexp'} . ":"
                      . $elements_ref->{'finalpt'}
                      . $elements_ref->{'comboexp'};
                    if (   $newthis =~ m/\)-/
                        && $newthis !~ m/\)($| )/ )
                    {
                        $final =
                            $elements_ref->{'finalser'}
                          . $elements_ref->{'finalno'}
                          . $elements_ref->{'comboexp'} . "-no."
                          . $elements_ref->{'firstnumexp'} . ":"
                          . $elements_ref->{'finalpt'};
                    }
                }
            }
        }
        if ( $elements_ref->{'firstnumexp'} eq "" ) {
            chop($final);
        }
    }
    return $final;
}

# ----------------------------------------------------------------------

sub _no_vol_num_no_onenum {

    trace_run('_no_vol_num_no_onenum');
    my $final;
    my ($elements_ref, $flags_ref, $newthis) = @_;
    $elements_ref->{'finalno'} =~ s/-$//g;
    if ( !$elements_ref->{'lastyearexp'} || $elements_ref->{'lastyearexp'} eq "" ) {
        my @finalno = split( /-/, $elements_ref->{'finalno'} );
        $final =
            $elements_ref->{'finalser'} . " "
          . $elements_ref->{'firstchron'} . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'firstyearexp'} . ":"
          . $elements_ref->{'finalno'}
          . $elements_ref->{'finalpt'};
        if ( $finalno[1] > $elements_ref->{'number_of_issues'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $finalno[0] . "-no."
              . $finalno[1]
              . $elements_ref->{'finalpt'} . "("
              . $elements_ref->{'firstchron'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'firstyearexp'} . ")";
            if ( $flags_ref->{'monthmatch'} ) {
                $final =
                    $elements_ref->{'finalser'} . " "
                  . $finalno[0] . "-no."
                  . $finalno[1]
                  . $elements_ref->{'finalpt'}
                  . $elements_ref->{'comboexp'};
            }
        }
    }
    else {
        my @finalno = split( /-/, $elements_ref->{'finalno'} );
        $final =
            $elements_ref->{'finalser'} . " "
          . $elements_ref->{'firstchron'} . " "
          . $elements_ref->{'firstyearexp'} . ":"
          . $finalno[0] . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'lastyearexp'} . ":no."
          . $finalno[1]
          . $elements_ref->{'finalpt'};
        if ( $finalno[1] > $elements_ref->{'number_of_issues'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $finalno[0] . "-no."
              . $finalno[1] . "("
              . $elements_ref->{'firstchron'} . " "
              . $elements_ref->{'firstyearexp'} . "-"
              . $elements_ref->{'lastchron'} . " "
              . $elements_ref->{'lastyearexp'} . ")"
              . $elements_ref->{'finalpt'};
            if ( $flags_ref->{'monthmatch'} ) {
                $final =
                    $elements_ref->{'finalser'} . " "
                  . $finalno[0] . "-no."
                  . $finalno[1]
                  . $elements_ref->{'finalpt'}
                  . $elements_ref->{'comboexp'};
            }
        }
    }
    return $final;
}

# ----------------------------------------------------------------------

sub _other_expressions {

    trace_run('_other_expressions');
    my $final;
    my ($elements_ref, $flags_ref, $newthis) = @_;
    if ( !$elements_ref->{'lastyearexp'} || $elements_ref->{'lastyearexp'} eq "" ) {
        $final =
            $elements_ref->{'finalser'} . " "
          . $elements_ref->{'finalvol'} . ":"
          . $elements_ref->{'finalno'} . ":"
          . $elements_ref->{'finalpt'} . "("
          . $elements_ref->{'firstchron'} . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'firstyearexp'} . ")";
        if ( $flags_ref->{'monthmatch'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . ":"
              . $elements_ref->{'finalno'} . ":"
              . $elements_ref->{'finalpt'}
              . $elements_ref->{'comboexp'};
        }
    }
    else {
        $final =
            $elements_ref->{'finalser'} . " "
          . $elements_ref->{'finalvol'} . ":"
          . $elements_ref->{'finalno'} . ":"
          . $elements_ref->{'finalpt'} . "("
          . $elements_ref->{'firstchron'} . " "
          . $elements_ref->{'firstyearexp'} . "-"
          . $elements_ref->{'lastchron'} . " "
          . $elements_ref->{'lastyearexp'} . ")";
        if ( $flags_ref->{'monthmatch'} ) {
            $final =
                $elements_ref->{'finalser'} . " "
              . $elements_ref->{'finalvol'} . ":"
              . $elements_ref->{'finalno'} . ":"
              . $elements_ref->{'finalpt'}
              . $elements_ref->{'comboexp'};
        }
    }
    return $final;
}


# NPF: to try to deal with things like v.1, v.3, v.5 (or no.1, no.3, v.5)
sub _check_vol_or_num_only {
    my $string = shift;
    my @check_parts = split(', ', $string);
    my $last_num = 0;
    my $vol_num = qr/v\.|no\./;
    foreach my $p (@check_parts) {
        if ($p =~ /^$vol_num(\d+)(?:-$vol_num?(\d+))?$/) {
            return if $1 <= $last_num;
            if ($2) {
                return if $2 <= $1;
                $last_num = $2;
            }
            else {
                $last_num = $1;
            }
        }
        else {
            return;
        }
    }
    return 1;
}

# ----------------------------------------------------------------------


1;
