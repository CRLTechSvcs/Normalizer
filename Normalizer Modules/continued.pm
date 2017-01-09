package Normalizer::continued;

# TODO:
#use strict;
#use warnings;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        continued
    );
    %EXPORT_TAGS = ('all' => \@EXPORT_OK);
}
binmode(STDOUT, ":encoding(utf8)");     #treat as if it is UTF-8
binmode(STDIN, ":encoding(utf8)");      #actually check if it is UTF-8W
binmode(STDERR, ":encoding(utf8)");

use open ':std', ':encoding(UTF-8)';

use utf8;
use v5.14;

sub continued {
	my $final = shift;
    
	$final =~ s/ -/-/g;
	$final =~ s/ [0-9]{1,2}\)/-/g;
	$final =~ s/\)-.*/-/g;
	$final =~ s/(:[0-9]{1,2})\)/$1-/g;

	if($final =~ m/[0-9]{4}:no\.[0-9]{1,3}\/*[0-9]{0,3}-[0-9]{4}:no\.[0-9]{1,3}\/*[0-9]{0,3}/g){
		$final =~ s/([0-9]{4}:no\.[0-9]{1,3}-)[0-9]{4}:no\.[0-9]{1,3}/$1/g
	}
	elsif ($final =~ m/[0-9]{4}:no\.[0-9]{1,3}\/*[0-9]{0,3}-[0-9]{1,3}\/*[0-9]{0,3}/g){
		$final =~ s/([0-9]{4}:no\.[0-9]{1,3}\/*[0-9]{0,3}-)[0-9]{1,3}\/*[0-9]{0,3}/$1/g
	}
	else{
		$final =~ s/-v\.[0-9]{1,3}:no\.[0-9]{1,3}\/*[0-9]{0,3}/-/g;
		$final =~ s/([A-Za-z]{3,4})-[A-Za-z]{3,4}\/*[A-Za-z]{0,6}/$1/g;
		if ($final =~ m/\([0-9]{4}\/*[0-9]{0,4}-[0-9]{4}\/*[0-9]{0,4}\)/g){
			$final =~ s/(\([0-9]{4}\/*[0-9]{0,4}-)[0-9]{4}\/*[0-9]{0,4}\)/$1/g;
		}
		elsif ($final =~ m/\(.*[0-9]{4}\/*[0-9]{0,4}-.*[0-9]{4}\/*[0-9]{0,4}\)/g){
			$final =~ s/(\(.*[0-9]{4}\/*[0-9]{0,4}-).*[0-9]{4}\/*[0-9]{0,4}\)/$1/g;
		}
		elsif ($final =~ m/\(.*[0-9]{4}\/*[0-9]{0,4}\)/g){
			$final =~ s/(\(.*[0-9]{4}\/*[0-9]{0,4})\)/$1-/g;
		}
		if ($final =~ m/no\.[0-9]{1,3}-[0-9]{1,3}/g){
			$final =~ s/(v\.[0-9]{1,3}\/*[0-9]{0,3}-)v\.[0-9]{1,3}\/*[0-9]{0,3}/$1/g;
			$final =~ s/(no\.[0-9]{1,3}-)[0-9]{1,3}/$1/g;
		} elsif ($final =~ m/no\.[0-9]{1,3}/g){
			if ($final =~ m/v\.[0-9]{1,3}\/*[0-9]{0,3}-v\.[0-9]{1,3}\/*[0-9]{0,3}/g){
				$final =~ s/(v\.[0-9]{1,3}-)v\.[0-9]{1,3}/$1/g;
			} elsif ($final =~ m/v\.[0-9]{1,3}/g){
				$final =~ s/(v\.[0-9]{1,3})/$1-/g;
			}
			$final =~ s/(no\.[0-9]{1,3})/$1/g;
		} else {
			if ($final =~ m/v\.[0-9]{1,3}\/*[0-9]{0,3}-v\.[0-9]{1,3}\/*[0-9]{0,3}/g){
				$final =~ s/(v\.[0-9]{1,3}\/*[0-9]{0,3}-)v\.[0-9]{1,3}\/*[0-9]{0,3}/$1/g;
			} elsif ($final =~ m/v\.[0-9]{1,3}/g){
				$final =~ s/(v\.[0-9]{1,3})/$1-/g;
			}
			$final =~ s/--:v\.[0-9]{1,3}--/-/g;
			$final =~ s/--:/-/g;
			$final =~ s/-:/-/g;
			$final =~ s/:-/-/g;
			$final =~ s/--/-/g;
		}
		$final =~ s/:no\.1\/2-/-/g;
		$final =~ s/:no\.1-/-/g;
		$final =~ s/--/-/g;
	}
	
	$final =~ s/\((n\.d\.-)[^\)]*/\($1/g;
	$final =~ s/(\([^-]*-)[^\)]*/$1/g;
	$final =~ s/(\([0-9]{4}:[A-Za-z]{3,6}:[0-9]{1,2}-).*/$1/g;
	$final =~ s/(pt\.[0-9]{1,3}-)[0-9]{1,3}/$1/g;
	$final =~ s/v\.$//g;
	$final =~ s/-[A-Za-z]{3,6}\/*[A-Za-z]{0,6} [0-9]{4}\/*[0-9]{0,4}\)/-/g;
	$final =~ s/-[0-9]{4}\/*[0-9]{0,4}:[A-Za-z]{3,6}:[0-9]{1,2}\)/-/g;
	$final =~ s/(\([0-9]{4}\/*[0-9]{0,4}-)[0-9]{4}\/*[0-9]{0,4}-/$1/g;
	$final =~ s/(:no\.[0-9]{1,3}\/*[0-9]{0,3}-)[0-9]{1,3}\/*[0-9]{0,3}/$1/g;
	$final =~ s/([A-Za-z]{3,4})-[A-Za-z]{3,4}\/*[A-Za-z]{0,6}/$1/g;
	$final =~ s/(v\.[0-9]{1,3})-(:no\.[0-9]{1,3}\/*[0-9]{0,3}-)/$1$2/g;
	$final =~ s/(no\.[0-9]{1,3}-)v\.[0-9]{0,3}\/*[0-9]{0,3}/$1/g;
	$final =~ s/-v\. /- /g;
	$final =~ s/v\.([0-9]{1,3})-(\/[0-9]{1,3})/v\.$1$2-/g;
	$final =~ s/no\.([0-9]{1,3})-(\/[0-9]{1,3})/no\.$1$2-/g;
	$final =~ s/(v\.\d+)-(:no\.\d+) /$1$2- /g;
	$final =~ s/(v\.\d+)-(:no\.\d+\/\d+)+ /$1$2- /g;
	$final =~ s/(v\.\d+)-(:no\.\d+\/\d+)+ /$1$2- /g;
	$final =~ s/(v\.\d+)-\(/$1- \(/g;
	$final =~ s/(v\.\d+-)no\. /$1 /g;
	$final =~ s/(no\.\d+-)no\.\d+ /$1 /g;
	$final =~ s/--/-/g;
	$final =~ s/(v\.[0-9]{1,3}\/*[0-9]{0,3}-)v\.[0-9]{1,3}\/*[0-9]{0,3}/$1/g;
	$final =~ s/(v\.[0-9]{1,3}\/*[0-9]{0,3}-)[0-9]{1,3}\/*[0-9]{0,3}/$1/g;
	$final =~ s/(v\.[0-9]{1,3}\/*[0-9]{0,3}):no.1(-|\/\d+)/$1-/g;
	$final =~ s/\(Jan ([0-9]{4}\/*[0-9]{0,4}-)/\($1/g;
	$final =~ s/(v\.[0-9]{1,3}\/*[0-9]{0,3})-(pt\.[0-9]{1,3}-)/$1:$2/g;
	$final =~ s/(v\.[0-9]{1,3}\/*[0-9]{0,3})-(pt\.[0-9]{1,3})/$1-/g;
	$final =~ s/(v\.[0-9]{1,3}\/*[0-9]{0,3})\s*-*\s*(v\.[0-9]{1,3}\/*[0-9]{0,3})/$1-/g;
	$final =~ s/(no\.[0-9]{1,3}) /$1- /g;

	return $final;
}

1;
