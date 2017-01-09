package Normalizer::normalize_transforms;

use strict;
use warnings;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        addedv_post_final_transform
        dates_transform
        final_transform
        first_transform
        post_final_transform
        roman_transform
        second_transform
        switch_transform
        third_transform
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

sub first_transform {   
    
    my $string = shift;
    
    trace_run('first_transform in', $string);
    
    # NPF: "Ser.3, v.1-Ser.3, v.2" becomes "Ser.3; v.1-Ser.3; v.2"
    $string =~ s/^ *(ser\.? ?\d+) ?,/$1 /i;
    $string =~ s/; *(ser\.? ?\d+) ?,/; $1 /i;
    $string =~ s/- *(ser\.? ?\d+) ?,/$1 /i;
    
    # NPF: years with colon vols after -- 1942:v.2-4, 1979:v.5, 1978:v.7-9, 1977:11-39
    if ($string =~ /\d{4}(?:[-\/]\d{2,4})?:v\. ?\d+(?:-\d+)?/) {
        $string =~ s/(\d{4}(?:[-\/]\d{2,4})?):v\. ?(\d+(?:-\d+)?)/v\.$2 $1/gi;
        $string =~ s/(\d{4}(?:[-\/]\d{2,4})?):(\d+(?:-\d+)?)/v\.$2 $1/gi;
    }
        
    # get rid of "note" starting a deliniated section
    $string =~ s/\[Note[^\]]+\]//gi;
    $string =~ s/\(Note[^\)]+\)//gi;
    # get rid of "bound with" notes that are sharply delineated
    # TODO: is it OK to disacrd such notes? Needed for final output?
    # TODO: ways to deal with more integrated "bound with" notes"
    $string =~ s/\[(?:bound|bd\.?\/?) ?(?:with|w\.?)[^\]]+\]//gi;
    $string =~ s/\((?:bound|bd\.?\/?) ?(?:with|w\.?)[^\)]+\)//gi;
    
    # Fix error of no space or colon between volume number and "no." (v.50no.)
    $string =~ s/v\.(\d+)no\./v\.$1 no\./g;

    # Fix expressions not separated by commas ("v.60:1 (1974) v.60:3 (1974)-v.89:2 (1981) v.90:1 (1987)-v.103:6 pt. 2")
    $string =~ s/\)\s+v\.(\d+)/\), v\.$1/g;

    # Awkward text set off by colon.
    # TODO: Possible to do this for all unwanted text blocks?
    $string =~ s/;\s*publ/: publ/g;
    $string =~ s/;\s*repr/: repr/g;

    # Parenthesis then comma to semicolon. Anything likely to be a break in holdings divided by semicolon?
    $string =~ s/\),/\);/g;

    # Nate added segment below.
    # Look for possible break points with commas, and change to semicolons
    $string =~ s/, ?(vol|v|Bd\.)\.?/; v\./g;
    ## turn double slashes into a semicolon
    $string =~ s/\/\//;/g;
    $string =~ s/fall/Fall/g;
    $string =~ s/Autumn/Fall/g;
    $string =~ s/autumn/Fall/g;
    $string =~ s/sic\.*//g;
    $string =~ s/Deel/v\./g;
    $string =~ s/rev\.//g;
    $string =~ s/Kniga/no\./g;

    # NPF:  TODO: This doesn't work with years; something to do with continued flag?
    # With continued volumes, remove multiple dashes ("v.304-v.306-" to "v.304-")
    $string =~ s/\b(v\. ?\d+(?::? ?no\.?\d+)?) ?- ?v\. ?\d+(?::? ?no\.?\d+)? ?-/$1-/gi;
    # With continued years, remove multiple dashes ("2002-2012-" to "2002-")
    $string =~ s/(\d{4}(?:\/\d{2,4})?) ?- ?\d{4}(?:\/\d{2,4})? ?-/$1- /g;

    # Eliminate square brackets. First add space between bracket and any digit immediately before/after bracket.
    # TODO: Need to add space separator for non-digit characters as well?
    $string =~ s/(\d)\[/$1 /g;
    $string =~ s/\](\d)/ $1/g;
    $string =~ s/\[//g;
    $string =~ s/\]//g;
    $string =~ s/||\?//g;

    # Normalize phrase "no date"
    $string =~ s/no date/n\.d\./g;
    $string =~ s/\(nd\)/\(n\.d\.\)/g;
    $string =~ s/\(n\.d\)/\(n\.d\.\)/g;
    $string =~ s/([0-9]{4}), ([0-9]{4})/$1; $2/g;
    
    # Normalize all caps vol/number. All caps "NO." breaks final output, also do it here before switch statement check
    $string =~ s/\bV\./v\./g;
    $string =~ s/\bNO?\./no\./g;
    $string =~ s/\bN\.(\d)/no\.$1/g;
    
    # NPF:
    # normalize no. and v. without period and no space before numbers
    $string =~ s/\bv(\d+)/v\.$1/g;
    $string =~ s/\bno(\d+)/no\.$1/g;
           
    # NPF: "v.5: 2,5 (1883)" to "v.5:no.2 (1883); v.5:no.5 (1883)" (and similar with three numbers)
    # This is here because any semicolon breaks have to be added before normalizer breaks string into @normalarray
    if ($string =~ m/\bv\. ?(\d+): *(\d+), *(\d+) *, *(\d+) *\((\d{4})\)/) {
        if ($4 > $3 && $3 > $2) {
            $string =~ s/\bv\. ?(\d+): *(\d+), *(\d+) *, *(\d+) *\((\d{4})\)/v\.$1:no\.$2 \($5\); v\.$1:no\.$3 \($5\); v\.$1:no\.$4 \($5\)/gi;
        }
    }
    if ($string =~ m/\bv\. ?(\d+): *(\d+), *(\d+) *\((\d{4})\)/) {
        if ($3 > $2) {
            $string =~ s/\bv\. ?(\d+): *(\d+), *(\d+) *\((\d{4})\)/v\.$1:no\.$2 \($4\); v\.$1:no\.$3 \($4\)/gi;
        }
    }
    
    trace_run('first_transform out', $string);
    
    return $string;
}


# ----------------------------------------------------------------------


sub switch_transform {
    my $string = shift;

    trace_run('switch_transform in', $string);

    $string =~ s/Teil/v\./gi;
    $string =~ s/no[^v]\.*/v\./g;
    $string =~ s/No[^v]\.*/v\./g;
    $string =~ s/^n/v\./g;
    $string =~ s/([^A-Za-z])n/$1v\./g;
    if ($string =~ /bd\./i && /heft/i) {
        # pass
    }
    else {
        $string =~ s/Heft/v\./g;
    }
    $string =~ s/v\.o\./v\./g;
    $string =~ s/bull(?:etin)?\./v\./gi;
    trace_run('switch_transform out', $string);    
    
    return $string;
}


# ----------------------------------------------------------------------


sub second_transform {
    my ($string, $that) = @_;
    
    trace_run('second_transform in', $string);

    # regex for many sets of digits -- "34", "34-37", "34/35"
    my $range = qr/\d+(?: ?[\/-] ?\d+)?/;

    # Jahrgang and variants coming after number
    $string =~ s/($range)\. ?Jahrg(?:ang)?\.?/v\.$1/gi;

    ## if the holding record starts with a three digit number and none of the neighboring expressions have numbers than make that expression a volume expression
    if ( $that !~ m/n|N|heft|Heft|\bHft/ ) {
        if ( $string !~ m/^\s*([0-9]{4})/ ) {
            $string =~ s/^\s*([0-9]{1,3})/v\.$1/g;
        }
    }

    # Make starting 1 to 3 digit number a no. if neighboring expressions don't have years and have numbers.
    elsif ($that !~ m/[^o]v|V|Anul|Aar|Anno|Rock|Jah/
        && $that =~ m/^n|; n|^N|; N/ )
    {
        if ( $string !~ m/^\s*([0-9]{4})/ ) {
            $string =~ s/^\s*([0-9]{1,3})/no\.$1/g;
        }
    }

    # NPF:
    # get rid of central section of strings with multiple vol/year expressions:
    # v.1(1990)-v.3(1992)-v.6(1996) 
    # relatively conservative -- require leading v.\d + four digit year in each segment
    my $intra_hyphen_segment = qr/v\. *\d[^-]*\d{4}[^-]*/;
    $string =~ s/^ *($intra_hyphen_segment)- *$intra_hyphen_segment- *($intra_hyphen_segment)$/$1-$2/;
    
    # Long session of normalizing regular expressions.
    # First expression deletes a hyphen with spaces around it.
    # The original script as a part of the pre-processing had something like this: s/ - /-/g;
    # TODO: Either change it here or change the current preprocessing.
    $string =~ s/ - / /g;
    $string =~ s/Pt\./pt\./g;
    $string =~ s/(P|p)ts\./pt\./g;
    $string =~ s/publ\./published/g;
    $string =~ s/v\.\./v\./g;
	
    # NPF:
    # Delete page data
    $string =~ s/(v\.\d+) *p[pg]\.? ?\d+ ?- ?\d+, ?\d+ ?- ?\d+ ?\((\d\d\d\d)/$1 \($2/gi;
    $string =~ s/\bp[pg]\. ?\d+(?: ?- ?\d+)?/ /gi;

    # NPF:
    # delete always-extraneuous period (plus any spaces) starting a string
    $string =~ s/^ *\. *//;
    
    # NPF:
    # weird instances of colons before parens --> v.6: (1942)
    $string =~ s/: *\(/ \(/g;

    # NPF
    $string =~ s/([\W])sér\./$1ser\./gi;
    $string =~ s/\bsér\./ser\./gi;
    $string =~ s/nou?v\. ?s[eé]r\.:?/n\.s\./gi;

    # NPF -- some Euro series statements like this: 2.ser
    $string =~ s/(\d+)\. ?ser\./ser\.$1/g;

    # NPF -- "5th series", "2nd ser.", etc plus some foreign variants
    $string =~ s/(\d+)(?:st|nd|rd|th|er|e) *s[eé]r(?:ies)?\./ser\.$1/gi;
    $string =~ s/(\d+) sér\.?/ser\.$1/g;
    $string =~ s/\bSer\.? */ser\./gi;

    # Delete "n.s." and similar after whitespace at beginning of string.
    # TODO: Is there ever whitespace to lead off the string? Should we always delete "n.s." at start of string, or always after whitespace, or both?
    # TODO: Add other variants of "n.s." -- "2nd series" and etc.
    # NPF:
    if ($string =~ m/^\s*n\.s\./) {
        $string =~ s/n\.s\.//g;
    }
    $string =~ s/^\s*ns\s*//g;
    $string =~ s/^\s*new ser\.\s*//gi;
    $string =~ s/pt /pt\./g;
    $string =~ s/pt(\d)/pt\.$1/g;
    
    $string =~ s/Jaarg\.*/v\./gi;
    $string =~ s/\bårg\.? ?/v\./gi;

    # Delete "SEE:" to the end of the string.
    # TODO: Add more indicators of unusable text.
    $string =~ s/SEE:.*//g;
    $string =~ s/Jy/July/g;
    $string =~ s/Vols\./v\./g;

    # Delete indicators of ordinal numbers.
    $string =~ s/(\d+)th/$1/g;
    $string =~ s/(\d+)rd/$1/g;
    $string =~ s/(\d+)st/$1/g;
    $string =~ s/(\d+)nd/$1/g;
    $string =~ s/Volume/v\./g;
    $string =~ s/God\./v\./g;
    $string =~ s/Anul/v\./g;
    $string =~ s/Aargang/v\./g;
    $string =~ s/Svazek/v\./g;
    $string =~ s/Bd\./v\./g;
    $string =~ s/v\.r\./v\./g;
    $string =~ s/Nr\./no\./g;
    $string =~ s/\bafl\./no\./gi;
    $string =~ s/Anno/v\./gi;
    $string =~ s/año/v\./gi;
    $string =~ s/Roc\./v\./g;
    $string =~ s/cislo/no\./g;
    $string =~ s/Fasc\./no\./g;
    
    # NPF:
    $string =~ s/edição/no\./gi;

    # NPF:
    # fixes oddities that comes from things like 25.Jaarg
    $string =~ s/\bv\. *(\d+)\.? *v\./v\.$1/g;
    $string =~ s/- *(\d+) *\.?v\./- v\.$1/g;
    $string =~ s/^ *\.+//;
    $string =~ s/ *\.v\./v\./; 

    # "ser." is preferred term for series.
    # TODO: difference in treatment of "2nd series" and "n.s."/"sew series"? Appears to be. Should we keep this behavior?
    $string =~ s/series? /ser\./gi; 
    $string =~ s/ser\. /ser\./gi;
    $string =~ s/ser\.(\d+):? */ser\.$1 /g; 
    $string =~ s/\|\|//g;
    $string =~ s/ -/-/g;
    $string =~ s/- /-/g;
    $string =~ s/Vol/v\./g;
    $string =~ s/Arg\./v\./g;
    $string =~ s/Issue/no\./g;
    $string =~ s/issue/no\./g;
    $string =~ s/v\.vember/Nov/g;
    $string =~ s/Roc\./v\./g;
    $string =~ s/Rocz\./v\./g;
    $string =~ s/Rocn\./v\./g;
    $string =~ s/Rocnik/v\./g;
    $string =~ s/ no / no\./g;
    $string =~ s/:no/ no\./g;
    $string =~ s/Rok\./v\./g;
    $string =~ s/Rok/v\./g;
    $string =~ s/Jahrgang/v\./g;
    $string =~ s/Jahrg\./v\./g;
    $string =~ s/Jahr\.?\b/v\./g;
    $string =~ s/Jahr /v./;
    $string =~ s/Nr\./no\./g;
    $string =~ s/nr\./no\./g;
    $string =~ s/Aarg./v\./g;
    $string =~ s/\.+$//g;
    $string =~ s/fasc\./no\./g;
    $string =~ s/H\./no\./g;
    $string =~ s/Tomul|Tomus/v\./g;
    $string =~ s/Vyp\.\s*/v\./g;
    #NPF
    if ($string =~ /köt/) {
        $string =~ s/\bköt\.?/v\./gi;
        $string =~ s/\bsz\.?/no\./gi;
    }

    # année
    $string =~ s/(\d+)e?[\s\.]ann[ée]e/v\.$1/g;

    # Delete segments of up to three digit numbers contained within parentheses.
    # TODO: Expand this to include other things? (5+ digit numbers, text not including months, etc.)
    $string =~ s/\([0-9]{1,3}\)/ /g;
    $string =~ s/^Vol\.\s*/v\./g;
    $string =~ s/^V/v\./g;
    $string =~ s/  / /g;
    $string =~ s/Part/pt\./g; 
    $string =~ s/part/pt\./g;
    $string =~ s/pt\. /pt\./g;
    $string =~ s/z\./v\./g;
    $string =~ s/(\d+) jaargang/v\.$1/g;
    # get rid of periods after things that look like months
    $string =~ s/([A-Za-z]{3,4})\./$1/g;
    # return period to "ser" (i.e., undo above transform)
    $string =~ s/\bser(\d)/ser\.$1/g;
    $string =~ s/\.-/\./g; 
    $string =~ s/--/-/g;
    $string =~ s/Bano\.d/Band/g;
    $string =~ s/Band|Tomo|Tom\.*|tom\.*|\bv|vol.|Vol.|vol|Vol/v\./g;
    $string =~ s/Kniga|kniga|heft|hft\.?|Hefte|Heft|Hft\.?|Nr|Nos|No|iss|nos|no/no\./g;
    $string =~ s/\bkn\./no\./gi;

    # Nate added this one. Not 100% sure it's a good one.
    $string =~ s/Memoir/v\./g;
    $string =~ s/[Aa]nn[ée]e/v\./g; 
    $string =~ s/([^A-Za-z])n\.* *(\d+)/$1no\.$2/g;
    $string =~ s/^n\.*/no\./g;
    $string =~ s/no\.os\. /no\./g;
    $string =~ s/no\.r\. /no\./g;
    $string =~ s/no\.v\.e/Nove/g;
    $string =~ s/No\.v\.e/Nove/g;
    $string =~ s/\bno\.v\b/Nov/g;
    $string =~ s/no\.\. /no\./g;
    $string =~ s/no\. /no\./g;

    if ( $that =~ m/Tomo|Tom|tom| t\.|T\./ ) {
        $string =~ s/V\.yp\.\s*/no\./g;
        $string =~ s/V\.yp\s*/no\./g;
        $string =~ s/v\.yp\.\s*/no\./g;
        $string =~ s/v\.yp\s*/no\./g;
    }
    else {
        $string =~ s/V\.yp\.\s*/v\./g;
        $string =~ s/V\.yp\s*/v\./g;
        $string =~ s/v\.yp\.\s*/v\./g;
        $string =~ s/v\.yp\s*/v\./g;
    }
    $string =~ s/V\.yp\.\s*/v\./g;
    $string =~ s/V\.yp\s*/v\./g;
    $string =~ s/v\.ol\.\s*/v\./g;
    $string =~ s/v\.ol\s*/v\./g;
    $string =~ s/\.\./\./g;
    $string =~ s/v\.e\s*/v\./g;
    $string =~ s/v\. /v\./g;
    $string =~ s/\bT\. ?/v\./g;
    $string =~ s/(^|-| )t\./$1v\./g;
    $string =~ s/(^|-| )r\./$1v\./g;
    
    # NPF: Foreign months, as a temporary expedient
    $string =~ s/\bjuni\b/Jun/gi;
    
    $string =~ s/nov\./Nov/g;    
    $string =~ s/December/Dec/gi;
    $string =~ s/February/Feb/gi;
    $string =~ s/March/Mar/gi;
    $string =~ s/A[pv]ril/Apr/gi;
    $string =~ s/June/Jun/gi;
    $string =~ s/August/Aug/gi;
    $string =~ s/July/Jul/gi;
    $string =~ s/September|Sept\.?/Sep/gi;
    $string =~ s/October/Oct/gi;
    $string =~ s/January/Jan/gi;
    $string =~ s/June/Jun/gi;
    $string =~ s/November/Nov/gi;
    $string =~ s/no\.o\. /no\./g;
    $string =~ s/no\.o\./no\./g;
    $string =~ s/no\.v\./Nov/g;
    $string =~ s/Juno\./Jun/g;
    $string =~ s/Jano\./Jan/g;
    $string =~ s/spring/Spring/g;
    $string =~ s/Wino\.ter/Winter/g;
    $string =~ s/winter/Winter/g;
    $string =~ s/Juv\./Jun/g;
    $string =~ s/Wino\./Winter/g;
    $string =~ s/Fal/Fall/g;
    $string =~ s/Sum+\.?\b/Summer/g;
    $string =~ s/Spr\.?\b/Spring/g;
    $string =~ s/Spr[^i]/Spring/g;
    $string =~ s/summer/Summer/g;
    $string =~ s/winter/Winter/g;
    $string =~ s/spring/Spring/g;
    $string =~ s/fall/Fall/g;
    $string =~ s/no\.os\./no\./g;
    $string =~ s/Ja( |$|-|,)/Jan$1/g;
    $string =~ s/Se( |$|-|,)/Sep$1/g;
    $string =~ s/Ap( |$|-|,)/Apr$1/g;
    $string =~ s/My( |$|-|,)/May$1/g;
    $string =~ s/Fe( |$|-|,)/Feb$1/g;
    $string =~ s/De( |$|-|,)/Dec$1/g;
    $string =~ s/Oc( |$|-|,)/Oct$1/g;
    $string =~ s/Mr( |$|-|,)/Mar$1/g;
    $string =~ s/Je( |$|-|,)/Jun$1/g;
    $string =~ s/Jl( |$|-|,)/Jul$1/g;
    $string =~ s/Ag( |$|-|,)/Aug$1/g;
    $string =~ s/([A-Za-z]{3,8})\s*\/ ([A-Za-z]{3,8})/$1\/$2/g;
    $string =~ s/\([^m]*maps[^\)]*\)//g;
    $string =~ s/(no\.[0-9]{1,3})-([0-9]{4})/$1 $2/g;
    $string =~ s/(v\.[0-9]{1,3})-([0-9]{4})/$1 $2/g;
    $string =~ s/no\. (\d)/no\.$1/g;
    $string =~ s/v\.\. /v\./g;
    $string =~ s/no\.([0-9]{1,3}\/*[0-9]{0,3}):[0-9]{1,3}\s*\(/no\.$1 \(/g;
    $string =~ s/([0-9]{1,3}) : ([0-9]{1,2}\/*[0-9]{0,2}) /$1 no\.$2/g;
    $string =~ s/\(no\.[0-9]{1,3}-*[0-9]{0,3}\)//g;
    $string =~ s/\.\./\./g;
    $string =~ s/\.\./\./g;
    
    # NPF: special seasonal transforms
    $string =~ s/(\d\d\d\d):summ?\.?\b/$1:Summer/gi;
    $string =~ s/(\d\d\d\d):wint?\.?\b/$1:Winter/gi;
    
    # NPF: v.42:3 to v.43:no.3
    $string =~ s/\bv\. ?(\d+): ?(\d)/v\.$1:no\.$2/gi;
    # NPF: now the above without the volume designation -- 102:4 to v.102:no.4
    $string =~ s/\b(\d{1,3}): ?(\d{1,3})/v\.$1:no\.$2/gi;
    
    # NPF: 1984:1-7 to 1984:no.1-7
    $string =~ s/\b(\d{4}):(\d+-\d+)/$1:no\.$2/;
    
    # NPF: specific fix, (1986)-2,no.8 (Aug.1987) to (1986)-v.2:no.8 (Aug.1987))
    # TODO: some way to expland this without converting things that should be "no.2-4, no.8 (1987)"
    $string =~ s/\) ?- ?(\d+), ?no\.? ?(\d+) ?\(/\)-v\.$1:no\.$2 \(/gi;

    if ( $string =~ m/no\./ ) {
        $string =~ s/\( ([0-9]{1,3}) \)/no\.$1/g;
    }
    $string =~ s/([0-9]{1,3}):([0-9]{1,2}\/*[0-9]{0,2})\(/$1 no\.$2\ (/g;
    $string =~ s/\(v\.[0-9]{1,3}\)*//g;
    $string =~ s/no\.d\./n\.d\./g;

    trace_run('second_transform out', $string);

    return $string;
}


# ----------------------------------------------------------------------


sub dates_transform {
    my $string = shift;

    trace_run('dates_transform in', $string);

    # TODO: Keep/expand this?
    # Nate added
    # To convert dates like "2009:May/June" to "May/June 2009"
    # $string =~ s/(\d\d\d\d) : (Spring|Winter|Fall|Summer|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sept|Oct|Nov|Dec)\.?\/(Spring|Winter|Fall|Summer|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sept|Oct|Nov|Dec)\.?/$2\/$3 $1/ig;
    # To convert dates like "2009:May" to "May 2009"
    # $string =~ s/(\d\d\d\d) : (Spring|Winter|Fall|Summer|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sept|Oct|Nov|Dec)\.?/$2 $1/ig;

    # Nate Added
    #
    # NPF: 
    # something like (1976-77) will almost always be a year range, but run checks first anyway
    my @potential_ranges = m/\((\d{4}[-\/]\d\d)\)/g;
    foreach my $p (@potential_ranges) {
        $p =~ m/(\d\d)(\d\d)([-\/])(\d\d)/;
        if ($4 > $2) {
            my $new = '(' . $1 . $2 . $3 . $1 . $4 . ')';
            $string =~ s/$p/$new/;
        }
    }

    ## account for specific dates
    # Generally want them to turn out like "1927:Jan:27".
    # Dates like "Jan 12-Oct 16, 1927"
    $string =~ s/([A-Za-z]{3,6})\s*([0-9]{1,2})-([A-Za-z]{3,6})\s*([0-9]{1,2}),*\s*([0-9]{4})/$5:$1:$2-$5:$3:$4/g;

    # Dates like "12 Jan-16 Oct, 1927"
    $string =~ s/([0-9]{1,2})\s*([A-Za-z]{3,6})\s*-([0-9]{1,2})\s*([A-Za-z]{3,6})\s*,\s*([0-9]{4})/$5:$2:$1-$5:$4:$3/g;

    # Dates like "Jan 12-16, 1927". Change to "1927:Jan:12-1927:Jan:16"
    $string =~ s/([A-Za-z]{3,6})\.*\s*([0-9]{1,2})-([0-9]{1,2}),\s*([0-9]{4})/$4:$1:$2-$4:$1:$3/g;

    # CT: added next 2 lines
    # Dates like "Jan-Feb 12, 1927"
    $string =~ s/([A-Za-z]{3,6})\.*\s*\-\s*([A-Za-z]{3,6})\.*\s*([0-9]{1,2}),\s*([0-9]{4})/$1 $4-$4:$2:$3/g;

    # Dates like "Jan 12, 1927"
    $string =~ s/([A-Za-z]{3,6})\.*\s*([0-9]{1,2}),\s*([0-9]{4})/$3:$1:$2/g;

    # Dates like "1927:Jan.12"
    # TODO: This would also capture "1927:Vol.12". Make sure that doesn't happen!
    $string =~ s/([0-9]{4}):([A-Za-z]{3,6})\.([0-9]{1,2})/$1:$2:$3/g;

    # Dates like "1927:Jan 12"
    # TODO: This would also capture "1927:Vol 12". Make sure that doesn't happen!
    $string =~ s/([0-9]{4}):([A-Za-z]{3,6})\s*([0-9]{1,2})/$1:$2:$3/g;

    # Dates like "( 12 Jan, 1927"
    # TODO: Why spaces at the start, after the parenthesis? Make them optional?
    $string =~ s/\(\s*([0-9]{1,2})\s*([A-Za-z]{3,6})\s*([0-9]{4})/\($3:$2:$1/g;

    ## reformat years with slashes like: 1990/98 to 1990/1998; v.123/24 to v.123/124
    # Match 1927/29
    if ( $string =~ m/\b[0-9]{4}\/[0-9]{2}\b/ ) {
        $string = _transform_yyyy_slash_yy($string);
    }
    
    if ( $string =~ m/[0-9]{3,4}\/[0-9]{3,4}/ ) {
        # pass
    }
    # Match things like this: 123/45 (to turn into 123/145)
    elsif ( $string =~ m/[0-9]{3}\/[0-9]{2}/ ) {
        $string = _transform_ddd_slash_dd($string);
    }

    ## reformat years with dashes like: 1990-98 to 1990-1998
    if ( $string =~ m/[0-9]{4}-[0-9]{4}/ ) {
        # pass
    }
    elsif ( $string =~ m/[0-9]{4}-[0-9]{2}/ ) {
        $string = _transform_yyyy_dash_yy($string);
    }

    # Reformat things like "123-45" to "123-145"
    if ( $string =~ m/[0-9]{3,4}-[0-9]{3,4}/ ) {
        # pass
    }
    elsif ( $string =~ m/[0-9]{3}-[0-9]{2}/ ) {
        $string = _transform_ddd_dash_dd($string);
    }
    if ( $string !~ m/^\s*([0-9]{4})/ ) {
        $string =~ s/^\s*([0-9]{1,3})/v\.$1/g;
    }

    trace_run('dates_transform out', $string);

    return $string;
}


# ----------------------------------------------------------------------


sub roman_transform {
    
    use Roman;
    my $string = shift;

    trace_run('roman_transform in', $string);
    
    ## convert any roman numerals to arabic numerals
    my @roman = ( $string =~ m/[A-Z]{1,7}[\s|\(|,|:|\-|\/]{1}/g );
    for ( my $i = 0 ; $i < @roman ; $i++ ) {
        chop( $roman[$i] );
        if ( $roman[$i] =~ m/X|I|M|C|V|L/g ) {
            my $arabic = arabic( $roman[$i] ) if isroman( $roman[$i] );
            if ( $arabic && $arabic =~ m/[0-9]{1,3}/g ) {
                $string =~ s/$roman[$i]/$arabic/;
            }
        }
    }

    trace_run('roman_transform out', $string);

    return $string;
}


# ----------------------------------------------------------------------


sub third_transform {
    my $string = shift;
    
    trace_run('third_transform in', $string);
    
    $string =~ s/Nov\./Nov/g;
    $string =~ s/\.\./\./g;
    $string =~ s/v\. /v\./g;
    $string =~ s/  / /g;
    $string =~ s/\(/ /g;
    $string =~ s/\)/ /g;
    
    # NPF:
    # normalizer can't handle dates with days ("Jan 30, 1927"), so delete days
    my $months = qr/Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec/;
    $string =~ s/($months)\.? \d{1,2},? (\d{4})/$1 $2/g;

    # NPF:
    # in certain circumstances, space after no. causes output to break
    $string =~ s/\bno\. *(\d)/no\.$1/g;
    $string =~ s/:no\. *(\d)/:no\.$1/g;
    
    # add v. when needed
    $string =~ s/^ *v\. *(\d+) *- *(\d+) *$/v\.$1-v\.$2/;

    trace_run('third_transform out', $string);
    return $string;
}


# ----------------------------------------------------------------------


sub final_transform {
    ## smooth out the syntax for the final string.
    my ($string, $flags_ref, $number_of_issues) = @_;

    my $no_close_paren = qr/[^\)]/;

    $string =~ s/\/ /\//g;

    trace_run('final_transform in', $string);

    if ( $number_of_issues && $number_of_issues > 0 ) {
        $string =~ s/:no\.1\/$number_of_issues//g;
    }
    $string =~ s/(v\.[0-9]{1,3}\/*[0-9]{0,3}):no\.1(-v\.[0-9]{1,3})/$1-$2/g;
    $string =~ s/: pt\./:pt\./g;
    $string =~ s/-v\.:/:/g;
    $string =~ s/, pt\./:pt\./g;
    $string =~ s/-v\.pt/:pt/g;
    $string =~ s/-pt/:pt/g;
    $string =~ s/-v\. / /g;
    $string =~ s/-v\.\(/(/g;
    $string =~ s/- /-/g;
    $string =~ s/-\(/ \(/g;
    $string =~ s/\(/ \(/g;
    $string =~ s/-:v/-v/g;
    $string =~ s/-:no\.([0-9]{1,3})/no\.$1/g;
    $string =~ s/-:no/-/g;
    $string =~ s/no\. / /g;
    $string =~ s/  / /g;
    $string =~ s/-\./-/g;
    $string =~ s/\( /\(/g;
    $string =~ s/\(\- /\(/g;
    $string =~ s/\- /\-/g;
    $string =~ s/^ //g;
    $string =~ s/^-//g;
    $string =~ s/no /no\./g;
    $string =~ s/v\. /v\./g;
    $string =~ s/-\)/\)/g;
    $string =~ s/\(\)//g;
    $string =~ s/\(-/\(/g;
    $string =~ s/^;//g;
    $string =~ s/: \(/ \(/g;
    $string =~ s/v\.\)//g;
    $string =~ s/::/:/g;
    $string =~ s/:-\(/\(/g;
    $string =~ s/: ,/,/g;
    $string =~ s/, /,/g;
    $string =~ s/\$//g;
    $string =~ s/\(\//\(/g;
    $string =~ s/ -/-/g;
    $string =~ s/\s\)/\)/g;
    $string =~ s/Jan-Dec //g;
    $string =~ s/([A-Za-z]{3,4})-([0-9]{4})/$1 $2/g;
    $string =~ s/Sept /Sep /g;
    $string =~ s/sept /Sep /g;
    $string =~ s/v\.0/v\./g;
    $string =~ s/n\.d\. /n\.d\.-/g;
    $string =~ s/Falll/Fall/g;
    $string =~ s/Springing/Spring/g;
    $string =~ s/Jan ([0-9]{4})-Dec ([0-9]{4})/$1-$2/g;
    $string =~ s/Jan ([0-9]{4}\/[0-9]{4})-Dec ([0-9]{4}\/[0-9]{4})/$1-$2/g;

    if ( $number_of_issues && $number_of_issues > 1 ) {
        $string =~ s/(-v\.[0-9]{1,3}\/*[0-9]{0,3}):no\.$number_of_issues/$1/g;
    }
    $string =~ s/([0-9]{4})-Dec /$1-/g;

    if (   $string =~ m/Jan [0-9]{4}\-/
        && $string !~ m/Jan [0-9]{4}\-[0-9]{4}:[A-Z][a-z]{2,3}:\d{1,2}/ )
    {
        $string =~ s/Jan ([0-9]{4})-/$1-/g;
    }

    $string =~ s/([0-9]{4})-[A-Za-z]{0,6}\/*Dec /$1-/g;
    
    # NPF: turn ed. into v., if not v. exists
    if ($string !~ /\bv\./i) {
        $string =~ s/\bed\./v\./gi;
    }
    
    # NPF : added to eliminate things like "v.52:no.11 (Nov 2011-2011)"
    if ($string =~ m/([0-9]{4})[-\/]([0-9]{4})\)/) {
        if ($1 == $2) {
            $string =~ s/([0-9]{4})[-\/][0-9]{4}\)/$1\)/;
        }
    }
    
    # NPF: v.54 (1990-2011) to (1990-2011)
    $string =~ s/^ *(?:v|no)\.? *\d+ *(\($no_close_paren*\d\d\d\d *- *$no_close_paren*\d\d\d\d$no_close_paren*\)) *$/$1/;

    # CT: commented out following line
    #$string =~ s/Jan\/*[A-Za-z]{0,6} ([0-9]{4})-/$1-/g;
    $string =~ s/^(pt\.[0-9]{1,3})\s*\(([0-9]{4}\/*[0-9]{0,4}-*[0-9]{0,4}\/*[0-9]{0,4})\)/$2:$1/g;
    $string =~ s/:\s*$//g;
    $string =~ s/\/-/\//g;
    $string =~ s/\([^\d]*\)//g;
    if ($string =~ m/\(([0-9]{4})-([0-9]{4})\)/) {
        if ( $1 eq $2 ) {
            $string =~ s/\(([0-9]{4})-([0-9]{4})\)/\($1\)/;
        }
    }
    if ( $string =~ m/-v\./ ) {
        $string =~ s/pt\.1-/pt\./g;
    }
    if ( $flags_ref->{'copy'} ) {
        $string = "";
    }
    if ( $flags_ref->{'switch'} ) {
        $string =~ s/v\./no\./g;
    }

    # return preceding letters to any vol that had them
    if ($flags_ref->{'letter_before_number'}) {
        my @letter_vols = sort(keys %{$flags_ref->{'letter_before_number'}});
        foreach my $lv (@letter_vols) {
            if ($string =~ /v\. ?$lv\b/) {
                my $letter = $flags_ref->{'letter_before_number'}{$lv};
                $string =~ s/v\. ?$lv\b/v\.$letter$lv/g;
            }
        }
    }

    trace_run('final_transform out', $string);

    return $string;
}


# ----------------------------------------------------------------------


sub _transform_yyyy_slash_yy {
    # Match 1927/29
    my $string = shift;
    trace_run('_transform_yyyy_slash_yy in', $string);
    my @slashexp = ( $string =~ m/\b[0-9]{4}\/[0-9]{2}\b/g );
    if ( scalar @slashexp == 1 ) {
        my @slasharray = split( /\//, $slashexp[0] );
        my $partone = substr( $slasharray[0], 0, 2 );
        my $finished = $slasharray[0] . '/' . $partone . $slasharray[1];
        $string =~ s/$slashexp[0]/$finished/g;
    }
    if ( scalar @slashexp == 2 ) {
        my $slashorg   = $slashexp[0];
        my @slasharray = split( /\//, $slashexp[0] );
        my $partone    = substr( $slasharray[0], 0, 2 );
        my $finished   = $slasharray[0] . '/' . $partone . $slasharray[1];
        $string =~ s/$slashorg/$finished/g;
        my $slashorgtwo   = $slashexp[1];
        my @slasharraytwo = split( /\//, $slashexp[1] );
        my $partonetwo    = substr( $slasharraytwo[0], 0, 2 );
        my $finishedtwo = $slasharraytwo[0] . '/' . $partonetwo . $slasharraytwo[1];
        $string =~ s/$slashorgtwo/$finishedtwo/g;
    }
    trace_run('_transform_yyyy_slash_yy out', $string);
    return $string; 
}

# ----------------------------------------------------------------------

sub _transform_ddd_slash_dd {
    # Match things like this: 123/45 (to turn into 123/145)
    my $string = shift;
    trace_run('_transform_ddd_slash_dd in', $string);

    my @slashexp = ( $string =~ m/[0-9]{3}\/[0-9]{2}/g );
    if ( scalar @slashexp == 1 ) {
        my @slasharray = split( /\//, $slashexp[0] );
        my $partone = substr( $slasharray[0], 0, 1 );
        my $finished = $slasharray[0] . '/' . $partone . $slasharray[1];
        $string =~ s/$slasharray[0]/$finished/g;
    }
    if ( scalar @slashexp == 2 ) {
        my $slashorg   = $slashexp[0];
        my @slasharray = split( /\//, $slashexp[0] );
        my $partone    = substr( $slasharray[0], 0, 1 );
        my $finished   = $slasharray[0] . '/' . $partone . $slasharray[1];
        $string =~ s/$slashorg/$finished/g;
        my $slashorgtwo   = $slashexp[1];
        my @slasharraytwo = split( /\//, $slashexp[1] );
        my $partonetwo    = substr( $slasharraytwo[0], 0, 1 );
        my $finishedtwo = $slasharraytwo[0] . '/' . $partonetwo . $slasharraytwo[1];
        $string =~ s/$slashorgtwo/$finishedtwo/g;
    }
    trace_run('_transform_ddd_slash_dd out', $string);
    return $string;
}


# ----------------------------------------------------------------------

sub _transform_yyyy_dash_yy {
    # reformat years with dashes like: 1990-98 to 1990-1998
    my $string = shift;
    trace_run('_transform_yyyy_dash_yy in', $string);
    my @slashexp = ( $string =~ m/[0-9]{4}-[0-9]{2}/g );
    if ( scalar @slashexp == 1 ) {
        my @slasharray = split( /-/, $slashexp[0] );
        my $partone = substr( $slasharray[0], 0, 2 );
        my $finished = $slasharray[0] . '-' . $partone . $slasharray[1];
        $string =~ s/$slashexp[0]/$finished/g;
    }
    if ( scalar @slashexp == 2 ) {
        my $slashorg   = $slashexp[0];
        my @slasharray = split( /-/, $slashexp[0] );
        my $partone    = substr( $slasharray[0], 0, 2 );
        my $finished   = $slasharray[0] . '-' . $partone . $slasharray[1];
        $string =~ s/$slashorg/$finished/g;
        my $slashorgtwo   = $slashexp[1];
        my @slasharraytwo = split( /-/, $slashexp[1] );
        my $partonetwo    = substr( $slasharraytwo[0], 0, 2 );
        my $finishedtwo = $slasharraytwo[0] . '-' . $partonetwo . $slasharraytwo[1];
        $string =~ s/$slashorgtwo/$finishedtwo/g;
    }
    trace_run('_transform_yyyy_dash_yy out', $string);
    return $string;
}

# ----------------------------------------------------------------------

sub _transform_ddd_dash_dd {
    # Reformat things like "123-45" to "123-145"
    my $string = shift;
    trace_run('_transform_ddd_dash_dd in', $string);
    my @slashexp = ( $string =~ m/[0-9]{3}-[0-9]{2}/g );
    if ( scalar @slashexp == 1 ) {
        my @slasharray = split( /-/, $slashexp[0] );
        my $partone = substr( $slasharray[0], 0, 1 );
        my $finished = $slasharray[0] . '-' . $partone . $slasharray[1];
        $string =~ s/$slasharray[0]/$finished/g;
    }
    if ( scalar @slashexp == 2 ) {
        my $slashorg   = $slashexp[0];
        my @slasharray = split( /-/, $slashexp[0] );
        my $partone    = substr( $slasharray[0], 0, 1 );
        my $finished   = $slasharray[0] . '-' . $partone . $slasharray[1];
        $string =~ s/$slashorg/$finished/g;
        my $slashorgtwo   = $slashexp[1];
        my @slasharraytwo = split( /-/, $slashexp[1] );
        my $partonetwo    = substr( $slasharraytwo[0], 0, 2 );
        my $finishedtwo = $slasharraytwo[0] . '-' . $partonetwo . $slasharraytwo[1];
        $string =~ s/$slashorgtwo/$finishedtwo/g;
    }
    trace_run('_transform_ddd_dash_dd out', $string);
    return $string;
}

# ----------------------------------------------------------------------


sub post_final_transform {
    my $string = shift;
    # fix output like "(1979-1980-Sep 2004)"
    my $no_close_paren = qr/[^\)]/;
    $string =~ s/\(($no_close_paren+)-$no_close_paren+-($no_close_paren+)\)/\($1-$2\)/;
    
    $string =~ s/\( */\(/g;
    
    return $string;
}


# ----------------------------------------------------------------------

# NPF:
sub addedv_post_final_transform {
    my $string = shift;
    # something like "v.1-2 (1990-Apr 1991); v.3 (1991)" to "v.1-2 (1990-1991); v.3 (1991)"
    # this will allow it to concatenate without error
    my @possibilities = $string =~ m/([A-Z][a-z][a-z] \d{4}\)[^\(]+\(\d{4})/g;
    foreach my $p (@possibilities) {
        $p =~ m/^[A-Z][a-z]{2} (\d{4})\)([^\(]+)\((\d{4})/;
        if ($1 == $3) {
            my $new = $1 . ')' . $2 . '(' . $3;
            $p =~ s/\(/\\\(/g;
            $p =~ s/\)/\\\)/g;
            $string =~ s/$p/$new/;
        }
    }
    undef @possibilities;
    # same as above, but for "v.1 (1990); v.2 (Mar 1990)"
    @possibilities = $string =~ m/\((\d{4}\)[^\(]+\([A-Z][a-z]{2} \d{4})/g;
    foreach my $p (@possibilities) {
        $p =~ m/^(\d{4})\)([^\(]+)\([A-Z][a-z]{2} (\d{4})/;
        if ($1 == $3) {
            my $new = $1 . ')' . $2 . '(' . $3;
            $p =~ s/\(/\\\(/g;
            $p =~ s/\)/\\\)/g;
            $string =~ s/$p/$new/;
        }
    }
    
    # NPF:
    # things like "ser.10-ser.12 v.1-v.4 (1924-1949)"
    $string =~ s/(ser\.\d+)-(ser\.\d+) (v\.[^-]+)-v\./$1 $3-$2 v\./;
    
    return $string;
}


# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
# ----------------------------------------------------------------------



1;
