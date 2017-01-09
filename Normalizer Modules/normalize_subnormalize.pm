package Normalizer::normalize_subnormalize;

use strict;
use warnings;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        normalize_subnormalize
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

sub normalize_subnormalize {
    
    my ($string, $flags_ref) = @_;

    trace_run('normalize_subnormalize in', $string);

    ## normalize volume holdings that look like: Vol. 4 (1986) - Vol. 23 No. 1-8, 10-12 (2001) separately;
    if ( $string =~
m/v\.([0-9]{1,3})\s*(\([0-9]{4}\))\s*-*\s*v*\.*([0-9]{1,3})\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})(,\s*[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})+\s*(\([0-9]{4}\))/g
      )
    {
        my $final = _normalize_vol_year_to_vol_multinums_year($string, $flags_ref);
        return ($final, 1);
    }
    ## normalize volume holdings that look like: Vol. 4 no.1 (1986) - Vol. 23 No. 1-8, 10-12 (2001) separately;
    elsif ( $string =~
m/v\.([0-9]{1,3})\s*no\.([0-9]{1,3})\s*(\([0-9]{4}\))\s*-*\s*v*\.*([0-9]{1,3})\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})(,\s*[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})+\s*(\([0-9]{4}\))/g
      )
    {
        my $final = _normalize_vol_num_year_to_vol_multinums_year($string, $flags_ref);
        return ($final, 1);
    }
    ## normalize holdings that resemble v.5 no.6-10, 12 (1999);
    elsif ( $string =~
m/v*\.*([0-9]{1,3}):*\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})(,\s*[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})+\s*(\([0-9]{4}\))/g
      )
    {
        my $final = _normalize_vol_multinums_year($string, $flags_ref);
        return ($final, 1);
    }
    
    ## normalize holdings that resemble 1999 no.4, 6;
    elsif ( $string =~
m/([0-9]{4})\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})(,\s*[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})+/g
      )
    {
        my $final = _normalize_year_multinums($string, $flags_ref);
        return ($final, 1);
    }
    
    ## normalize holdings that resemble v.5 no.1, 3;
    elsif ( $string =~
m/v*\.*([0-9]{1,3})\s*:*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})(,\s*[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})+/g
      )
    {
        my $final = _normalize_vol_multinums($string, $flags_ref);
        return ($final, 1);
    }
    
    ## normalize holdings that resemble v.5 (1999) no.1, 3;
    elsif ( $string =~
m/^\s*v*\.*([0-9]{1,3})\s*(\([0-9]{4}\/*[0-9]{0,4}\))\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})(,\s*[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})+\s*$/g
      )
    {
        my $final = _normalize_vol_year_multinum($string, $flags_ref);
        return ($final, 1);
    }
    
    ## normalize holdings that resemble v.5 (1999) no.1
    elsif ( $string =~
m/^\s*v*\.*([0-9]{1,3})\s*(\([0-9]{4}\))\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})\s*$/g
      )
    {
        my $final = _normalize_vol_year_num($string, $flags_ref);
        return ($final, 1);
    }
    
    ## normalize holdings that resemble 1999 no.1
    elsif ( $string =~
m/^\s*([0-9]{4})\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})\s*$/g
      )
    {
        my $final = _normalize_year_num($string, $flags_ref);
        return ($final, 1);
    }
    
    ## normalize holdings that resemble v.1 no.9
    elsif ( $string =~
m/^\s*v*\.*([0-9]{1,3})\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})\s*$/g )
    {
        my $final = _normalize_vol_num($string, $flags_ref);
        return ($final, 1);
    }
    
    ## normalize holdings that resemble 1980-82
    elsif ( $string =~ m/^\s*([0-9]{2})([0-9]{2})-([0-9]{2})$/g ) 
    {
        my $final = _normalize_year_dash_year($string, $flags_ref);
        return ($final, 1);
    }
    
    ## normalize holdings that resemble Mar, Oct 1990
    elsif ( $string =~
m/^\s*([A-Za-z]{3,8}\/*[A-Za-z]{0,8})\s*(,\s*[A-Za-z]{3,8}-*[A-Za-z]{0,8}\/*[A-Za-z]{0,8})+\s*([0-9]{4}\/*[0-9]{0,4})$/g )
    {
        my $final = _normalize_mon_mon_year($string, $flags_ref);
        return ($final, 1);
    }
    
    ## normalize holdings that resemble 1990 mar, oct
    elsif ( $string =~
m/^\s*([0-9]{4}\/*[0-9]{0,4})\s*([A-Za-z]{3,8}\/*[A-Za-z]{0,8})\s*(,\s*[A-Za-z]{3,8}-*[A-Za-z]{0,8}\/*[A-Za-z]{0,8})+\s*$/g )
    {
        my $final = _normalize_year_mon_mon($string, $flags_ref);
        return ($final, 1);
    }

    ## normalize holdings that resemble v.120-21 (1991)
    elsif ( $string =~
m/^\s*v\.([0-9]{1})([0-9]{2})-([0-9]{2})\s*(\([A-Za-z]{0,6}\s*[0-9]{4}\))*\s*$/g )
    {
        my $final = _normalize_vol_vol_year($string, $flags_ref);
        return ($final, 1);
    }
    trace_run('normalize_subnormalize out', $string);
}


# ----------------------------------------------------------------------
# - INTERNAL ROUTINES
# ----------------------------------------------------------------------


sub _normalize_vol_year_to_vol_multinums_year {
    ## normalize volume holdings that look like: Vol. 4 (1986) - Vol. 23 No. 1-8, 10-12 (2001) separately;
    my ($string, $flags_ref) = @_;
    trace_run('_normalize_vol_year_to_vol_multinums_year', $string);
    $string=~
m/v\.([0-9]{1,3})\s*(\([0-9]{4}\))\s*-*\s*v*\.*([0-9]{1,3})\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})(,\s*[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})+\s*(\([0-9]{4}\))/g;
    my @commasplit = split( /,/, $string);
    my $volholder  = 'v.' . $1 . ' ' . $2 . '-v.' . $3;
    my $final      = $volholder . ":" . $4;
    my $end        = $6;
    $volholder  = 'v.' . $3;
    $end =~ s/\)\(/-/g;
    for ( my $i = 1 ; $i < @commasplit ; $i++ ) {
        $commasplit[$i] =~ s/\([0-9]{4}\)//g;
        $final .= ', ' . $volholder . ':no.' . $commasplit[$a];
    }
    $final .= " " . $end;
    $final =~ s/  / /g;
    $final =~ s/no\. /no\./g;
    if ( $flags_ref->{'copy'} ) {
        $final = "";
    }
    return $final;
}


# ----------------------------------------------------------------------


sub _normalize_vol_num_year_to_vol_multinums_year {
    ## normalize volume holdings that look like: Vol. 4 no.1 (1986) - Vol. 23 No. 1-8, 10-12 (2001) separately;
    my ($string, $flags_ref) = @_;
    trace_run('_normalize_vol_num_year_to_vol_multinums_year', $string);
    $string=~
m/v\.([0-9]{1,3})\s*no\.([0-9]{1,3})\s*(\([0-9]{4}\))\s*-*\s*v*\.*([0-9]{1,3})\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})(,\s*[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})+\s*(\([0-9]{4}\))/g;
    my @commasplit = split( /,/, $string);
    my $volholder  = 'v.' . $1 . ':no.' . $2 . ' ' . $3 . '-v.' . $4;
    my $final      = $volholder . ":" . $5;
    my $end        = $7;
    $volholder  = 'v.' . $4;
    $end =~ s/\)\(/-/g;
    for ( my $i = 1 ; $i < @commasplit ; $i++ ) {
        $commasplit[$i] =~ s/\([0-9]{4}\)//g;
        $final .= ', ' . $volholder . ':no.' . $commasplit[$a];
    }
    $final .= " " . $end;
    $final =~ s/  / /g;
    $final =~ s/no\. /no\./g;
    if ( $flags_ref->{'copy'} ) {
        $final = "";
    }
    return $final;

}


# ----------------------------------------------------------------------


sub _normalize_vol_multinums_year {   
    ## normalize holdings that resemble v.5 no.6-10, 12 (1999);
    my ($string, $flags_ref) = @_;
    trace_run('_normalize_vol_multinums_year', $string);
    $string =~
m/v*\.*([0-9]{1,3}):*\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})(,\s*[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})+\s*(\([0-9]{4}\))/g;
    my @commasplit = split( /,/, $string );
    my $volholder  = 'v.' . $1;
    my $final      = 'v.' . $1 . ':' . $2;
    for ( my $i = 1 ; $i < @commasplit ; $i++ ) {
        $final .= ', ' . $volholder . ':no.' . $commasplit[$i];
    }
    $final =~ s/  / /g;
    $final =~ s/Ja /Jan/g;
    $final =~ s/Oc /Oct/g;
    $final =~ s/Ap /Apr/g;
    $final =~ s/My /May/g;
    $final =~ s/Fe /Feb/g;
    $final =~ s/Mr /Mar/g;
    $final =~ s/Ag /Aug/g;
    $final =~ s/Au /Aug/g;
    $final =~ s/no\. /no\./g;

    if ( $flags_ref->{'copy'} ) {
        $final = "";
    }
    return $final;
}


# ----------------------------------------------------------------------


sub _normalize_year_multinums {   
    ## normalize holdings that resemble 1999 no.4, 6;
    my ($string, $flags_ref) = @_;
    trace_run('_normalize_year_multinums', $string);
    $string =~
m/([0-9]{4})\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})(,\s*[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})+/g;
    my @commasplit = split( /,/, $string );
    ## $final .=  $2;
    my $final = '' . $1 . ':' . $2;
    for ( my $i = 1 ; $i < @commasplit ; $i++ ) {
        $final .= ', ' . $1 . ':no.' . $commasplit[$i];
    }
    $final =~ s/  / /g;
    $final =~ s/no\. /no\./g;
    if ( $flags_ref->{'copy'} ) {
        $final = "";
    }
    return $final;
}


# ----------------------------------------------------------------------

sub _normalize_vol_multinums {
    ## normalize holdings that resemble v.5 no.1, 3;
    my ($string, $flags_ref) = @_;
    trace_run('_normalize_vol_multinums', $string);
    $string =~
m/v*\.*([0-9]{1,3})\s*:*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})(,\s*[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})+/g;
    my @commasplit = split( /,/, $string );
    my $volholder  = 'v.' . $1;
    my $final      = 'v.' . $1 . ':' . $2;
    for ( my $i = 1 ; $i < @commasplit ; $i++ ) {
        $final .= ', ' . $volholder . ':no.' . $commasplit[$i];
    }
    $final =~ s/  / /g;
    $final =~ s/no\. /no\./g;
    if ( $flags_ref->{'copy'} ) {
        $final = "";
    }
    return $final;

}


# ----------------------------------------------------------------------


sub _normalize_vol_year_multinum {
    ## normalize holdings that resemble v.5 (1999) no.1, 3;
    my ($string, $flags_ref) = @_;
    trace_run('_normalize_vol_year_multinum', $string);
    $string =~
m/^\s*v*\.*([0-9]{1,3})\s*(\([0-9]{4}\/*[0-9]{0,4}\))\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})(,\s*[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})+\s*$/g;
    my $myyear     = $2;
    my @commasplit = split( /,/, $string );
    my $volholder  = 'v.' . $1;
    my $final      = 'v.' . $1 . ':' . $3;
    for ( my $i = 1 ; $i < @commasplit ; $i++ ) {
        $final .= ', ' . $volholder . ':no.' . $commasplit[$i];
    }
    $final =~ s/  / /g;
    $final =~ s/no\. /no\./g;
    $final .= ' ' . $myyear;
    if ( $flags_ref->{'copy'} ) {
        $final = "";
    }
    return $final;
}

# ----------------------------------------------------------------------


sub _normalize_vol_year_num {
    ## normalize holdings that resemble v.5 (1999) no.1
    my ($string, $flags_ref) = @_;
    trace_run('_normalize_vol_year_num', $string);
    $string =~
m/^\s*v*\.*([0-9]{1,3})\s*(\([0-9]{4}\))\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})\s*$/g;
    my $final = 'v.' . $1 . ':' . $3 . ' ' . $2;
    if ( $flags_ref->{'copy'} ) {
        $final = "";
    }
    return $final;
}


# ----------------------------------------------------------------------


sub _normalize_year_num {
    ## normalize holdings that resemble 1999 no.1
    my ($string, $flags_ref) = @_;
    trace_run('_normalize_year_num', $string);
    $string =~
m/^\s*([0-9]{4})\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})\s*$/g;
    my $final = $1 . ':' . $2 . '';
    if ( $flags_ref->{'copy'} ) {
        $final = "";
    }
    return $final;
}


# ----------------------------------------------------------------------


sub _normalize_vol_num {
    ## normalize holdings that resemble v.1 no.9
    my ($string, $flags_ref) = @_;
    trace_run('_normalize_vol_num', $string);
    $string =~
m/^\s*v*\.*([0-9]{1,3})\s*(no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3})\s*$/g;
    my $final = 'v.' . $1 . ':' . $2;
    if ( $flags_ref->{'copy'} ) {
        $final = "";
    }
    return $final;
}


# ----------------------------------------------------------------------


sub _normalize_year_dash_year {
    ## normalize holdings that resemble 1980-82
    my ($string, $flags_ref) = @_;
    trace_run('_normalize_year_dash_year', $string);
    $string =~ m/^\s*([0-9]{2})([0-9]{2})-([0-9]{2})$/g;
    my $final = '(' . $1 . $2 . '-' . $1 . $3 . ')';
    if ( $flags_ref->{'copy'} ) {
        $final = "";
    }
    return $final;

}


# ----------------------------------------------------------------------


sub _normalize_mon_mon_year {
    ## normalize holdings that resemble Mar, Oct 1990
    my ($string, $flags_ref) = @_;
    trace_run('_normalize_mon_mon_year', $string);
    $string =~
m/^\s*([A-Za-z]{3,8}\/*[A-Za-z]{0,8})\s*(,\s*[A-Za-z]{3,8}-*[A-Za-z]{0,8}\/*[A-Za-z]{0,8})+\s*([0-9]{4}\/*[0-9]{0,4})$/g;
    my $myyear     = $3;
    my @commasplit = split( /,/, $string );
    my $final      = '(' . $1 . ' ' . $myyear . ')';
    for ( my $i = 1 ; $i < @commasplit ; $i++ ) {
        $final .= ', (' . $commasplit[$i] . ')';
    }
    $final =~ s/  / /g;
    if ( $flags_ref->{'copy'} ) {
        $final = "";
    }
    $final =~ s/\( /\(/g;
    return $final;
}

# ----------------------------------------------------------------------


sub _normalize_year_mon_mon {
    my ($string, $flags_ref) = @_;
    trace_run('_normalize_year_mon_mon', $string);
    ## normalize holdings that resemble 1990 mar, oct
    $string =~
m/^\s*([0-9]{4}\/*[0-9]{0,4})\s*([A-Za-z]{3,8}\/*[A-Za-z]{0,8})\s*(,\s*[A-Za-z]{3,8}-*[A-Za-z]{0,8}\/*[A-Za-z]{0,8})+\s*$/g;
    my $myyear     = $1;
    my @commasplit = split( /,/, $string );
    my $final      = '(' . $2 . ' ' . $myyear . ')';
    for ( my $i = 1 ; $i < @commasplit ; $i++ ) {
        $final .= ', (' . $commasplit[$i] . ' ' . $myyear . ')';
    }
    $final =~ s/  / /g;
    if ( $flags_ref->{'copy'} ) {
        $final = "";
    }
    $final =~ s/\( /\(/g;
    return $final;
}


# ----------------------------------------------------------------------


sub _normalize_vol_vol_year {
    ## normalize holdings that resemble v.120-21 (1991)
    my ($string, $flags_ref) = @_;
    trace_run('_normalize_vol_vol_year', $string);
    $string =~
m/^\s*v\.([0-9]{1})([0-9]{2})-([0-9]{2})\s*(\([A-Za-z]{0,6}\s*[0-9]{4}\))*\s*$/g;
    my $final = "v." . $1 . $2 . "-v." . $1 . $3 . " " . $4;
    if ( $flags_ref->{'switch'} ) {
        $final =~ s/v\./no\./g;
    }
    if ( $flags_ref->{'copy'} ) {
        $final = "";
    }
    return $final;
}

# ----------------------------------------------------------------------

1;
