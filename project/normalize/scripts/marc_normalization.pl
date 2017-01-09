#!/usr/bin/perl

use warnings;
use strict;

use CRL::Utilities qw(:all);
use File::Path qw(make_path);
use Getopt::Std;

use Data::Dumper;


#	ORIGINAL SUBROUTINES
#	&check finds the frequency of a title. Only useful if we're working from full MARC records or something else with frequencies.
#	require 'compressnormal.pl';
#	&continued deals with holdings ending in a dash
#	&continued not called in main body of script
#	called in &shorten, &normalize, and repeatedly in &compressnormal
#	&gaps called in main body of script, towards the end.
#	require 'gaps.pl';
#	&gapsattempt not called in main body of script
#	called in &gaps
	use NormalizerDev::sort_holdings qw(:all);
	use NormalizerDev::qc_normalize qw(:all);
	use NormalizerDev::check qw(:all);
	use NormalizerDev::continued qw(:all);
	use NormalizerDev::normalize qw(:all);
	use NormalizerDev::gapsattempt qw(:all);
    use NormalizerDev::tests qw(:all);

my ($proj, $input_file, $output_file, $proj_dir, $input_dir, $log_dir, $output_dir,
	$ignore_concerns_file, $series_info_file, $error_file, $warning_file, $debug_file, $log_file, $gaps_file,
	$ignore_concerns_fh, $series_info_fh, $err_fh, $warn_fh, $debug_fh, $log_fh, $output_fh, $gaps_fh, $input_fh, 
	$ctrl_num, $concerns, $series_info, $orig_freq, $alt_freq, $tmp_freq, $orig_tmp_freq,
    $orig_holdings, $tmp_holdings, $replaced, $replace_text, $holdings, $has_error, $error_msg);
my (@addl_fields);
my (%opts, %fh, %ignore_concerns, %series_info, %orig_text_map, %freq);

# get parameters from command-line
&print_usage()
  if (!&getopts('hcgsipP:I:O:', \%opts));

# process required parameters
&print_usage() if ($opts{'h'} || !defined($opts{'P'}) || !defined($opts{'I'}) || !defined($opts{'O'}));
$proj = $opts{'P'};
if ($opts{'I'} =~ m/\//) {
	print STDERR 'The input filename should not include any directory paths.'.&crl_get_EOL();
	&print_usage();
}
$input_file = $opts{'I'};
if ($opts{'O'} =~ m/\//) {
	print STDERR 'The output filename should not include any directory paths.'.&crl_get_EOL();
	&print_usage();
}
$output_file = $opts{'O'};

# process optional parameters
$opts{'c'} = (defined($opts{'c'})) ? 1 : 0;
$opts{'g'} = (defined($opts{'g'})) ? 1 : 0;
#$supp = (defined($opts{'s'})) ? 1 : 0;
#$indexes = (defined($opts{'i'})) ? 1 : 0;
$opts{'p'} = (defined($opts{'p'})) ? 1 : 0;

# auto-skip prompts if concatenation is not enabled
$opts{'p'} = 1 if ($opts{'c'} == 0);

#$proj = &crlGetDateTime('sortable')
#  if (!defined($proj) || $proj eq '');

# define and create output directory structure
$proj_dir = $proj.'/normalize';
$input_dir = $proj_dir.'/input/';
make_path($input_dir);
$log_dir = $proj_dir.'/logs/';
make_path($log_dir);
$output_dir = $proj_dir.'/output/';
make_path($output_dir);

# determine log file names & locations
$error_file = $log_dir.'error.log';
$warning_file = $log_dir.'warning.log';
$debug_file = $log_dir.'debug.log';
$log_file = $log_dir.'info.log';

# determine input file names & locations
$ignore_concerns_file = $input_dir.'ignore_concerns.txt';
$series_info_file = $input_dir.'series_info.txt';
$input_file = $input_dir.$input_file;

# determine output file names & locations
$output_file = $output_dir.$output_file;
$gaps_file = $output_dir.'gaps_info';

# open files for logging
open($err_fh, '>', $error_file)
  or &crl_exit_err($err_fh, 'Could not open error file: '.$error_file.','.$!);
open($warn_fh, '>', $warning_file)
  or &crl_exit_err($err_fh, 'Could not open warning file: '.$warning_file.','.$!);
open($debug_fh, '>', $debug_file)
  or &crl_exit_err($err_fh, 'Could not open debug file: '.$debug_file.','.$!);
open($log_fh, '>', $log_file)
  or &crl_exit_err($err_fh, 'Could not open log file: '.$log_file.','.$!);

# add file handles to hash by type
$fh{'ERROR'} = $err_fh;
$fh{'WARNING'} = $warn_fh;
$fh{'DEBUG'} = $debug_fh;
$fh{'LOG'} = $log_fh;

# read in list of records with ignoreable issues
if (-f $ignore_concerns_file) {
	open($ignore_concerns_fh, '<', $ignore_concerns_file)
	  or &crl_exit_err($err_fh, 'Could not open ignore concerns file: '.$ignore_concerns_file.','.$!);
	while (<$ignore_concerns_fh>) {
		$_ =~ s/\s+$//;
		next if ($_ eq '');

		($ctrl_num, $concerns) = split(/[\t]\s*/, $_);
		$ctrl_num =~ s/^\#\s*/0\./;
		$ignore_concerns{$ctrl_num} = $concerns;
	}
	close($ignore_concerns_fh)
	  or &crl_exit_err($err_fh, 'Could not close ignore concerns file: '.$ignore_concerns_file.','.$!);
}

# read in list of records with new series info
if (-f $series_info_file) {
	open($series_info_fh, '<', $series_info_file)
	  or &crl_exit_err($err_fh, 'Could not open series info file: '.$series_info_file.','.$!);
	while (<$series_info_fh>) {
		$_ =~ s/\s+$//;
		next if ($_ eq '');

		($ctrl_num, $series_info) = split("\t", $_);
		$series_info{$ctrl_num} = $series_info;
	}
	close($series_info_fh)
	  or &crl_exit_err($err_fh, 'Could not close series info file: '.$series_info_file.','.$!);
}

# open files for output
open($output_fh, '>', $output_file)
  or &crl_exit_err($err_fh, 'Could not open output file: '.$output_file.','.$!);
open($gaps_fh, '>', $gaps_file)
  or &crl_exit_err($err_fh, 'Could not open gaps file: '.$gaps_file.','.$!);

# add file handles to hash by type
$fh{'GAPS'} = $gaps_fh;

open($input_fh, '<', $input_file)
  or &crl_exit_err($err_fh, 'Could not open input file: '.$input_file.','.$!);
while (<$input_fh>) {
	$_ =~ s/\s+$//;

	($ctrl_num, $orig_freq, $alt_freq, $orig_holdings, @addl_fields) = split("\t", $_);

	# initialize original values if not present
	$orig_freq = '' if (!defined($orig_freq));
	$orig_holdings = '' if (!defined($orig_holdings));

	# define frequency rate
	# TODO: determine how to deal with subfields better (or earlier)
	$orig_freq =~ s/\$b.*$//;
	$orig_freq =~ s/\$a//;

	$freq{'max_freq'} = check($orig_freq, \%fh, $ctrl_num);
	$freq{'second_freq'} = 0;
	$freq{'defined'} = (($orig_freq eq '' && defined($alt_freq) && $alt_freq ne '') || $freq{'max_freq'} != 0 || $orig_freq =~ m/^Annual/) ? 1 : 0;
	$freq{'freq'} = (defined($alt_freq) && $alt_freq ne '') ? 0 : $freq{'max_freq'};
	foreach $tmp_freq (split(/\s*;\s*/,$alt_freq)) {
		$tmp_freq =~ s/\$b.*$//;
		$tmp_freq =~ s/\$a//;
		$orig_tmp_freq = $tmp_freq;
		$tmp_freq = check($tmp_freq, \%fh, $ctrl_num);
		if ($tmp_freq > $freq{'max_freq'}) {
			$freq{'second_freq'} = $freq{'max_freq'};
			$freq{'max_freq'} = $tmp_freq;
		} elsif ($tmp_freq > $freq{'second_freq'}) {
			$freq{'second_freq'} = $tmp_freq;
		}
		$freq{'defined'} = 0 if ($tmp_freq == 0 && $orig_tmp_freq !~ m/^Annual/);
	}
	if (!$freq{'defined'}) {
		$freq{'max_freq'} = 0;
		$freq{'second_freq'} = 0;
	}

	# print detailed summary to log
	&crl_print_log($log_fh, 'ID: '.$ctrl_num);
	&crl_print_log($log_fh, 'Frequency (O): '.$orig_freq);
	&crl_print_log($log_fh, 'Frequency (N): '.$freq{'freq'});
	&crl_print_log($log_fh, 'Holdings (O): '.$orig_holdings);

	if ($orig_holdings eq '') {
		&crl_print_err($err_fh, 'ID: '.$ctrl_num);
		&crl_print_err($err_fh, 'Error Type(s): No original holdings exist');
		&crl_print_err($err_fh, '');

		# print separator line to log file
		&crl_print_log($log_fh, '');

		next;
	}

	# replace instances of 4-digit numbers followed by a / character followed by another 4-digit number (i.e. 1997/1998) with placeholder text
	# this is to allow successful normalization
	$tmp_holdings = $orig_holdings;
	$tmp_holdings =~ s/\([^\)]*\)//g;
	if ($tmp_holdings =~ m/\d{4}\/\d{4}/) {
		while ($orig_holdings =~ m/((\d{4})\/(\d{4}))/) {
			$orig_text_map{$2} = 0;
			$orig_text_map{$3} = 0;
			($orig_holdings, $replaced) = &replace_holdings_text(\%orig_text_map, $orig_holdings, $1, $3);
			last if (!$replaced);
			
		}
	}

	# replace instances of volumes containing letters (i.e. v.20A) with placeholder text
	# this is to allow successful normalization
	while ($orig_holdings =~ m/((\d+)[a-z])[^a-z]/i) {
		$orig_text_map{$2} = 0;
		($orig_holdings, $replaced) = &replace_holdings_text(\%orig_text_map, $orig_holdings, $1, $2);
		last if (!$replaced);
	}

	# normalize holdings
	($holdings, undef) = normalize($orig_holdings, $freq{'freq'}, $ctrl_num, \%fh);

	# revert prior text replacements
	if (scalar(keys %orig_text_map)) {
		foreach (keys %orig_text_map) {
			next if ($orig_text_map{$_} eq '0');
			$replace_text = $orig_text_map{$_};
			$holdings =~ s/$_/$replace_text/;
		}
		%orig_text_map = ();
		# TODO: auto-add to list of records for QC?
	}

	# sort holdings in place, to minimize manual updates
    trace_run('marc_normalization pre-sort', $holdings);
	$holdings = &sort_holdings($holdings, $ctrl_num, \%fh)
	  if (!&has_user_gen_concern($ignore_concerns{$ctrl_num}));
    trace_run('marc_normalization post-sort', $holdings);
    
	# check normalized data for potential issues; also handle concatenation
	($has_error, $error_msg, $holdings) = &post_process($ctrl_num, \%freq, $holdings, \%fh, \%opts, \%series_info, \%ignore_concerns, \@addl_fields);
    
    trace_run('marc_normalization post-concat', $holdings);

	if ($has_error && &display_error($ignore_concerns{$ctrl_num})) {
		&crl_print_err($err_fh, 'ID: '.$ctrl_num);
		&crl_print_err($err_fh, 'Holdings (N): '.$holdings);
		&crl_print_err($err_fh, 'Error Type(s): '.$error_msg);
		&crl_print_err($err_fh, '');
	}

	# print summary
	print $output_fh join("\t", $ctrl_num, $holdings, @addl_fields).&crl_get_EOL();

	# print normalized holdings to log
	&crl_print_log($log_fh, 'Holdings (N): '.$holdings);

	# print separator line to log file
	&crl_print_log($log_fh, '');

	# determine gaps
	#$gaps = gapsattempt($holdings, $freq);

	#if ($gaps =~ /\d/)	{
		#print "gaps:\t\t$gaps\n";
	#}

	#if ($supplements =~ /\d/)	{
		#print "suppl:\t\t$supplements\n";
	#}

	#if ($indexes =~ /\d/)	{
		#print "indexes:\t$indexes\n";
	#}
}
close($input_fh)
  or &crl_exit_err($err_fh, 'Could not close input file: '.$input_file.','.$!);

# update ignore concerns file
open($ignore_concerns_fh, '>', $ignore_concerns_file)
  or &crl_exit_err($err_fh, 'Could not open ignore concerns file: '.$ignore_concerns_file.','.$!);
foreach $ctrl_num (sort {&crlSortByNumOrString($a, $b)} keys %ignore_concerns) {
	$concerns = $ignore_concerns{$ctrl_num};
	$ctrl_num =~ s/^0\./\# /;
	print $ignore_concerns_fh $ctrl_num."\t".$concerns.&crl_get_EOL();
}
close($ignore_concerns_fh)
  or &crl_exit_err($err_fh, 'Could not close ignore concerns file: '.$ignore_concerns_file.','.$!);

# close remaining output files
close($gaps_fh)
  or &crl_exit_err($err_fh, 'Could not close gaps file: '.$gaps_file.','.$!);
close($output_fh)
  or &crl_exit_err($err_fh, 'Could not close output file: '.$output_file.','.$!);
close($log_fh)
  or &crl_exit_err($err_fh, 'Could not close log file: '.$log_file.','.$!);
close($debug_fh)
  or &crl_exit_err($err_fh, 'Could not close debug file: '.$debug_file.','.$!);
close($warn_fh)
  or &crl_exit_err($err_fh, 'Could not close warning file: '.$warning_file.','.$!);
close($err_fh)
  or &crl_exit_err($err_fh, 'Could not close error file: '.$error_file.','.$!);

exit 0;


# prints the usage for the script
sub print_usage() {

print <<HELP;

Usage: $0 -P <project> -I <input-filename> -O <output-filename> [OPTIONS]

Optional arguments:
	-h	Display this usage 

	-c	Concatenate holdings

	-g	Create gaps report

	-s	Include supplements in output

	-i	Include indexes in output

	-p	Skip prompts during script run


Example: $0 -P 'CHLA' -I 'normalize/input/input_file.tsv' -O 'normalize/output/norm_holdings.txt'

HELP

	exit 1;
}

# replace text in holdings string with placeholder text; this allows normalization to proceed on non-standard formats
sub replace_holdings_text() {
	my ($map_ref, $holdings, $replace_text, $replace_text_num) = @_;

	my ($tmp_num, $replaced);

	# check holdings for available replacement number
	$tmp_num = $replace_text_num;
	do {
		$tmp_num -= 1;
	} while (($holdings =~ m/$tmp_num/ || exists($map_ref->{$tmp_num})) && $tmp_num > 0);

	if ($tmp_num == 0) {
		&crl_print_warning($fh{'WARNING'}, 'ID: '.$ctrl_num.', Unable to auto-handle case where holdings text requires replacement: '.$holdings);
		$replaced = 0;
	} else {
		$map_ref->{$tmp_num} = $replace_text;
		$holdings =~ s/$replace_text/$tmp_num/;
		$replaced = 1;
	}

	return ($holdings, $replaced);
}

# determines whether or not to display error text
sub display_error() {
	my ($concerns) = @_;

	my ($display_error, $concern);

	$display_error = (&has_user_gen_concern($concerns)) ? 0 : 1;
	
	return $display_error;
}

# determines whether any non auto-generated concerns are present; based on included types in the ignore_concerns file
sub has_user_gen_concern() {
	my ($concerns) = @_;

	my ($has_user_gen_concern, $concern);

	# TODO: potentially update hasConcern sub in postProcess script when new concerns added

	$has_user_gen_concern = 0;
	if (defined($concerns) && $concerns ne '') {
		foreach $concern (split(/\;\s*/, $concerns)) {
			# TODO: create hash to track auto-generated concerns
			$has_user_gen_concern = 1
			  if ($concern ne 'Concatenateable' && $concern ne 'Non-concatenateable' &&
			      $concern ne 'Gaps acceptable' && $concern ne 'Gaps not acceptable' &&
			      $concern ne 'Acceptable enumeration');
		}
	}
	
	return $has_user_gen_concern;
}
