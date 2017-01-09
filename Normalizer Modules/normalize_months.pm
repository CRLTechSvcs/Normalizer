package Normalizer::normalize_months;

use strict;
use warnings;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        months_abbreviations_transform
        months_seasons_transform
        seasons_transform
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

sub months_seasons_transform {
    my $string = shift; 
    trace_run('months_seasons_transform in', $string);
    # no letters beyond v for volume; return
    return $string if $string !~ /[a-uw-x]/i;
    $string = seasons_transform($string);
    $string = months_abbreviations_transform($string);
    trace_run('months_seasons_transform out', $string);
    return $string;
}


sub seasons_transform {
    my $string = shift;
    trace_run('seasons_transform in', $string);
    $string =~ s/\bspring\b/Spring/gi;
    $string =~ s/\bsummer\b/Summer/gi;
    $string =~ s/\bautumn\b/Fall/gi;
    $string =~ s/\bfall\b/Fall/gi;    
    $string =~ s/\bwinter\b/Winter/gi;
    # French
    $string =~ s/\bprintemps\b/Spring/gi;
    $string =~ s/\bété\b/Summer/gi;
    $string =~ s/\bete\b/Summer/gi;
    $string =~ s/\bautomne\b/Fall/gi;
    $string =~ s/\bhiver\b/Winter/gi;
    # German
    $string =~ s/\bfrühling\b/Spring/gi;
    $string =~ s/\bfruhling\b/Spring/gi;
    $string =~ s/\bfryhling\b/Spring/gi;  # Swiss German
    $string =~ s/\bsommer\b/Summer/gi;
    $string =~ s/\bherbst\b/Fall/gi;
    $string =~ s/\bhärbscht\b/Fall/gi;  # Swiss German
    $string =~ s/\bharbscht\b/Fall/gi;  # Swiss German
    # Irish
    $string =~ s/\bearrach\b/Spring/gi;
    $string =~ s/\bsamhradh\b/Summer/gi;
    $string =~ s/\bfómhar\b/Fall/gi;
    $string =~ s/\bgeimhreadh\b/Winter/gi;
    # Italian
    $string =~ s/\bprimavera\b/Spring/gi;
    $string =~ s/\bestate\b/Summer/gi;
    $string =~ s/\bautunno\b/Fall/gi;
    $string =~ s/\binverno\b/Winter/gi;
    # Russian
    $string =~ s/\bвесна\b/Spring/gi;
    $string =~ s/\bvesna\b/Spring/gi;
    $string =~ s/\bлето\b/Summer/gi;
    $string =~ s/\bleto\b/Summer/gi;
    $string =~ s/\bосень\b/Fall/gi;
    $string =~ s/\bosen\'\b/Fall/gi;
    $string =~ s/\bosen\b/Fall/gi;
    $string =~ s/\bosen\b/Fall/gi;
    $string =~ s/\bзима\b/Winter/gi;
    $string =~ s/\bzima\b/Winter/gi;
    # polish
    $string =~ s/\bwiosna\b/Spring/gi;
    $string =~ s/\blato\b/Summer/gi;
    $string =~ s/\bjesień\b/Fall/gi;
    $string =~ s/\bjesien\b/Fall/gi;
    # spanish
    $string =~ s/\bverano\b/Summer/gi;
    $string =~ s/\bverán\b/Summer/gi; # Galician
    $string =~ s/\bveran\b/Summer/gi; # Galician
    $string =~ s/\botoño\b/Fall/gi;
    $string =~ s/\botono\b/Fall/gi;
    $string =~ s/\boutono\b/Fall/gi; # Galician
    $string =~ s/\binvierno\b/Winter/gi;
    trace_run('seasons_transform out', $string);
    return $string;
}


sub months_abbreviations_transform {
    my $string = shift;
    trace_run('months_transform in', $string);
    #czech_months 
    $string =~ s/\bleden\b/Jan/gi;
    $string =~ s/\bledna\b/Jan/gi;
    $string =~ s/\búnor\b/Feb/gi;
    $string =~ s/\búnoru\b/Feb/gi;
    $string =~ s/\bbřezen\b/Mar/gi;
    $string =~ s/\bbřeznu\b/Mar/gi;
    $string =~ s/\bduben\b/Apr/gi;
    $string =~ s/\bkvěten\b/May/gi;
    $string =~ s/\bkvětnu\b/May/gi;
    $string =~ s/\bčerven\b/Jun/gi;
    $string =~ s/\bčervenec\b/Jul/gi;
    $string =~ s/\bčervence\b/Jul/gi;
    $string =~ s/\bsrpen\b/Aug/gi;
    $string =~ s/\bsrpnu\b/Aug/gi;
    $string =~ s/\bzáří\b/Sep/gi;
    $string =~ s/\bříjen\b/Oct/gi;
    $string =~ s/\bříjna\b/Oct/gi;
    $string =~ s/\blistopad\b/Nov/gi;
    $string =~ s/\blistopadu\b/Nov/gi;
    $string =~ s/\bprosinec\b/Dec/gi;
    $string =~ s/\bprosince\b/Dec/gi;
    $string =~ s/\bprosinci\b/Dec/gi;
    #english_months 
    $string =~ s/\bjanuary\b/Jan/gi;
    $string =~ s/\bfebruary\b/Feb/gi;
    $string =~ s/\bmarch\b/Mar/gi;
    $string =~ s/\bapril\b/Apr/gi;
    $string =~ s/\bmay\b/May/gi;
    $string =~ s/\bjune\b/Jun/gi;
    $string =~ s/\bjuly\b/Jul/gi;
    $string =~ s/\baugust\b/Aug/gi;
    $string =~ s/\bseptember\b/Sep/gi;
    $string =~ s/\boctober\b/Oct/gi;
    $string =~ s/\bnovember\b/Nov/gi;
    $string =~ s/\bdecember\b/Dec/gi;
    #french_months 
    $string =~ s/\bjanvier\b/Jan/gi;
    $string =~ s/\bfévrier\b/Feb/gi;
    $string =~ s/\bmars\b/Mar/gi;
    $string =~ s/\bavril\b/Apr/gi;
    $string =~ s/\bmai\b/May/gi;
    $string =~ s/\bjuin\b/Jun/gi;
    $string =~ s/\bjuillet\b/Jul/gi;
    $string =~ s/\baoût\b/Aug/gi;
    $string =~ s/\baout\b/Aug/gi;
    $string =~ s/\bseptembre\b/Sep/gi;
    $string =~ s/\boctobre\b/Oct/gi;
    $string =~ s/\bnovembre\b/Nov/gi;
    $string =~ s/\bdécembre\b/Dec/gi;
    #dutch_months 
    $string =~ s/\bjanuari\b/Jan/gi;
    $string =~ s/\bfebruari\b/Feb/gi;
    $string =~ s/\bmaart\b/Mar/gi;
    $string =~ s/\bapril\b/Apr/gi;
    $string =~ s/\bmei\b/May/gi;
    $string =~ s/\bjuni\b/Jun/gi;
    $string =~ s/\bjuli\b/Jul/gi;
    $string =~ s/\baugustus\b/Aug/gi;
    $string =~ s/\bseptember\b/Sep/gi;
    $string =~ s/\boktober\b/Oct/gi;
    $string =~ s/\bnovember\b/Nov/gi;
    $string =~ s/\bdecember\b/Dec/gi;
    #finnish_months 
    $string =~ s/\btammikuu\b/Jan/gi;
    $string =~ s/\bhelmikuu\b/Feb/gi;
    $string =~ s/\bmaaliskuu\b/Mar/gi;
    $string =~ s/\bhuhtikuu\b/Apr/gi;
    $string =~ s/\btoukokuu\b/May/gi;
    $string =~ s/\bkesäkuu\b/Jun/gi;
    $string =~ s/\bheinäkuu\b/Jul/gi;
    $string =~ s/\belokuu\b/Aug/gi;
    $string =~ s/\bsyyskuu\b/Sep/gi;
    $string =~ s/\blokakuu\b/Oct/gi;
    $string =~ s/\bmarraskuu\b/Nov/gi;
    $string =~ s/\bjoulukuu\b/Dec/gi;
    #german_months 
    $string =~ s/\bjanuar\b/Jan/gi;
    $string =~ s/\bfebruar\b/Feb/gi;
    $string =~ s/\bmärz\b/Mar/gi;
    $string =~ s/\bmȧrz\b/Mar/gi;    # really a typo
    $string =~ s/\bmarz\b/Mar/gi;    # de-unicoded
    $string =~ s/\bapril\b/Apr/gi;
    $string =~ s/\bmai\b/May/gi;
    $string =~ s/\bjuni\b/Jun/gi;
    $string =~ s/\bjuli\b/Jul/gi;
    $string =~ s/\baugust\b/Aug/gi;
    $string =~ s/\bseptember\b/Sep/gi;
    $string =~ s/\boktober\b/Oct/gi;
    $string =~ s/\bnovember\b/Nov/gi;
    $string =~ s/\bdezember\b/Dec/gi;
    #irish_months
    $string =~ s/\beanáir\b/Jan/gi;
    $string =~ s/\bfeabhra\b/Feb/gi;
    $string =~ s/\bmárta\b/Mar/gi;
    $string =~ s/\baibreán\b/Apr/gi;
    $string =~ s/\baíbreán\b/Apr/gi;
    $string =~ s/\bbealtaine\b/May/gi;
    $string =~ s/\bmeitheamh\b/Jun/gi;
    $string =~ s/\biúil\b/Jul/gi;
    $string =~ s/\blúnasa\b/Aug/gi;
    $string =~ s/\bmeán fómhair\b/Sep/gi;
    $string =~ s/\bméan fómhair\b/Sep/gi;
    $string =~ s/\bdeireadh fómhair\b/Oct/gi;
    $string =~ s/\bsamhain\b/Nov/gi;
    $string =~ s/\bnollaig\b/Dec/gi;
    $string =~ s/\bnodlaig\b/Dec/gi;
    #italian_months 
    $string =~ s/\bgennaio\b/Jan/gi;
    $string =~ s/\bfebbraio\b/Feb/gi;
    $string =~ s/\bmarzo\b/Mar/gi;
    $string =~ s/\baprile\b/Apr/gi;
    $string =~ s/\bmaggio\b/May/gi;
    $string =~ s/\bgiugno\b/Jun/gi;
    $string =~ s/\bluglio\b/Jul/gi;
    $string =~ s/\bagosto\b/Aug/gi;
    $string =~ s/\bsettembre\b/Sep/gi;
    $string =~ s/\bottobre\b/Oct/gi;
    $string =~ s/\bnovembre\b/Nov/gi;
    $string =~ s/\bdicembre\b/Dec/gi;
    #portuguese_months
    $string =~ s/\bjaneiro\b/Jan/gi;
    $string =~ s/\bfevereiro\b/Feb/gi;
    $string =~ s/\bmarço\b/Mar/gi;
    $string =~ s/\babril\b/Apr/gi;
    $string =~ s/\bmaio\b/May/gi;
    $string =~ s/\bjunho\b/Jun/gi;
    $string =~ s/\bjulho\b/Jul/gi;
    $string =~ s/\bagosto\b/Aug/gi;
    $string =~ s/\bsetembro\b/Sep/gi;
    $string =~ s/\boutubro\b/Oct/gi;
    $string =~ s/\bnovembro\b/Nov/gi;
    $string =~ s/\bdezembro\b/Dec/gi;
    #romanian_months 
    $string =~ s/\bianuarie\b/Jan/gi;
    $string =~ s/\bianvarie\b/Jan/gi;
    $string =~ s/\bianuar\b/Jan/gi;
    $string =~ s/\bfebruarie\b/Feb/gi;
    $string =~ s/\bfevruarie\b/Feb/gi;
    $string =~ s/\bmartie\b/Mar/gi;
    $string =~ s/\baprilie\b/Apr/gi;
    $string =~ s/\bmai\b/May/gi;
    $string =~ s/\bmaiŭ\b/May/gi;
    $string =~ s/\biunie\b/Jun/gi;
    $string =~ s/\biuniŭ\b/Jun/gi;
    $string =~ s/\biulie\b/Jul/gi;
    $string =~ s/\biuliu\b/Jul/gi;
    $string =~ s/\baugust\b/Aug/gi;
    $string =~ s/\bsetiembre\b/Sep/gi;
    $string =~ s/\bseptembrie\b/Sep/gi;
    $string =~ s/\bseptemvrie\b/Sep/gi;
    $string =~ s/\boctombrie\b/Oct/gi;
    $string =~ s/\boctomvrie\b/Oct/gi;
    $string =~ s/\boctombre\b/Oct/gi;
    $string =~ s/\bnoiembrie\b/Nov/gi;
    $string =~ s/\bnoembre\b/Nov/gi;
    $string =~ s/\bnoemvrie\b/Nov/gi;
    $string =~ s/\bdecembrie\b/Dec/gi;
    $string =~ s/\bdecemvrie\b/Dec/gi;
    #russian_months 
    $string =~ s/\bянварь\b/Jan/gi;
    $string =~ s/\bjanvar\'\b/Jan/gi;
    $string =~ s/\bфевраль\b/Feb/gi;
    $string =~ s/\bfevrali\b/Feb/gi;
    $string =~ s/\bмарт\b/Mar/gi; 
    $string =~ s/\bmart\b/Mar/gi;
    $string =~ s/\bапрель\b/Apr/gi;
    $string =~ s/\baprel\'\b/Apr/gi;
    $string =~ s/\bмай\b/May/gi;
    $string =~ s/\bmaj\b/May/gi;
    $string =~ s/\bиюньi\b/Jun/gi;
    $string =~ s/\bjun\'\b/Jun/gi;
    $string =~ s/\bиюльi\b/Jul/gi;
    $string =~ s/\bjul\'\b/Jul/gi;
    $string =~ s/\bавгуст\b/Aug/gi;
    $string =~ s/\bavgust\b/Aug/gi;
    $string =~ s/\bсентябрь\b/Sep/gi;
    $string =~ s/\bsentjabr\'\b/Sep/gi;
    $string =~ s/\bоктябрь\b/Oct/gi;
    $string =~ s/\boktjabr\'\b/Oct/gi;
    $string =~ s/\bноябрь\b/Nov/gi;
    $string =~ s/\bnojabr\'\b/Nov/gi;
    $string =~ s/\bдекабрь\b/Dec/gi;
    $string =~ s/\bdekabr\'\b/Dec/gi;
    #spanish_months 
    $string =~ s/\benero\b/Jan/gi;
    $string =~ s/\bfebrero\b/Feb/gi;
    $string =~ s/\bmarzo\b/Mar/gi;
    $string =~ s/\babril\b/Apr/gi;
    $string =~ s/\bmayo\b/May/gi;
    $string =~ s/\bjunio\b/Jun/gi;
    $string =~ s/\bjulio\b/Jul/gi;
    $string =~ s/\bxullo\b/Jul/gi; # Galician
    $string =~ s/\bxulio\b/Jul/gi; # Galician
    $string =~ s/\bagosto\b/Aug/gi;
    $string =~ s/\bseptiembre\b/Sep/gi;
    $string =~ s/\boctubre\b/Oct/gi;
    $string =~ s/\bnoviembre\b/Nov/gi;
    $string =~ s/\bdiciembre\b/Dec/gi;
    #thai_months 
    $string =~ s/\bmakarakhom\b/Jan/gi;
    $string =~ s/\bkumphaphan\b/Feb/gi;
    $string =~ s/\bminakhom\b/Mar/gi;
    $string =~ s/\bmesayon\b/Apr/gi;
    $string =~ s/\bpruesaphakho\b/May/gi;
    $string =~ s/\bmithunayon\b/Jun/gi;
    $string =~ s/\bkarakadakhom\b/Jul/gi;
    $string =~ s/\bsinghakhom\b/Aug/gi;
    $string =~ s/\bkanyayon\b/Sep/gi;
    $string =~ s/\btulakhom\b/Oct/gi;
    $string =~ s/\bpruesajikayon\b/Nov/gi;
    $string =~ s/\bthanwakhom\b/Dec/gi;
    #unknown_months 
    # where oddities, mysteries, & misspellings go
    $string =~ s/\bjänner\b/Jan/gi;
    $string =~ s/\bfebruario\b/Feb/gi;
    $string =~ s/\bmartio\b/Mar/gi;
    $string =~ s/\baprili\b/Apr/gi;
    $string =~ s/\biunio\b/Jun/gi;
    $string =~ s/\bjuilet\b/Jul/gi;
    $string =~ s/\bjulli\b/Jul/gi;
    $string =~ s/\bseptembri\b/Sep/gi;
    $string =~ s/\bnovembri\b/Nov/gi;
    $string =~ s/\bnovmbre\b/Nov/gi;
    $string =~ s/\bdecembri\b/Dec/gi;
    $string =~ s/\bdececember\b/Dec/gi;
    $string =~ s/\bfirst month\b/Jan/gi;
    $string =~ s/\bsecond month\b/Feb/gi;
    $string =~ s/\bthird month\b/Mar/gi;
    $string =~ s/\bfourth month\b/Apr/gi;
    $string =~ s/\bfifth month\b/May/gi;
    $string =~ s/\bsixth month\b/Jun/gi;
    $string =~ s/\bseventh month\b/Jul/gi;
    $string =~ s/\beighth month\b/Aug/gi;
    $string =~ s/\bninth month\b/Sep/gi;
    $string =~ s/\btenth month\b/Oct/gi;
    $string =~ s/\beleventh month\b/Nov/gi;
    $string =~ s/\btwelfth month\b/Dec/gi;

    ##########################
    #   ABBREVIATIONS
    ##########################
    # dutch abbrevs
    $string =~ s/\bmaart\b/Mar/gi;
    $string =~ s/\bmei\b/May/gi;
    $string =~ s/\bjuni\b/Jun/gi;
    $string =~ s/\bjuli\b/Jul/gi;
    $string =~ s/\bokt\b/Nov/gi;
    # french abbrevs
    $string =~ s/\bjanv\b/Jan/gi;
	$string =~ s/\bfévr\b/Feb/gi;
	$string =~ s/\bmars\b/Mar/gi;
	$string =~ s/\bavril\b/Apr/gi;
	$string =~ s/\bavr\b/Apr/gi;
	$string =~ s/\bmai\b/May/gi;
	$string =~ s/\bjuin\b/Jun/gi;
	$string =~ s/\bjuil\b/Jul/gi;
	$string =~ s/\baoût\b/Aug/gi;
	$string =~ s/\bdéc\b/Dec/gi;
    # german abbrevs
	$string =~ s/\bjän\b/Jan/gi;
	$string =~ s/\bmärz\b/Mar/gi;
	$string =~ s/\bmai\b/May/gi;
	$string =~ s/\bjuni\b/Jun/gi;
	$string =~ s/\bjuli\b/Jul/gi;
	$string =~ s/\bdez\b/Dec/gi;
    # italian abbreviations 
    $string =~ s/\bgenn\b/Jan/gi;
    $string =~ s/\bfebbr\b/Feb/gi;
    $string =~ s/\bmagg\b/May/gi;
    $string =~ s/\bgiugno\b/Jun/gi;
    $string =~ s/\bluglio\b/Jul/gi;
    $string =~ s/\bag\b/Aug/gi;
    $string =~ s/\bsett\b/Sep/gi;
    $string =~ s/\bott\b/Oct/gi;
    $string =~ s/\bdic\b/Dec/gi;
    # russian abbreviations
    $string =~ s/\bianv\b/Jan/gi;
	$string =~ s/\bfevr\b/Feb/gi;
	$string =~ s/\bmart\b/Mar/gi;
	$string =~ s/\biiun\'\b/Jun/gi;
	$string =~ s/\biiun\b/Jun/gi;
	$string =~ s/\biiul\'\b/Jul/gi;
	$string =~ s/\biiul\b/Jul/gi;
	$string =~ s/\bavg\b/Aug/gi;
	$string =~ s/\bsent\b/Sep/gi;
	$string =~ s/\bnoiabr\'\b/Nov/gi;
	$string =~ s/\bnoiabr\b/Nov/gi;
	$string =~ s/\bdek\b/Dec/gi;
    # spanish abbrevs
	$string =~ s/\babr\b/Apr/gi;
    # portuguese abbrevs
    $string =~ s/\bout\./Oct/gi;
    # unknown_abbreviations
    # unknown languages, or stupid abbreviations (require period with them))
    $string =~ s/\bJänn\.\b/Jan/gi;
    $string =~ s/\bjänn\.\b/Jan/gi;
    $string =~ s/\bseptemb\.\b/Sep/gi;
    $string =~ s/\boctob\.\b/Oct/gi;
    $string =~ s/\bnovemb\.\b/Nov/gi;
    $string =~ s/\bdecemb\.\b/Dec/gi;
    
    # english abbrevs -- doubles as cleanup of traliing periods
    $string =~ s/\bjan\.*\b/Jan/gi;
    $string =~ s/\bfebr?\.*\b/Feb/gi;
    $string =~ s/\bmar\.*\b/Mar/gi;
    $string =~ s/\bapr\.*\b/Apr/gi;
    $string =~ s/\bmay\.*\b/May/gi;
    $string =~ s/\bjun\.*\b/Jun/gi;
    $string =~ s/\bjul\.*\b/Jul/gi;
    $string =~ s/\baug\.*\b/Aug/gi;
    $string =~ s/\bsep\.*\b/Sep/gi;
    $string =~ s/\bsept\.*\b/Sep/gi;
    $string =~ s/\boct\.*\b/Oct/gi;
    $string =~ s/\bnov\.*\b/Nov/gi;
    $string =~ s/\bdec\.*\b/Dec/gi;    
    trace_run('months_transform out', $string);
    return $string;
}


1;
