package Normalizer::normalize_match_expressions;

use strict;
use warnings;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        match_any_numerical_expression
        match_no_expressions
        match_pt_expressions
        match_series_expression
        match_vol_expressions
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

sub match_series_expression {   
    ## Match the series expression and store it in a variable for later use
    my ($string, $elements_ref, $flags_ref) = @_;
    trace_run('match_series_expression in', $string);

    my @serexp = ( $string =~ m/ser\.[0-9]{1,3}-*[0-9]{0,3}|ser\.[A-Z]+/g );
    
    if ( @serexp && scalar @serexp >= 1 ) {
        $flags_ref->{'ser'}     = 1;
        my $firstserexp = $serexp[0];
        my $sersize     = scalar @serexp;
        if ( $sersize == 2 ) {
            my $secondserexp = $serexp[1];
            $secondserexp = substr( $secondserexp, 4 );
            my $subser       = substr( $firstserexp, 4 );
            if ( $subser eq $secondserexp ) {
                $elements_ref->{'finalser'} = $firstserexp;
            }
            else {
                $elements_ref->{'finalser'} = $firstserexp . "-ser." . $secondserexp;
            }
        }
        if ( $serexp[0] =~ m/(ser\.[0-9]{1,3})-([0-9]{1,3})/g ) {
            $elements_ref->{'finalser'} = $1 . "-ser." . $2;
            $sersize  = 2;
        }
        elsif ( $sersize == 1 ) {
            $flags_ref->{'oneser'}   = 1;
            $elements_ref->{'finalser'}   = $firstserexp;
        }
    }
    else {
        $elements_ref->{'finalser'} = "";
    }
    $string =~ s/ser\.[0-9]{1,3}-*[0-9]{0,3}|ser\.[A-Z]+/ /g;
    
    trace_run('match_series_expression out', $elements_ref);
    return $string;
    
}


# ----------------------------------------------------------------------


sub match_vol_expressions { 
    ## Match the volume expression and store it in a variable for later use
    my ($string, $elements_ref, $flags_ref) = @_;
    trace_run('match_vol_expressions in', $string);

    my ($first_vol_exp, $first_vol_expnumb, $secondvolexpnumb, $secondvolexp);

    my @volexp = ( $string =~ m/v\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3}|v\.[A-Z]+/g );
    if ($volexp[0]) {
        $first_vol_exp      = $volexp[0];
        $first_vol_expnumb  = substr( $first_vol_exp, 2 );
        $first_vol_expnumb =~ s/-//;
    }
    if ($volexp[1]) {
        $secondvolexp     = $volexp[1];
        $secondvolexpnumb = substr( $secondvolexp, 2 );
    }
    
    if ( $secondvolexpnumb ) {
        if ( $first_vol_expnumb && $first_vol_expnumb =~ /^\d+$/ &&
             $secondvolexpnumb =~ /\d/ &&
             $first_vol_expnumb > $secondvolexpnumb ) {
            $volexp[1] = $first_vol_exp;
            $volexp[0] = $secondvolexp;
        }
    }
    if ( @volexp && scalar @volexp >= 1 ) {
        $flags_ref->{'vol'}     = 1;
        $first_vol_exp = $volexp[0];
        my $volsize    = scalar @volexp;
        if ( $volsize == 2 ) {
            $secondvolexp = $volexp[1];
            $secondvolexp = substr( $secondvolexp, 2 );
            my $subvol       = substr( $first_vol_exp, 2 );
            if ( $subvol eq $secondvolexp ) {
                $elements_ref->{'finalvol'}   = $first_vol_exp;
                $flags_ref->{'onevol'} = 1;
            }
            else {
                $elements_ref->{'finalvol'} = $first_vol_exp . "-v." . $secondvolexp;
            }
        }
        if ( $volexp[0] =~
            m/(v\.[0-9]{1,3}\/*[0-9]{0,3})-([0-9]{1,3}\/*[0-9]{0,3})/g )
        {
            $elements_ref->{'finalvol'} = $1 . "-v." . $2;
            $volsize  = 2;
        }
        elsif ( $volsize == 1 ) {
            $flags_ref->{'onevol'} = 1;
            $elements_ref->{'finalvol'}   = $first_vol_exp;
        }
    }
    $string =~ s/(v\.[0-9]{1,3}\/*[0-9]{0,3})-*[0-9]{0,3}\/*[0-9]{0,3}/ /g;
    $string =~ s/ - /-/g;
    
    trace_run('match_vol_expressions out', $elements_ref);
    
    return $string;    
}


# ----------------------------------------------------------------------


sub match_no_expressions {
    ## Match any no. expression and store it in a variable for later use

    my ($string, $elements_ref, $flags_ref) = @_;
    trace_run('match_no_expressions in', $string);

    $flags_ref->{'chron'} = 0;
    my @noexp = ( $string =~ m/no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3}[A-Z]{0,1}/g );
    if ( @noexp && scalar @noexp >= 1 ) {
        use Data::Dumper;
        $flags_ref->{'no'}     = 1;
        my $firstnoexp = $noexp[0];
        my $nosize     = scalar @noexp;
        # TODO: the following sets $nosize to two, but usually without second element in @nosize
        # TODO: this leads to failed $secondnoexp and $elements_ref->{'subno'} variables
        if ( $string =~ m/no\.[0-9]{1,3}\/*[0-9]{0,3}-[0-9]{1,3}\/*[0-9]{0,3}/g ) {
            $nosize = 2;
        }
        if ( $nosize >= 2 ) {
            my $secondnoexp = $noexp[1];
            $secondnoexp = substr( $secondnoexp, 3 );
            $elements_ref->{'subno'}       = substr( $firstnoexp, 3 );
            # Nate added:
            # if the number is greater than the supposed number of issues, we need to throw out the number of issues, as it's wrong.
            if ( $elements_ref->{'subno'} && $elements_ref->{'number_of_issues'} && $elements_ref->{'subno'} > $elements_ref->{'number_of_issues'} ) {
                $elements_ref->{'number_of_issues'} = "";
            }

            if (   $elements_ref->{'subno'} eq '1'
                && $secondnoexp =~ m/^[0-9]{0,3}\/*$elements_ref->{'number_of_issues'}/
                && $elements_ref->{'number_of_issues'} ne "" )
            {  
                $elements_ref->{'finalno'}   = "";
                $flags_ref->{'chron'} = 1;
                $flags_ref->{'no'}    = 0;
            }
            elsif ($elements_ref->{'subno'} =~ m/^1-$elements_ref->{'number_of_issues'}/
                && $elements_ref->{'number_of_issues'} ne ""
                || $elements_ref->{'subno'} =~
                m/^1\/[0-9]{1,3}-[0-9]{1,3}\/$elements_ref->{'number_of_issues'}/
                && $elements_ref->{'number_of_issues'} ne "" )
            {
                $elements_ref->{'finalno'}   = "";
                $flags_ref->{'chron'} = 1;
                $flags_ref->{'no'}    = 0;
            }
            else {
                if ($secondnoexp) {
                    $elements_ref->{'finalno'} = $firstnoexp . "-" . $secondnoexp;
                }
                if ( $firstnoexp =~ m/-/ ) {
                    if ( !$secondnoexp || $secondnoexp eq "" ) {
                        $elements_ref->{'finalno'} = $firstnoexp;
                    }
                    else {
                        my @splitfirstno = split( /-/, $firstnoexp );
                        $elements_ref->{'finalno'} =
                          $splitfirstno[0] . "-" . $secondnoexp;
                        if ( $secondnoexp =~ m/-/ ) {
                            my @splitsecondno = split( /-/, $secondnoexp );
                            $elements_ref->{'finalno'} = $splitfirstno[0] . "-"
                              . $splitsecondno[1];
                        }
                    }
                }
            }
        }
        elsif ( $nosize == 1 ) {
            $flags_ref->{'oneno'} = 1;
            $elements_ref->{'finalno'}   = $firstnoexp;
        }
    }
    else {
        $elements_ref->{'finalno'} = "";
    }
    $elements_ref->{'finalno'} =~ s/--/-/;
    $string =~ s/no\.[0-9]{1,3}\/*[0-9]{0,3}-*\/*[0-9]{0,3}\/*[0-9]{0,3}[A-Z]{0,1}/ /g;
    trace_run('match_no_expressions out', $elements_ref);
    return $string;
}


# ----------------------------------------------------------------------


sub match_pt_expressions {
    

    ## Match any pt. expression and store it in a variable for later use
    my ($string, $elements_ref, $flags_ref) = @_;
    trace_run('match_pt_expressions in', $string);
    
    my @ptexp = ( $string =~ m/pt\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3}/g );
    if ( @ptexp && scalar @ptexp >= 1 ) {
        $flags_ref->{'pt'}     = 1;
        my $firstptexp = $ptexp[0];
        my $ptsize     = @ptexp;
        if ( $ptsize == 2 ) {
            my $secondptexp = $ptexp[1];
            $secondptexp = substr( $secondptexp, 3 );
            my $subpt       = substr( $firstptexp, 3 );
            if ( $subpt eq $secondptexp ) {
                $elements_ref->{'finalpt'} = " " . $firstptexp;
            }
            else {
                $elements_ref->{'finalpt'} = " " . $firstptexp . "-" . $secondptexp;
            }
        }
        elsif ( $ptsize == 1 ) {
            $flags_ref->{'onept'} = 1;
            $elements_ref->{'finalpt'}   = " " . $firstptexp;
        }
    }
    else {
        $elements_ref->{'finalpt'} = "";
    }
    ## eliminate pt. elements from $string string
    $string =~ s/pt\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3}/ /g;
    trace_run('match_pt_expressions out', $elements_ref);
    return $string;
}


# ----------------------------------------------------------------------


sub match_any_numerical_expression {
    ## Match any number expression and store it in a variable for later use
    # flags ref not actually used here
    my ($string, $elements_ref, $flags_ref) = @_;
    trace_run('match_any_numerical_expression in', $string);
       
    $elements_ref->{'firstnumexp'} = "";
    my @numexp = ( $string =~ m/( [0-9]{1,3}\/[0-9]{1,3} |-[0-9]{1,3}\/[0-9]{1,3} | [0-9]{1,3}\/[0-9]{1,3}$|-[0-9]{1,3}\/[0-9]{1,3}$| [0-9]{1,3} |-[0-9]{1,3} | [0-9]{1,3}$|-[0-9]{1,3}$)/g );
    my $numsize      = scalar @numexp;
    if ($numsize >= 1) {
        $elements_ref->{'firstnumexp'} = $numexp[0];
        $elements_ref->{'firstnumexp'} = substr( $elements_ref->{'firstnumexp'}, 1 );
        $elements_ref->{'firstnumexp'} =~ s/ $//g;
    }
    if ($numsize > 1) {
        $elements_ref->{'secondnumexp'} = $numexp[1];
        $elements_ref->{'secondnumexp'} = substr( $elements_ref->{'secondnumexp'}, 1 );
        $elements_ref->{'secondnumexp'} =~ s/ $//g;
        ## get rid of the last number if it matches the first
        if ( $elements_ref->{'firstnumexp'} eq $elements_ref->{'secondnumexp'} ) {
            $elements_ref->{'secondnumexp'} = "";
        }
    }
    $string =~ s/(-| )[0-9]{1,3}(\/[0-9]{1,3})*\s/ /g;
    $string =~ s/\$z.+//g;
    $string =~
s/( [0-9]{1,3}\/[0-9]{1,3} |-[0-9]{1,3}\/[0-9]{1,3} | [0-9]{1,3}\/[0-9]{1,3}$|-[0-9]{1,3}\/[0-9]{1,3}$| [0-9]{1,3} |-[0-9]{1,3} | [0-9]{1,3}$|-[0-9]{1,3}$)/ /;
    trace_run('match_any_numerical_expression out', $elements_ref);
    return $string;
}

# ----------------------------------------------------------------------

1;
