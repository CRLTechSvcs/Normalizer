#!/usr/bin/perl
         
use warnings;
use strict;

use CRL::Utilities qw(:all);
use File::Path qw(make_path);

use NormalizerDev::tests qw(:all);


my ($proj, $log_dir, $out_dir,
	$error_file, $warning_file, $debug_file, $log_file, $supp_file, $index_file, $series_info_file,
	$err_fh, $warn_fh, $debug_fh, $log_fh, $supp_fh, $index_fh, $series_info_fh,
	$in_record, $line, $field, $value, $field_type,
    $curr_ldr, $curr_ctrl_num, $curr_oclc, $backup_oclc, $file, $key,
    $new_oclc, $oclc_from_001, $oclc_from_035);
my (@series_info);
my (%flags, %fh, %curr_record, %recs_lacking_vols, %addl_fields);

# TODO: retrieve flags from command-line
$flags{'remove_lacks'} = 1;
$flags{'remove_wants'} = 0;

# TODO: parameterize additional fields
$addl_fields{'022'} = 1;

# TODO: get $proj from command-line
$proj = 'project/extract';

# define and create output directories
$proj = &crl_get_date_time('sortable')
  if (!defined($proj) || $proj eq '');
$log_dir = $proj.'/logs/';
make_path($log_dir);
$out_dir = $proj.'/output/';
make_path($out_dir);

# determine output file names & locations
$error_file = $log_dir.'error.log';
$warning_file = $log_dir.'warning.log';
$debug_file = $log_dir.'debug.log';
$log_file = $log_dir.'info.log';
$supp_file = $out_dir.'supp.txt';
$index_file = $out_dir.'index.txt';
$series_info_file = $out_dir.'series_info.txt';

# open files for output
open($err_fh, '>', $error_file);
open($warn_fh, '>', $warning_file);
open($debug_fh, '>', $debug_file);
open($log_fh, '>', $log_file);
open($supp_fh, '>', $supp_file);
open($index_fh, '>', $index_file);
open($series_info_fh, '>', $series_info_file);

# add file handles to hash by type
$fh{'ERROR'} = $err_fh;
$fh{'WARNING'} = $warn_fh;
$fh{'DEBUG'} = $debug_fh;
$fh{'LOG'} = $log_fh;
$fh{'SUPP'} = $supp_fh;
$fh{'INDEX'} = $index_fh;
$fh{'SERIES'} = $series_info_fh;

# process file from STDIN
$in_record = 0;
$curr_ldr = '';
$curr_ctrl_num = '';
$curr_oclc = '';
$backup_oclc = '';
$oclc_from_001 = 0;
$oclc_from_035 = 0;
while(<STDIN>) {
	$line = $_;
	$line =~ s/\s+$//;

	# split into field (=LDR, =245, etc.) and value
	$line =~ m/^([^\s]+)\s+(.*)$/;
	($field, $value) = ($1, $2);

	if ($line eq '') {
		# end of record
		$in_record = 0;
	} elsif ($field eq '=LDR') {
		# start of new record

		&crl_print_err($fh{'ERROR'}, 'Improper spacing before line '.$..': '.$line)
		  if ($in_record);

		# print extracted data for previous record
		$curr_oclc = $backup_oclc
		  if ($curr_oclc eq '' && $backup_oclc ne '');
		if (scalar(keys %curr_record)) {
			&print_extracted_data(\%curr_record, \%fh, $curr_ldr, $curr_oclc, \%addl_fields);

			# handle new series identifiers
			if (scalar(@series_info)) {
				&crl_print_line($fh{'SERIES'}, $curr_ctrl_num."\t".join(', ',@series_info));
				@series_info = ();
			}

			undef %curr_record;
			$curr_ctrl_num = '';
			$curr_oclc = '';
			$backup_oclc = '';
		}

		# current LDR
		$curr_ldr = $value;

		$in_record = 1;
	} elsif ($field =~ m/^=(\d{3})$/) {
		# current field of record
		$field_type = $1;
		&crl_print_err($fh{'ERROR'}, 'Improper spacing before line '.$..': '.$line)
		  if (!$in_record);
		if ($field_type eq '001') {
			# control field
			#&crl_print_err($fh{'ERROR'}, 'OCLC contains multiple integers at line '.$..': '.$line)
			#  if ($value =~ m/\d+[^\d]+\d+/);
			#$value =~ s/[^\d]+//g;
			if ($value =~ m/^oc[lmn]\d+$/) {
				$curr_oclc = $value;
				$oclc_from_001++
			} else {
				$backup_oclc = $value;
			}
			$curr_ctrl_num = $value;
			&store_field_value(\%curr_record, $field_type, $value, 0, 0);
		} elsif ($field_type eq '035') {
			# system control field
			($new_oclc) = &process_system_control_line(\%curr_record, $curr_oclc, \%fh, $field_type, $value);
			$oclc_from_035++
			  if ($curr_oclc ne $new_oclc);
			$curr_oclc = $new_oclc;
		} elsif ($field_type eq '310') {
			# current frequency
			&store_field_value(\%curr_record, $field_type, $value, 1, 0);
		} elsif ($field_type eq '321') {
			# former frequency
			&store_field_value(\%curr_record, $field_type, $value, 1, 1);
		} elsif ($field_type eq '590') {
			# holdings
		    if (($value =~ /index/i || $value =~ /supp/i) && $value !~ /;/) {
				# TODO: restore this?
		        #$value =~ s/,/;/g;
		    }
			&process_holdings_line(\%curr_record, \%flags, \%fh, \%recs_lacking_vols, \@series_info, $curr_ctrl_num, $field_type, $value);
		} elsif (exists($addl_fields{$field_type})) {
			# additional fields to maintain
			&store_field_value(\%curr_record, $field_type, $value, 1, 0);
		}
	} elsif ($field =~ m/^\#/) {
		# manually edited to ignore/skip content
	} else {
		&crl_print_err($fh{'ERROR'}, 'Unrecognized input at line '.$..': '.$line);
	}
}

# print extracted data for last record
$curr_oclc = $backup_oclc
  if ($curr_oclc eq '' && $backup_oclc ne '');
if (scalar(keys %curr_record)) {
	&print_extracted_data(\%curr_record, \%fh, $curr_ldr, $curr_oclc, \%addl_fields);

	# handle new series identifiers
	if (scalar(@series_info)) {
		&crl_print_line($fh{'SERIES'}, $curr_ctrl_num."\t".join(', ',@series_info));
		@series_info = ();
	}

	undef %curr_record;
}

&crl_print_err($fh{'ERROR'}, 'OCLC retrieved from field 001 for some records and from field 035 for others')
  if (scalar($oclc_from_001) && scalar($oclc_from_035));

# keep track of records with lacking volume info
if (scalar(keys %recs_lacking_vols)) {
	$file = $out_dir.'records_lacking_volumes.txt';
	open(FILE, ">$file") or &crl_exit_err('Could not open file for output: '.$file.','.$!);
	foreach $key (keys %recs_lacking_vols) {
		print FILE $key.&crl_get_EOL();
	}
	close(FILE);
}

# close output files
close_files($index_fh, $supp_fh, $series_info_fh);

# log warning for supplements and/or indexes
&crl_print_warning($fh{'WARNING'}, 'Input file contains lines with supplements, available at '.$supp_file)
  if (-s $supp_file);
&crl_print_warning($fh{'WARNING'}, 'Input file contains lines with indexes, available at '.$index_file)
  if (-s $index_file);

# close remaining files
close_files($log_fh, $debug_fh, $warn_fh, $err_fh);

exit 0;


# stores value(s) of type field_type in data ref
sub store_field_value {
	my ($data_ref, $field_type, $value, $remove_indicators, $allow_multiline) = @_;

	$value =~ s/^..//
	  if ($remove_indicators);

	if ($allow_multiline && exists($data_ref->{$field_type})) {
		$data_ref->{$field_type} = $data_ref->{$field_type}.'; '.$value;
	} else {
		$data_ref->{$field_type} = $value;
	}
}

# specialized processing for field type 035 (system control number)
sub process_system_control_line {
	my ($curr_record_ref, $curr_oclc, $fh_ref, $field_type, $value) = @_;

	my ($curr_oclc_num, $system_ctrl_num);

	$curr_oclc_num = $curr_oclc;
	$curr_oclc_num =~ s/^oc[lmn]//;
	$curr_oclc_num =~ s/^0+//;

	$system_ctrl_num = &crl_get_subfield($value, '\$', 'a');
	if ($system_ctrl_num =~ m/^\(OCoLC\)((?:oc[lmn])?(\d+))$/ || $system_ctrl_num =~ m/^(oc[lmn](\d+))$/) {
		if ($curr_oclc eq '') {
			$curr_oclc = $1;
			&store_field_value($curr_record_ref, $field_type, $curr_oclc, 0, 0);
		} elsif ($curr_oclc ne $1 && $curr_oclc_num ne $2) {
			&crl_print_warning($fh_ref->{'WARNING'}, 'OCLC: '.$curr_oclc.', Second OCLC number present in system control line: '.$value);
		}
	}

	return $curr_oclc;
}

# specialized processing for field type 590 (holdings)
sub process_holdings_line { 
	my ($data_ref, $flags_ref, $fh_ref, $lack_ref, $series_info_ref, $ctrl_num, $field_type, $value) = @_;
    trace_run("process_holdings_line in", $value);
	my ($has_supp, $has_index) = (0,0);

	$value =~ s/^..//;
	if ($value !~ m/^\$aCenter(\'s)? (has|holdings begin with)[\.:]?$/i) {
		$value =~ s/\s*;\s*$//;
	
		# remove subfield variable name
		$value =~ s/\$a//g;

		# remove standard call numbers
		$value =~ s/^\s*[A-GJ]\-[0-9]+[A-Z]?\s*//gi;
		$value =~ s/\|[A-GJ]\-[0-9]+[A-Z]?\s*//gi;

		# remove other call numbers
		$value =~ s/^\s*2[A-Z][\dA-Z]{1,2}\s*//;
		$value =~ s/^\s*5\/\d{2}\/[A-Z][\dA-Z]{1,2}(\-\d|\/[a-z])?\s*//;
		$value =~ s/^\s*7[A-Z][\dA-Z]{1,2}(\/c|:\d)?\s*//;

		# remove microfilm information
		# TODO: do not always remove holdings info entirely (create var. that contains .*$ portion of regex?)
		$value =~ s/^(Neg\.?\s*)?MF\-\d+\s*(r.\d+(\-\d+)?|\([^\)]*reel[^\)]*\)?)?.*$//i;

		# remove lacks statements; save info for later use
		if ($flags_ref->{'remove_lacks'} && $value =~ m/lack/i) {
			$lack_ref->{$ctrl_num}++;
			$value =~ s/\;?\s*\(?lack.*$//i; 
		}

		# remove wants statements; save info for later use
		if ($flags_ref->{'remove_wants'} && $value =~ m/^WANTS?:?\s+/i) {
			if ($ctrl_num ne '') {
				$lack_ref->{$ctrl_num}++;
			} else {
				# record only includes wants; no need to track
			}
			$value = ''; 
		}

		# remove cat info
		$value =~ s/\s*(in)?\s*cat\.? ?[bc]\.?\s*/ /i;

		# remove starting identifiers?
		$value =~ s/^[\/\\]c\s*//g;
		$value =~ s/^[\/\\]e\s*//g;
		if ($value =~ m/^[\/\\]m\s*/) {
			&crl_print_warning($fh_ref->{'WARNING'}, 'ID: '.$ctrl_num.', Investigate missing holdings: '.$value);
			$value = '';
		}

		# fix case where no. is not explicitly listed for every number (i.e. v.12, no. 3, 5, 6)
		#$value = &add_num_IDs_to_holdings($value, $fh_ref);

		# remove spaces around - characters
		$value =~ s/\s*\-\s*/-/g;

		# ensure there is a space before every '(' character
		$value =~ s/\s*\(/ (/g;
		
		# remove () around number identifiers
		$value =~ s/ \((no\.[^\)]+)\)/, $1/g;

        # NPF -- expand supplement segment
		if ($value =~ m/supp|map/i) {
            my $supplement;
            ($value, $supplement) = process_supplement_index_line($value, 'supplement');
			
			# print info to separate file for later processing
			if ($supplement) {
                $has_supp = 1;
                &crl_print_line($fh_ref->{'SUPP'}, $ctrl_num."\t".$supplement);
            }
		}
		
		if ($value && $value =~ m/index/i) {
            my $index;
            ($value, $index) = process_supplement_index_line($value, 'index');
            if ($index) {
                $has_index = 1;
                # print info to separate file for later processing
                &crl_print_line($fh_ref->{'INDEX'}, $ctrl_num."\t".$index);
            }
		}

		if ($value && $value !~ m/^\s*$/) {

			# compile list of various errors
			&crl_print_err($fh_ref->{'ERROR'}, 'ID: '.$ctrl_num.', Holdings line contains missing no. identifier: '.$value)
			  if ($value =~ m/no\.\s*\d{1,3}\s*\-\s*\d{4}/);

			&crl_print_err($fh_ref->{'ERROR'}, 'ID: '.$ctrl_num.', Holdings line contains bad sets: '.$value)
			  if ($value =~ m/^(?:v|no|pt)\.\s*\d+(?:\s*\-\s*\d+)?\s*,\s*\d+/ || $value =~ m/(?:[^o]v|no|[^e]pt)\.\s*\d+(?:\s*\-\s*\d+)?\s*,\s*\d+/);

			&crl_print_err($fh_ref->{'ERROR'}, 'ID: '.$ctrl_num.', Holdings line contains improper range: '.$value)
			  if ($value =~ m/\d+[^\s]*\-[^\s]*\d+[^\s]*\-/);

			&crl_print_err($fh_ref->{'ERROR'}, 'ID: '.$ctrl_num.', Holdings line contains date portion with multiple - characters: '.$value)
			  if ($value =~ m/\([^\)]*\-[^\)]*\-[^\)]*\)/);

			&crl_print_err($fh_ref->{'ERROR'}, 'ID: '.$ctrl_num.', Holdings line contains years separated by , characters: '.$value)
			  if ($value =~ m/\(.*\d{4}\s*,\s*\d{4}/);

			&crl_print_err($fh_ref->{'ERROR'}, 'ID: '.$ctrl_num.', Holdings line contains pages: '.$value)
			  if ($value =~ m/p(p|g)/i);


			# compile list of warnings that need resolution
			&crl_print_warning($fh_ref->{'WARNING'}, 'ID: '.$ctrl_num.', Holdings line contains unspecific data: '.$value)
			  if ($value =~ m/\?/);

			&crl_print_warning($fh_ref->{'WARNING'}, 'ID: '.$ctrl_num.', Joined set potentially too broad: '.$value)
			  if ($value =~ m/(\d+)\/(\d+)/ && $2 >= $1 + 10);

			&crl_print_warning($fh_ref->{'WARNING'}, 'ID: '.$ctrl_num.', Holdings line contains special issue; should it be a supplement?: '.$value)
			  if ($value =~ m/special\s*issue/i);

			&crl_print_warning($fh_ref->{'WARNING'}, 'ID: '.$ctrl_num.', Holdings line contains text "'.$1.'": '.$value)
			  if ($value =~ m/(bound|folio|inc)/i);

			# letters in the regex below match the following: months, seasons, v, volume, no and pt
			&crl_print_warning($fh_ref->{'WARNING'}, 'ID: '.$ctrl_num.', Holdings line contains unexpected text: '.$value)
			  if ($value =~ m/[^ABDFJMNOSVWabcdefghilmnoprstuvwy\d\s\.\,\-\(\)\/\;\:]/);


			# compile list of potential warnings that MAY need resolution
			if ($value =~ m/^pt/i || $value =~ m/[^e]pt/i) {
				if ($value =~ m/pt\.?\s*(\d+)?[a-z]/i) {
					&crl_print_warning($fh_ref->{'WARNING'}, 'ID: '.$ctrl_num.', Holdings line contains parts with letters: '.$value);
				} else {
					&crl_print_warning($fh_ref->{'WARNING'}, 'ID: '.$ctrl_num.', Holdings line contains parts: '.$value);
				}
			}

			&crl_print_warning($fh_ref->{'WARNING'}, 'ID: '.$ctrl_num.', Holdings line contains long string of non-digits: '.$value)
			  if ($value =~ m/[^\d]{10}/i);

			&crl_print_warning($fh_ref->{'WARNING'}, 'ID: '.$ctrl_num.', Holdings line contains more than 1 consecutive space character: '.$value)
			  if ($value =~ m/  /i);

			&crl_print_warning($fh_ref->{'WARNING'}, 'ID: '.$ctrl_num.', Holdings line contains numbers in ordinal form: '.$value)
			  if ($value =~ m/\d+((st)|(n?d)|(rd)|(th))\s+[^s]/);

            # NPF -- German series designation
            $value =~ s/Reihe/ser\./gi;
			# handle new series identifiers
			if ($value =~ m/ser/i || $value =~ m/n\.s\./) {
				# save off order of new series identifiers (by control number)
				# replace with n.s.
                # TODO: series handling needs to be fixed, here and in QC scripts
				# NPF: replaced the following while loop with non-destructive gathering of series data
                #while ($value =~ s/(ser(?:ies)?\.?\s*\d+|\d+[a-z]{1,2}\s+ser\.?|new\s+ser\.?|n\.s\.(?:\d+)?)[:,]?\s*/Ns_Ph /i) {
					# save info for later processing
				#	push(@{$series_info_ref}, $1);
				#}
                my @found_series_info = m/(ser(?:ies)?\.?\s*\d+|\d+[a-z]{1,2}\s+ser\.?|new\s+ser\.?|n\.s\.(?:\d+)?)[:,]?\s*/gi;
                push(@{$series_info_ref}, @found_series_info);
				$value =~ s/Ns_Ph/n\.s\./g;
				$value =~ s/n\.s\.\s*n\.s\./n.s.; n.s./g;
			}
			&crl_print_warning($fh_ref->{'WARNING'}, 'ID: '.$ctrl_num.', Holdings line contains new series without a proper identifier: '.$value) if ($value =~ m/ser/i);

			# replace commas with semicolons in cases where the normalizer will handle the holdings string badly
            if ($value =~ m/^(\d+(\/\d+)?\s*(\-(\s*\d+(\/\d+)?)?)?\s*,\s*)+\d+(\/\d+)?\s*(\-(\s*\d+(\/\d+)?)?)?$/ ||
                $value =~ m/^(no.\s*\d+(\/\d+)?(\s*\-\s*\d+(\/\d+)?)?(\s+\(?\d+(\/\d+)?\s*(\-(\s*\d+(\/\d+)?)?)?\)?)?\s*,\s*)+no.\s*\d+(\/\d+)?(\s*\-\s*\d+(\/\d+)?)?(\s+\(?\d+(\/\d+)?\s*(\-(\s*\d+(\/\d+)?)?)?\)?)?$/i ||
                $value =~ m/^[a-z]{3,6}\.?(\/[a-z]{3,6}\.?)? \d{4}(\d{2,4})?(,\s*[a-z]{3,6}\.?(\/[a-z]{3,6}\.?)? \d{4}(\d{2,4})?)+$/i ||
                $value =~ m/^\d{4}([\:\s][a-z]{3,6}\.?)?(\s*\-\s*\d{4}([\:\s][a-z]{3,6}\.?)?)?(,\s*\d{4}([\:\s][a-z]{3,6}\.?)?(\s*\-\s*\d{4}([\:\s][a-z]{3,6}\.?)?)?)+$/i) {
                    $value =~ s/,\s*/; /g;
                }
			while ($value =~ m/\)\s*([^\-\;\s])\s*/) {
				my $replace = '';
				$replace = $1 if ($1 ne ',');
				$value =~ s/\)\s*[^\-\;\s]\s*/); $replace/;
			}
			$value =~ s/,\s*n\.s\./; n.s./g;

			&store_field_value($data_ref, $field_type, $value, 0, 1);
		}
	}
    trace_run("process_holdings_line out", $value);
}

# adds no. identifier within holdings string to individual numbers and sets that are missing it
sub add_num_IDs_to_holdings {
	my ($holdings, $fh_ref) = @_;

	# TODO: expand to separate holdings by vol/num/date sets

	#my ($orig_holdings, $first_section, $second_section, $second_num);

	#$orig_holdings = $holdings;
	#while ($holdings =~ m/(no\.\s*\d+(?:\s*\-\s*\d+)?)(\s*,\s*(\d+))/) {
	#	($first_section, $second_section, $second_num) = ($1, $2, $3);
	#	$holdings =~ s/$first_section$second_section/$first_section, no. $second_num/;
	#}

	#if ($orig_holdings ne $holdings) {
	#	print STDERR 'O: '.$orig_holdings.&crl_get_EOL();
	#	print STDERR 'N: '.$holdings.&crl_get_EOL();
	#	print STDERR &crl_get_EOL();
	#}

	return $holdings;
}

# prints subset of marc data in preparation for normalization
sub print_extracted_data {
	my ($data_ref, $fh_ref, $ldr, $oclc, $addl_fields_ref) = @_;

	my ($id);

	# handle missing identifying info
	if (!exists($data_ref->{'001'}) || $data_ref->{'001'} eq '') {
		if ($ldr eq '') {
			&crl_print_err($fh_ref->{'ERROR'}, 'Record does not contain any identifying information');
		} else {
			&crl_print_err($fh_ref->{'ERROR'}, 'Record does not contain a control number: '.$ldr);
		}
		$id = 'LDR: '.$ldr;
	} else {
		$id = 'Control number: '.$data_ref->{'001'};
	}

	if (!exists($data_ref->{'590'})) {
		# do not print since no holdings to normalize; display warning for verification
		&crl_print_warning($fh_ref->{'WARNING'}, 'Record does not contain any valid holdings, '.$id);
	} else {
		print $data_ref->{'001'} if (exists($data_ref->{'001'}));
		print "\t";
		print $data_ref->{'310'} if (exists($data_ref->{'310'}));
		print "\t";
		print $data_ref->{'321'} if (exists($data_ref->{'321'}));
		print "\t";
		print $data_ref->{'590'} if (exists($data_ref->{'590'}));
		print "\t";
		print $oclc if ($oclc ne '');
		foreach $field_type (sort {$a cmp $b} keys(%{$addl_fields_ref})) {
			print "\t";
			print $data_ref->{$field_type} if (exists($data_ref->{$field_type}));
		}
		print &crl_get_EOL();
	}
}


sub close_files {
    my @fhs = @_;
    foreach my $fh (@fhs) {
        close $fh 
          or &crl_exit_err('Could not open file for output: '.$fh.','.$!);
    }
}


sub process_supplement_index_line {
    my ($value, $check_type) = @_;
    
    my @regular_segments;
    my @special_segments;
    my ($regular_output, $special_output);
    
    my @segments;
	if ($value !~ /;/) {
		@segments = split(',', $value);
	}
	else {
		@segments = split(';', $value);
	}

    foreach my $seg (@segments) {
        if ($check_type eq 'supplement' && $seg =~ /supp/i 
                                        || $seg =~ /^ *map/i
                                        || $seg =~ /^ e?spec/i) {
            push(@special_segments, $seg);
        }
        elsif ($check_type eq 'index' && $seg =~ /index/i) {
            push(@special_segments, $seg);
        }
        else {
            push(@regular_segments, $seg);
        }
    }
    $regular_output = join('; ', @regular_segments) if scalar @regular_segments >= 1;
    $special_output= join('; ', @special_segments) if scalar @special_segments >= 1;
    
    return($regular_output, $special_output);
}


# ----------------------------------------------------------------------
