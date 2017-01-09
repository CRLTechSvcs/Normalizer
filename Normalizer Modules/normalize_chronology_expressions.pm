package Normalizer::normalize_chronology_expressions;

use strict;
use warnings;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        match_chron_expressions 
        match_month_expressions
        match_years_expressions
        check_chron_expressions
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

sub match_chron_expressions {   
    ## Match any year/chron expression and store it for later use
    my ($string, $elements_ref, $flags_ref) = @_;
    trace_run('match_chron_expressions in', $string);
    $flags_ref->{'monthmatch'} = 0;
    $elements_ref->{'comboexp'}  = "(" . $string . ")";
    $elements_ref->{'comboexp'} =~ s/reprino\.ted/reprinted/g;
    $elements_ref->{'comboexp'} =~ s/repriv\.ted/reprinted/g;
    $elements_ref->{'comboexp'} =~ s/ published/:published/g;
    $elements_ref->{'comboexp'} =~ s/,//g;
    $elements_ref->{'comboexp'} =~ s/v\.d\./n\.d\./g;
    $elements_ref->{'comboexp'} =~ s/v\.d/n\.d\./g;
    $elements_ref->{'comboexp'} =~ s/no\.d\./n\.d\./g;
    $elements_ref->{'comboexp'} =~ s/\|\|//g;
    $elements_ref->{'comboexp'} =~ s/\|//g;
    $elements_ref->{'comboexp'} =~ s/\( +/\(/g;
    $elements_ref->{'comboexp'} =~ s/ +\)/\)/g;
    $elements_ref->{'comboexp'} =~ s/([0-9]{4}) /$1-/g;
    $elements_ref->{'comboexp'} =~ s/[Ss]priv\.g/Spring/g;
    $elements_ref->{'comboexp'} =~ s/[Ss]prino\.g/Spring/g;
    $elements_ref->{'comboexp'} =~ s/Jav\.uary/Jan/g;
    $elements_ref->{'comboexp'} =~ s/Jano\.uary/Jan/g;
    $elements_ref->{'comboexp'} =~ s/Ja( |\/)/Jan$1/g;
    $elements_ref->{'comboexp'} =~ s/Se( |\/)/Sep$1/g;
    $elements_ref->{'comboexp'} =~ s/Oc( |\/)/Oct$1/g;
    $elements_ref->{'comboexp'} =~ s/Ap( |\/)/Apr$1/g;
    $elements_ref->{'comboexp'} =~ s/My( |\/)/May$1/g;
    $elements_ref->{'comboexp'} =~ s/Fe( |\/)/Feb$1/g;
    $elements_ref->{'comboexp'} =~ s/Mr( |\/)/Mar$1/g;
    $elements_ref->{'comboexp'} =~ s/Je( |\/)/Jun$1/g;
    $elements_ref->{'comboexp'} =~ s/Jl( |\/)/Jul$1/g;
    $elements_ref->{'comboexp'} =~ s/De( |\/)/Dec$1/g;
    $elements_ref->{'comboexp'} =~ s/Nv( |\/)/Nov$1/g;
    $elements_ref->{'comboexp'} =~ s/Ag( |\/)/Aug$1/g;
    $elements_ref->{'comboexp'} =~ s/Jan\./Jan/g;
    $elements_ref->{'comboexp'} =~ s/Sep\./Sep/g;
    $elements_ref->{'comboexp'} =~ s/Sept\./Sep/g;
    $elements_ref->{'comboexp'} =~ s/Oct\./Oct/g;
    $elements_ref->{'comboexp'} =~ s/Apr\./Apr/g;
    $elements_ref->{'comboexp'} =~ s/May\./May/g;
    $elements_ref->{'comboexp'} =~ s/Feb\./Feb/g;
    $elements_ref->{'comboexp'} =~ s/Mar\./Mar/g;
    $elements_ref->{'comboexp'} =~ s/Jun\./Jun/g;
    $elements_ref->{'comboexp'} =~ s/Jul\./Jul/g;
    $elements_ref->{'comboexp'} =~ s/Dec\./Dec/g;
    $elements_ref->{'comboexp'} =~ s/Nov\./Nov/g;
    $elements_ref->{'comboexp'} =~ s/Aug\./Aug/g;
    $elements_ref->{'comboexp'} =~ s/- +/-/g;
    $elements_ref->{'comboexp'} =~ s/no\./n/g;
    $elements_ref->{'comboexp'} =~ s/-: /-/g;
    $elements_ref->{'comboexp'} =~ s/\(: /\(/g;
    $elements_ref->{'comboexp'} =~ s/(\D+)(\d+)/$1 $2/g;
    $elements_ref->{'comboexp'} =~ s/([0-9]{4}):([A-Za-z]{3,8}\/*[A-Za-z]{0,8})([^:_a-zA-Z]{1})/$2 $1$3/g;
    $elements_ref->{'comboexp'} =~ s/(\d+)\s+(\d+)/$1-$2/g;
    $elements_ref->{'comboexp'} =~ s/-\)/\)/g;
    $elements_ref->{'comboexp'} =~ s/: /:/g;
    $elements_ref->{'comboexp'} =~ s/ ([0-9]{4})/$1/g;
    $elements_ref->{'comboexp'} =~ s/([A-Za-z]{3,6}\/*[A-Za-z]{0,6})([0-9]{4})/$1 $2/g;
    $elements_ref->{'comboexp'} =~ s/([0-9]{4}:[A-Za-z]{3,8}:[0-9]{1,2}) /$1-/g;
    $elements_ref->{'comboexp'} =~ s/([0-9]{4})\./$1/g;
    $elements_ref->{'comboexp'} =~ s/([0-9]{4})\s*([A-Za-z]{3,6}\/*[A-Za-z]{0,6})/$1-$2/g;
    $elements_ref->{'comboexp'} =~ s/-[A-Za-z]{3,8}(-[A-Za-z]{3,8})/$1 /g;
    
    if ($elements_ref->{'comboexp'} =~
m/\s*([A-Za-z]{3,6}\/*[A-Za-z]{0,6})\s*([0-9]{4}\/*[0-9]{0,4})-([A-Za-z]{3,6}\/*[A-Za-z]{0,6})\s*([0-9]{4}\/*[0-9]{0,4})/)
    {
        if ( $2 eq $4 ) {
            $elements_ref->{'comboexp'} =~
s/\s*([A-Za-z]{3,6}\/*[A-Za-z]{0,6})\s*([0-9]{4}\/*[0-9]{0,4})-([A-Za-z]{3,6}\/*[A-Za-z]{0,6})\s*([0-9]{4}\/*[0-9]{0,4})/$1-$3 $4/;
        }
    }

    $elements_ref->{'comboexp'} =~ s/\s*([0-9]{4}\/*[0-9]{0,4})-([0-9]{4}\/*[0-9]{0,4})-([A-Za-z]{3,6}\/*[A-Za-z]{0,6})/$1-$3 $2/;

    if ($elements_ref->{'comboexp'} =~ m/[A-Za-z]{3,6}\/*[A-Za-z]{0,6}\s*([0-9]{4})-*\s*([0-9]{4})(:[A-Z][a-z]{2,3}:\d+)?/)
    {
        if ( $1 eq $2 && !defined($3) ) {
            $elements_ref->{'comboexp'} =~ s/[A-Za-z]{3,6}\/*[A-Za-z]{0,6}\s*([0-9]{4})-*\s*([0-9]{4})/$1/g;
            $flags_ref->{'monthmatch'} = 1;
        }        
    }

    if ($elements_ref->{'comboexp'} =~ m/([A-Za-z]{3,6}\/*[A-Za-z]{0,6})\s*([0-9]{4})-([A-Za-z]{3,6}\/*[A-Za-z]{0,6})\s*([0-9]{4})/)
    {
        if ( $2 == $4 ) {
            $elements_ref->{'comboexp'} =~ s/([A-Za-z]{3,6}\/*[A-Za-z]{0,6})\s*([0-9]{4})-([A-Za-z]{3,6}\/*[A-Za-z]{0,6})\s*([0-9]{4})/$1-$3 $2/g;
            $flags_ref->{'monthmatch'} = 1;
        }
    }

    $elements_ref->{'comboexp'} =~ s/nd nd/n\.d\.-n\.d\./g;
    $elements_ref->{'comboexp'} =~ s/\(([0-9]{4}\/*[0-9]{0,4})-([A-Za-z]{3,8}\/*[A-Za-z]{0,8})\)/\($2 $1\)/g;

    if ( $elements_ref->{'comboexp'} =~ m/:/ || $elements_ref->{'comboexp'} =~ m/n\.d\./ ) {
        $flags_ref->{'monthmatch'} = 1;
    }
    trace_run('match_chron_expressions out', $elements_ref);
}


# ----------------------------------------------------------------------


sub match_years_expressions {
    ## Match any year expression and store it in a variable for later use
    my ($string, $elements_ref, $flags_ref) = @_;
    trace_run('match_years_expressions in', $string);
    $elements_ref->{'firstyearexp'} = '';
    $elements_ref->{'lastyearexp'} = '';
    my @yearexp      = ( $string =~ m/([0-9]{4}(\/[0-9]{0,4})*)/g );
    $elements_ref->{'firstyearexp'}  = $yearexp[0];
    my $yearsize     = scalar @yearexp - 1;
    $elements_ref->{'lastyearexp'}   = $yearexp[ $yearsize - 1 ];
    $string =~ s/[0-9]{4}/ /g;
    trace_run('match_years_expressions out', $elements_ref);
    return $string;
}


# ----------------------------------------------------------------------


sub match_month_expressions {
    ## Match any month expression and store it in a variable for later use
    my ($string, $elements_ref, $flags_ref) = @_;
    trace_run('match_month_expressions in', $string);
    $elements_ref->{'firstchron'} = '';
    $elements_ref->{'lastchron'} = '';
    
    $string =~ s/sprino\.g/Spring/g;
    $string =~ s/Sprino\.g/Spring/g;
    my @chronexp =
      ( $string =~
m/[A-Za-z]{2,8}\.*\/[A-Za-z]{2,8}\.*|Spring|spring|Winter|winter|Fall|fall|Summer|summer|December|January|February|March|April|May|June|July|August|September|October|November|Dec|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sept|Sep|Oct|Nov|De\b|Jl\b|Se\b|Fe\b|Ap\b|Ag\b|Ja\b|Je\b|My\b|Oc\b|Fe\b|Mr\b/g
      );

    for ( my $i = 0 ; $i < @chronexp ; $i++ ) {
        $chronexp[$i] =~ s/Ja($|\/)/Jan$1/g;
        $chronexp[$i] =~ s/Se($|\/)/Sep$1/g;
        $chronexp[$i] =~ s/Oc($|\/)/Oct$1/g;
        $chronexp[$i] =~ s/Ap($|\/)/Apr$1/g;
        $chronexp[$i] =~ s/My($|\/)/May$1/g;
        $chronexp[$i] =~ s/Fe($|\/)/Feb$1/g;
        $chronexp[$i] =~ s/Mr($|\/)/Mar$1/g;
        $chronexp[$i] =~ s/Je($|\/)/Jun$1/g;
        $chronexp[$i] =~ s/Jl($|\/)/Jul$1/g;
        $chronexp[$i] =~ s/De($|\/)/Dec$1/g;
        $chronexp[$i] =~ s/Nv($|\/)/Nov$1/g;
        $chronexp[$i] =~ s/Ag($|\/)/Aug$1/g;
        $chronexp[$i] =~ s/Jan\./Jan/g;
        $chronexp[$i] =~ s/Sept\./Sep/g;
        $chronexp[$i] =~ s/Oct\./Oct/g;
        $chronexp[$i] =~ s/Apr\./Apr/g;
        $chronexp[$i] =~ s/May\./May/g;
        $chronexp[$i] =~ s/Feb\./Feb/g;
        $chronexp[$i] =~ s/Mar\./Mar/g;
        $chronexp[$i] =~ s/Jun\./Jun/g;
        $chronexp[$i] =~ s/Jul\./Jul/g;
        $chronexp[$i] =~ s/Dec\./Dec/g;
        $chronexp[$i] =~ s/Nov\./Nov/g;
        $chronexp[$i] =~ s/Aug\./Aug/g;
    }
    if ( @chronexp && scalar @chronexp >= 0 ) {
        $elements_ref->{'firstchron'} = $chronexp[0];
        $elements_ref->{'lastchron'}  = $chronexp[1];
    }
    else {
        $elements_ref->{'firstchron'} = "";
        $elements_ref->{'lastchron'}  = "";
    }
    if ( $flags_ref->{'chron'} == 1 ) {
        $elements_ref->{'firstchron'} = "";
        $elements_ref->{'lastchron'}  = "";
    }
    if ( $elements_ref->{'firstyearexp'} && $elements_ref->{'lastyearexp'} 
      && $elements_ref->{'firstyearexp'} eq $elements_ref->{'lastyearexp'} ) {
        $elements_ref->{'lastyearexp'} = "";
        if ( !$elements_ref->{'lastchron'} || $elements_ref->{'firstchron'} eq $elements_ref->{'lastchron'} ) {
            $elements_ref->{'lastchron'} = "";
        }
    }
    if ( scalar @chronexp == 1 ) {
        if ( $elements_ref->{'lastyearexp'} && $elements_ref->{'lastyearexp'} =~ /[a-z0-9]/i ) {
            $flags_ref->{'monthmatch'} = 1;
        }
    }
    trace_run('match_month_expressions out', $elements_ref);
}


# ----------------------------------------------------------------------


sub check_chron_expressions {
    # $string is original variant, i.e. "$newthis"
    my ($string, $elements_ref, $flags_ref) = @_;
    
    # "v.57:no.8-v.65:no.7 (1981)" generates a comboexp of "( :  1981)"
    if ($elements_ref->{'comboexp'} =~ /:/ && $string =~ /^[^\(]*\((\d\d\d\d)\)[^\)]*/) {
        $elements_ref->{'comboexp'} = '(' . $1 . ')';
    }
}


# ----------------------------------------------------------------------




1;
