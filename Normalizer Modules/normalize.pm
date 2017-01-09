package Normalizer::normalize;

use strict;
use warnings;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        normalize
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

use Normalizer::tests qw(:all);

use Normalizer::normalize_transforms qw(:all);
use Normalizer::normalize_flags qw(:all);
use Normalizer::normalize_subnormalize qw(:all);
use Normalizer::normalize_match_expressions qw(:all);
use Normalizer::normalize_chronology_expressions qw(:all);
use Normalizer::normalize_build_final_expression qw(:all);
use Normalizer::normalize_months qw(:all);

sub normalize {
    trace_initialize();

    # print out start/end string or no
    my $suppress_reports = 0;
    #$suppress_reports = 1;

    my (
        @final, @normalarray
    );
    
    my %flags;

    # Concatenated holdings string is $that
    # Frequency information. Number of issues per year.
    my ( $that, $number_of_issues ) = @_;
    trace_run('normalize start', $that);

    # For keeping track of changes, if desired
    my $original = $that;
    
    say "\nORIGINAL:\n" . $original if !$suppress_reports;

    $that = first_transform($that);
    # Split into array on semicolons (most likely spot for breaks in holdings).
    @normalarray = split( /;/, $that );
    ## entries with only numbers (that are not periodic) and no volumes should have the numbers treated like volumes
    $flags{'switch'} = set_switch_flag($that, $number_of_issues);
    
    ## loop through all the different expressions on the same line
    # MOST OF THE REST OF THE SCRIPT IS A HUGE LOOP THAT STARTS HERE
    for ( my $i = 0 ; $i < @normalarray ; $i++ ) {
        
        my ($newthis, $final);
        
        my %elements;
        $elements{'number_of_issues'} = $number_of_issues;
        ## set this and eliminate any unecessary syntax
        my $this = $normalarray[$i];
        trace_run('NEW PART', 'HR');
        trace_run('NEW PART', $this);
        $flags{'continued'} = set_continued_flag($this);
        # v.A21 to v.21A, to get it through the normalizer
        ($this) = set_letter_before_number_flag($this, \%flags);
        
        trace_run('post continued flag', \%flags);

        ## for($c=0; $c<50000000; $c++)    {
        ## }
        $flags{'copy'} = set_copy_flag($this);
        $this= set_not_publ_flag($this, \%flags);
        
        if ( $flags{'switch'} ) {
            $this = switch_transform($this);
        }

        ## new keeps track of new series expressions
        # TODO: Expand on new series work!
        $this = set_ns_flag($this, \%flags);
        trace_run('post ns flag', \%flags);
        
        $this = months_seasons_transform($this);        
        $this = second_transform($this, $that);
        $this = dates_transform($this);
        $this = roman_transform($this);
        
    ## if the holding record starts with a three digit number and none of the neighboring expressions have numbers, then make that expression a volume expression
        if ( $that !~ m/n|N|Heft/ ) {
            if ( $this !~ m/^\s*([0-9]{4})/ ) {
                $this =~ s/^\s*([0-9]{1,3})/v\.$1/g;
            }
        }

        $newthis = $this;
        
        my ($normalizing_completed);
        ($final, $normalizing_completed) = normalize_subnormalize($this, \%elements, \%flags);
        
        if ($normalizing_completed) {
            # normalization of basic holdings types succeeded
            # pass
        }
        # Sort of general cleanup.
        else {
            ## set all flags to zero
            $flags{'vol'}    = 0;
            $flags{'no'}     = 0;
            $flags{'pt'}     = 0;
            $flags{'oneno'}  = 0;
            $flags{'onevol'} = 0;
            $flags{'onept'}  = 0;
            $flags{'ser'}    = 0;
            $flags{'oneser'} = 0;
            
            $this = third_transform($this);
            
            ## Match the series expression and store it in a variable for later use
            $this = match_series_expression($this, \%elements, \%flags);
 
            ## Match the volume expression and store it in a variable for later use
            $this = match_vol_expressions($this, \%elements, \%flags);

            ## Match any no. expression and store it in a variable for later use
            $this = match_no_expressions($this, \%elements, \%flags);
            
            ## Match any pt. expression and store it in a variable for later use
            $this = match_pt_expressions($this, \%elements, \%flags);
            
            ## Match any number expression and store it in a variable for later use
            $this = match_any_numerical_expression($this, \%elements, \%flags);

            ## Match any year/chron expression and store it for later use
            match_chron_expressions($this, \%elements, \%flags);

            ## Match any year expression and store it in a variable for later use
            $this = match_years_expressions($this, \%elements);
            
            ## Match any month expression and store it in a variable for later use
            # "months" include seasons
            $this = match_month_expressions($this, \%elements, \%flags);
            
            ### NPF:
            ### Sanity checks on some of these expressions
            check_chron_expressions($newthis, \%elements, \%flags);
            
            ## now create our final string from all the pieces that we have assembled.
            $final = build_final_expression(\%elements, \%flags, $newthis);
            
            ## NPF:
            ## final expression postprocessing to fix common errors
            $final = post_final_transform($final);
        }

        # add new series, if needed
        if ( $flags{'ns_flag'} ) {
            # NPF: had been more baroque fiddling with @final array
            $final = 'n.s. ' . $final;
        }
        if ($final && $final =~ /[a-z0-9]/i) {
            push(@final, $final);
        }
    }

    my $addedv = $final[0] . ",";
    trace_run('initial addedv', $addedv);
    ## Add a v. to any descriptions that dont have a volume expressoin that come directly after another description on the same line with a v.
    for ( my $i = 1 ; $i < @final ; $i++ ) {
        if ( $final[0] =~ m/v\./g ) {
            if ( @final >= 2 ) {
                if ( $final[$i] !~ m/v./g ) {
                    if ( $final[$i] !~ m/no./g ) {
                        if ( $final[$i] !~ m/^(([0-9]{1,4})(-[0-9]{1,4})*)/ ) {
                            if (
                                $final[$i] =~ m/^(([0-9]{1,3})(-[0-9]{1,3})*)/ )
                            {
                                my $thisindex = index( $final[$i], ' ', 2 );
                                my $endhere = substr( $final[$i], $thisindex );
                                $final[$i] = "v." . $2 . "v." . $3 . $endhere;
                                $final[$i] =~ s/v\.-/-v\./g;
                                $final[$i] =~ s/v\. / /g;
                                $addedv .= $final[$i] . ",";
                            }
                            else {
                                $addedv .= $final[$i] . ",";
                            }
                        }
                        else {
                            $addedv .= $final[$i] . ",";
                        }
                    }
                    else {
                        $addedv .= $final[$i] . ",";
                    }
                }
                else {
                    $addedv .= $final[$i] . ",";
                }
            }
        }
        else {
            $addedv .= $final[$i] . ",";
        }
    }

    $addedv =~ s/, ,/,/g;
    chop($addedv);
    $addedv =~ s/,,/,/g;
    $addedv =~ s/,/, /g;
    $addedv =~ s/  / /g;
    $addedv =~ s/^, //g;
    $addedv =~ s/^,//g;
    $addedv =~ s/:,/,/g;
    $addedv =~ s/--/-/g;
    $addedv =~ s/:-/-/g;
    $addedv =~ s/\$3 /\$3/g;
    $addedv =~ s/=583/=583 /g;
    
    $addedv = addedv_post_final_transform($addedv);
    
    trace_run('returned addedv', $addedv);
    say "\nADDEDV:$addedv\n" if !$suppress_reports;
    return ( $addedv, $number_of_issues );
}

    # A little pseudo-documentation follows.

    # Definitions of a few variables:
    # $flags{'switch'} -> 1 means string starts with a no. treated as a volume, 0 means it doesn't.
    # $flags{'continued'} -> whether or not the string ends in a hyphen, which would indicate that the holdings continue.
    # $this -> Name for each section of the big looped array, made from the input then split on semicolons into an array
    # $flags{'copy'} -> indication that the section has indication that it's a 2nd copy (or so on).
    # $flags{'not_publ'} -> indicates "1987 not published" and the like
    # $flags{'ns'} -> track "new series" expressions and the like
    # $flags{'no'} -> "no." as basic enumeration, rather than "vol."

    # SCRIPT CALLS:
    # continued.pl


1;

