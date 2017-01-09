package Normalizer::sort_holdings;

use strict;
use warnings;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        compare_holdings
        sort_holdings
        subsort_holdings
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

sub sort_holdings {
	my ($holdings, $ctrl_num, $fh_ref) = @_;
    trace_run('sort_holdings in', $holdings);
	my ($new_holdings, $last_start, $curr_holdings, $curr_start, $sorted_holdings);
	my (@holdings_to_sort);
    
	$new_holdings = '';
	$last_start = '';
	foreach $curr_holdings (split(/\s*,\s*/, $holdings)) {
		if ($curr_holdings =~ m/^v\./) {
			$curr_start = 'v.';
		} elsif ($curr_holdings =~ m/^no\./) {
			$curr_start = 'no.';
		} elsif ($curr_holdings =~ m/^pt\./) {
			$curr_start = 'pt.';
		} elsif ($curr_holdings =~ m/^\s*\(/) {
			$curr_start = '(';
		} elsif ($curr_holdings =~ m/^\d{4}\:/) {
			$curr_start = 'year';
		} elsif ($curr_holdings =~ m/^n\.s\./) {
			# holdings contains new series; will have to be sorted manually
			return $holdings;
		} else {
			&crl_print_warning($fh_ref->{'WARNING'}, 'ID: '.$ctrl_num.', Unrecognized holdings format for sorting method: '.$curr_holdings);
			return $holdings;
		}

		if ($last_start eq '' || $last_start eq $curr_start) {
			push(@holdings_to_sort, $curr_holdings);
			$last_start = $curr_start;
		} else {
			$sorted_holdings = &subsort_holdings(\@holdings_to_sort, $curr_holdings, $last_start);
			$new_holdings = ($new_holdings eq '') ? $sorted_holdings : join(', ', $new_holdings, $sorted_holdings);
			@holdings_to_sort = ();
			$last_start = '';
		}
	}
	if (scalar(@holdings_to_sort)) {
		$sorted_holdings = &subsort_holdings(\@holdings_to_sort, '', $last_start);
		$new_holdings = ($new_holdings eq '') ? $sorted_holdings : join(', ', $new_holdings, $sorted_holdings);
	}

	return $new_holdings;
}

sub subsort_holdings {
	my ($holdings_ref, $curr_holdings, $last_start) = @_;

	my ($num_holdings, $sorted_holdings);

	$num_holdings = scalar(@{$holdings_ref});
	if ($num_holdings > 1) {
		if ($curr_holdings ne '') {
			$sorted_holdings = join(', ', sort {&compare_holdings($a, $b, $last_start)} @{$holdings_ref}[0..$num_holdings-2]);
			$sorted_holdings = join(', ', $sorted_holdings, @{$holdings_ref}[$num_holdings-1]);
			$sorted_holdings = join(', ', $sorted_holdings, $curr_holdings);
		} else {
			$sorted_holdings = join(', ', sort {&compare_holdings($a, $b, $last_start)} @{$holdings_ref}[0..$num_holdings-1]);
		}
	} elsif ($num_holdings == 1) {
		if ($curr_holdings ne '') {
			$sorted_holdings = join(', ', @{$holdings_ref}[0], $curr_holdings);
		} else {
			$sorted_holdings = @{$holdings_ref}[0];
		}
	} else {
		$sorted_holdings = $curr_holdings;
	}

	return $sorted_holdings;
}

sub compare_holdings {
	my ($a, $b, $last_start) = @_;

	my ($a_num, $b_num);

	# handle potential space before ( character
	$last_start =~ s/\(/\\s*\\(/;

	# remove first caption
	$a =~ s/^$last_start//;
	$b =~ s/^$last_start//;

	if ($last_start eq 'v.') {
		# attempt to retrieve number in addition to volume, in order to process secondary sort
		$a =~ m/^(\d+)(?::no\.(\d+))?/;
		($a, $a_num) = ($1, $2);
		$b =~ m/^(\d+)(?::no\.(\d+))?/;
		($b, $b_num) = ($1, $2);
	} elsif ($last_start eq 'year') {
		# attempt to retrieve number or part in addition to date, in order to process secondary sort
		$a =~ m/^(\d+)(?::(?:(?:no)|(?:pt))\.(\d+))?/;
		($a, $a_num) = ($1, $2);
		$b =~ m/^(\d+)(?::(?:(?:no)|(?:pt))\.(\d+))?/;
		($b, $b_num) = ($1, $2);
	} else {
		# retrieve first number ( for caption)
		$a =~ s/^(\d+).*$/$1/;
		$b =~ s/^(\d+).*$/$1/;
	}

	if (defined($a_num) && defined($b_num)) {
		# attempt secondary sort on number, when volume is the same
		$a <=> $b || $a_num <=> $b_num;
	} elsif (defined $a && defined $b && $a =~ m/^\d+$/ && $b =~ m/^\d+$/) {
		# only sort volumes, numbers or years for now (does not handle dates with months)
		$a <=> $b;
	}
}


1;
