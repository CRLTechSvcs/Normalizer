package Normalizer::check;

use strict;
use warnings;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        check
        fix_frequency_typos
    );
    %EXPORT_TAGS = ('all' => \@EXPORT_OK);
}

binmode(STDOUT, ":encoding(utf8)");     #treat as if it is UTF-8
binmode(STDIN, ":encoding(utf8)");      #actually check if it is UTF-8W
binmode(STDERR, ":encoding(utf8)");

use open ':std', ':encoding(UTF-8)';

use utf8;
use v5.14;

##	This subroutine takes in the 310 info and returns the maximum number of issues per volume
sub check {
	my ($subfreq, $fh_ref, $ctrl_num) = @_;

	my ($number_of_issues, $number_text, $number_mult, $unit, $printErr, $part1, $part2);
	my (%number_to_digit);

	$number_of_issues = 0;
	$number_text = '';
	$number_mult = 1;

	# TODO: research CPAN for modules that will do this
	%number_to_digit = (
		'two' => 2,
		'twice' => 2,
		'three' => 3,
		'thrice' => 3,
		'four' => 4,
		'five' => 5,
		'six' => 6,
		'seven' => 7,
		'eight' => 8,
		'nine' => 9,
		'ten' => 10,
		'eleven' => 11,
		'twelve' => 12,
		'thirteen' => 13,
		'fourteen' => 14,
		'fifteen' => 15,
		'sixteen' => 16,
		'seventeen' => 17,
		'eighteen' => 18,
		'twenty' => 20,
		'twenty-one' => 21,
		'twenty-two' => 22,
		'twenty-four' => 24,
		'twenty-eight' => 28,
		'thirty' => 30,
		'thirty-six' => 36,
		'fifty' => 50,
		'fifty-one' => 51
	);

	# TODO: create comment block identifying known, not yet resolved, problems
	# i.e. X issues per (academic|school)? year or X bimonthly issues (during academic year)

    $subfreq = fix_frequency_typos($subfreq);

	if ($subfreq =~ m/Frequency varies|Irregular|\s*or\s*|except|Changed|Monthly \(|Bimonthly \(|ennial/i)	{
		# TODO: consider adding phrases to this set: Four to six no. a year, Every other day, Published every five years, Every ten years
		$number_of_issues = 0;
	
	} elsif ($subfreq =~ m/^Annual/i) {
		$number_of_issues = 0;

	} elsif ($subfreq =~ m/^Semi\s*\-?\s*annual|Semestral/i) {
		$number_of_issues = 2;

	} elsif ($subfreq =~ m/^Quarterly/i) {
		$number_of_issues = 4;

	} elsif ($subfreq =~ m/^Bi\-?monthly|^Every two months/i) {
		$number_of_issues = 6;

	} elsif ($subfreq =~ m/^Monthly|^Mensuel|^Mensual|^Mies|^Published monthly/i) {
		$number_of_issues = 12;

	} elsif ($subfreq =~ m/^Semi[- ]?monthly|^Twice monthly/i) {
		$number_of_issues = 24;

	} elsif ($subfreq =~ m/^Bi\-?weekly|^Fortnightly/i) {
		$number_of_issues = 26;

	} elsif ($subfreq =~ m/^Weekly/i) {
		$number_of_issues = 52;

	} elsif ($subfreq =~ m/^Semi\-?weekly/i) {
		$number_of_issues = 104;

	} elsif ($subfreq =~ m/^Daily/i) {
		$number_of_issues = 365;

	} elsif ($subfreq =~ m/^(\d+)(?:\s+(?:nos?\.?|numbers?|issue[ds]?|times?))?(?:\s+(?:a|per|each)\s+(year|annum|vol|month))?/i) {
		# handles phrases of the form '5 no./number/issue/issued/time a/per/each year/annum/vol' - (no., number, issue and time are optional and can also be pluralized)
		($number_of_issues, $unit) = ($1, $2);

	} elsif ($subfreq =~ m/^((?:[A-Za-z]+)|(?:[A-Za-z]+[ \-][A-Za-z]+))((?:\s+(?:nos?\.?|numbers?|issue[ds]?|times?))?(?:\s+(?:a|per|each)\s+(year|annum|vol|month))?)/i && defined($2) && $2 ne '') {
		# TODO: need to tweak regex to process twenty-eight, twenty eight or two-three
		# handles phrases of the form 'Five no./number/issue/issued/time a/per/each year/annum/vol' - (no., number, issue and time are optional and can also be pluralized)
		($number_text, $unit) = ($1, $3);
		$number_text = lc($number_text);
		$number_text =~ s/ /-/;

	} elsif ($subfreq =~ m/^(\d+)\s+(?:(?:nos?\.?|issue[ds]?|times?)\s+)?(year|month)ly/i) {
		# handles phrases starting with '5 no. yearly', '5 issue yearly', '5 issued yearly' and '5 time yearly' (no., issue and time are optional and can also be pluralized)
		($number_of_issues, $unit) = ($1, $2);

	} elsif ($subfreq =~ m/^((?:[A-Za-z]+)|(?:[A-Za-z]+[ \-][A-Za-z]+))\s+(?:(?:nos?\.?|issue[ds]?|times?)\s+)?(year|month)ly/i) {
		# TODO: need to tweak regex to process twenty-eight, twenty eight or two-three
		# handles phrases starting with 'Five no. yearly', 'Five issue yearly', 'Five issued yearly' and 'Five time yearly' (no., issue and time are optional and can also be pluralized)
		($number_text, $unit) = ($1, $2);
		$number_text = lc($number_text);
		$number_text =~ s/ /-/;



#8 no. year
# Triannual: 3 times a year
# Biannual: 2 times a year OR every 2 years?

	} elsif ($subfreq =~ m/^20 nos\.\/year/)	{
		$number_of_issues = 20;



	} elsif ($subfreq ne '') {
		$number_of_issues = 0;

		&crl_print_warning($fh_ref->{'WARNING'}, 'ID: '.$ctrl_num.', Frequency not recognized: '.$subfreq);
	}

	# process cases where the number text was included (instead of the digits)
	if ($number_text ne '') {
		if (exists($number_to_digit{$number_text})) {
			$number_of_issues = $number_to_digit{$number_text};
		} else {
			$printErr = 0;
			if ($number_text =~ m/\-/) {
				($part1, $part2) = split(/\-/, $number_text);
				$printErr = 1
				  if (!exists($number_to_digit{$part1}) || !exists($number_to_digit{$part2}) || $number_to_digit{$part1} > $number_to_digit{$part2});
			} else {
				$printErr = 1;
			}

			$number_of_issues = 0;
			if ($printErr) {
				&crl_print_err($fh_ref->{'ERROR'}, 'ID: '.$ctrl_num);
				&crl_print_err($fh_ref->{'ERROR'}, 'Frequency not recognized: '.$subfreq);
				&crl_print_err($fh_ref->{'ERROR'}, 'Text: '.$number_text);
				&crl_print_err($fh_ref->{'ERROR'}, '');
			}
		}
	}
	
	$number_mult = 12 if (defined($unit) && $unit eq 'month');
	$number_of_issues = $number_of_issues * $number_mult;

	return ($number_of_issues);
}
 
 
# NPF: to avoid cluttering the above with typo fixes
sub fix_frequency_typos {
    my $string = shift;
    $string =~ s/\bthee\b/three/i;
    $string =~ s/one (?:issue|iss\.?|number|no\.?|num\.?|volume|vol\.?) (?:a|per) year/annual/i;
    $string =~ s/Once a year/annual/i;
    $string =~ s/Tw(?:evl|elv)e (?:no. )?(?:a|per) year/annual/i;
    $string =~ s/^One issue *$/annual/i;
    $string =~ s/\bFout\b/four/i;
    return $string;
}

1;
