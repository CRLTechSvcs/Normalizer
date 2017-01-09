package Normalizer::qc_normalize;

use strict;
use warnings;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        can_concat
        concat_prompt
        concat_set
        determine_gap
        gap_prompt
        has_concern
        is_valid_holdings_format
        post_process
        process_joined_set
        reset_max_num
        set_last_date
        validate_vols_and_nums
        vals_exist
    );
    %EXPORT_TAGS = ('all' => \@EXPORT_OK);
}

binmode(STDOUT, ":encoding(utf8)");     #treat as if it is UTF-8
binmode(STDIN, ":encoding(utf8)");      #actually check if it is UTF-8W
binmode(STDERR, ":encoding(utf8)");

use open ':std', ':encoding(UTF-8)';

use utf8;
use v5.14;

use CRL::Utilities qw(:all);
use Normalizer::tests qw(:all);


use Data::Dumper;

# TODO: Is there some way to convert this to a more general testing library?
#       At the moment, this is a 1200 line monolith with tests added to it
#       Any way to shrink it to more manageable and modilar size?

sub post_process {
    my ( $ctrl_num, $freq_ref, $input, $fh_ref, $opts_ref, $series_info_ref,
        $ignore_concerns_ref, $addl_fields_ref )
      = @_;
    trace_run('concat start', $input);
    my (
        $err_flag,           $err_msg,
        $run_concat,         $run_gaps,
        $series_info,        $series_number,
        $last_input_section, $input_section,
        $is_valid,           $is_valid_err_msg,
        $index,              $concat_holdings,
        $concern_string,     $concern_holdings_string,
        $last_ns_num,        $curr_ns_num
    );
    my (@series_info);
    my (%info);

    $err_flag = 0;
    $err_msg  = '';

    # retrieve parameter values
    $run_concat = $opts_ref->{'c'};
    $run_gaps   = $opts_ref->{'g'};

    # initialize info hash
    %info = (
        'last_holdings'             => '',
        'last_vol'                  => '',
        'last_num'                  => '',
        'last_part'                 => '',
        'last_date'                 => '',
        'last_new_series'           => 0,
        'last_date_as_vol'          => 0,
        'holdings_count'            => 0,
        'potential_standalone_date' => 0,
        'concerns'                  => '',
        'ns_count'                  => 0,
        'gaps'                      => {
            'process'      => $run_gaps,
            'prompt',      => !$opts_ref->{'p'},
            'gaps_allowed' => -1,
            'display'      => 1,
            'value'        => ''
        },
        'concat' => {
            'new_holdings' => '',
            'current_set'  => [],
            'skipped_ns'   => {},
            'last_vol'     => '',
            'last_num'     => '',
            'last_part'    => '',
            'last_date'    => '',
            'process'      => $run_concat,
            'orig'         => {
                'concat'    => 0,
                'nonconcat' => 0
            },
            'new' => {
                'concat'             => 0,
                'nonconcat'          => 0,
                'nonconcat_holdings' => []
            }
        }
    );

    # get original values from ignore concerns
    $info{'concerns'} = $ignore_concerns_ref->{$ctrl_num}
      if ( defined( $ignore_concerns_ref->{$ctrl_num} ) );
    $info{'concat'}->{'orig'}->{'concat'} =
      &has_concern( $info{'concerns'}, 'concat' );
    $info{'concat'}->{'orig'}->{'nonconcat'} =
      &has_concern( $info{'concerns'}, 'nonconcat' );

    $info{'gaps'}->{'prompt'} = 0
      if ( &has_concern( $info{'concerns'}, 'gaps' ) );
    if ( &has_concern( $info{'concerns'}, 'no_gaps' ) ) {
        $info{'gaps'}->{'process'} = 0;
        $info{'gaps'}->{'display'} = 0;
    }

    # prepare new series for qc
    @series_info = split( /,\s*/, $series_info_ref->{$ctrl_num} )
      if ( exists( $series_info_ref->{$ctrl_num} ) );
    foreach $series_info (@series_info) {
        $series_number = $series_info;
        $series_number =~ s/[^\d]//g;
        $input =~ s/n\.s\./${series_number}Ns_Ph/;
    }
    # NPF : one following line is a shim to get around series issues with error reporting
    # TODO: Fix this issue
    # TODO: this whole thing seems unnecessary
    # TODO: series statements still often cause check failures
    $input =~ s/[Ss]er\.? ?(\d+)/$1Ns_Ph/g;
    $input =~ s/Ns_Ph/n\.s\./g;
    #$input =~ s/(\d+)n\.s\./ser\.$1/g;
    
    # ensure that some number exists (date, volume, number, page, etc.)
    ( $err_msg, $err_flag ) =
      &crl_append_error_msg( $err_msg, 'No numeric info included' )
      if ( $input !~ /\d/ );

    # verify each section independently
    $last_input_section = '';
    foreach $input_section ( split( /\s*,\s*/, $input ) ) {

        # ignore exact duplicates
        next if ( $input_section eq $last_input_section );

        # parenthesis starts with a lower case letter; indicates odd errors
        ( $err_msg, $err_flag ) =
          &crl_append_error_msg( $err_msg,
            'Parenthesis character followed by lower-case letter' )
          if ( $input_section =~ m/\([a-z]/ );

        # validate volumes and numbers
        ( $err_msg, $err_flag ) =
          &validate_vols_and_nums( $input_section, $err_msg, $err_flag );

        # check for other errors not previously encountered
        ( $is_valid, $is_valid_err_msg ) =
          &is_valid_holdings_format( $ctrl_num, $input_section, $freq_ref,
            $fh_ref, $opts_ref, \%info, \@series_info );
        ( $err_msg, $err_flag ) =
          &crl_append_error_msg( $err_msg,
            'Invalid format (' . $is_valid_err_msg . '): ' . $input_section )
          if ( !$is_valid );

        $info{'holdings_count'}++;
        $last_input_section = $input_section;
    }

    # handle concatenation of last set
    ( $is_valid, $is_valid_err_msg, $concat_holdings ) =
      &concat_set( \@{ $info{'concat'}->{'current_set'} },
        $fh_ref, $freq_ref->{'max_freq'}, \%info );
    ( $err_msg, $err_flag ) =
      &crl_append_error_msg( $err_msg,
        'Invalid concatenated format (' . $is_valid_err_msg . ')' )
      if ( !$is_valid );
    if ( $concat_holdings ne '' ) {
        if ( $info{'concat'}->{'new_holdings'} ne '' ) {
            $info{'concat'}->{'new_holdings'} =
              join( ', ', $info{'concat'}->{'new_holdings'}, $concat_holdings );
        }
        else {
            $info{'concat'}->{'new_holdings'} = $concat_holdings;
        }
    }

    # use concatenated holdings, when flag is set
    $input = $info{'concat'}{'new_holdings'}
      if ( $info{'concat'}{'process'} );
    
    # print out gaps report
    &crl_print_line( $fh_ref->{'GAPS'},
        join( "\t", $ctrl_num, $info{'gaps'}->{'value'}, @{$addl_fields_ref} ) )
      if ( $info{'gaps'}->{'value'} ne '' && $info{'gaps'}->{'display'} );

    #return series info to initial text
    $index       = 0;
    $last_ns_num = 0;
    foreach $series_info (@series_info) {
        if (   !$info{'concat'}{'process'}
            || !exists( $info{'concat'}{'skipped_ns'}{$index} ) )
        {
            # only process when applicable, regarding concatenation
            $series_info =~ s/n\.s\./Ns_Ph/;
            $input =~ m/(\d+)?n\.s\./;
            $curr_ns_num = ( defined($1) ) ? $1 : 1;
            say "SERIES INFO $series_info";
            if ( $curr_ns_num != $last_ns_num ) {
                $input =~ m/(,\s*)?(?:\d+)?n\.s\./;
                if ( defined($1) ) {
                    $input =~ s/,\s*(\d+)?n\.s\./; $series_info/;
                }
                else {
                    $input =~ s/(\d+)?n\.s\./$series_info/;
                }
            }
            else {
                $input =~ s/(\d+)?n\.s\./$series_info/;
            }
            $last_ns_num = $curr_ns_num;
        }
        $index++;
    }
    $input =~ s/Ns_Ph/n\.s\./g;

    # print warning for case where standalone date may need to be combined with previous statement
    &crl_print_warning( $fh_ref->{'WARNING'},
            'ID: '
          . $ctrl_num
          . ', Investigate standalone date (may need to be combined with previous statement): '
          . $input )
      if ( $info{'potential_standalone_date'} && $input =~ m/,/ );

    # reformat dates
    while ($input =~ m/(\d{4})\:([A-Z][a-z]{2})(?::(\d{1,2}))?/
        && &crl_get_month_num($2) != 0 )
    {
        if ( defined($3) ) {
            $input =~ s/(\d{4})\:([A-Z][a-z]{2}):(\d{1,2})/$2 $3, $1/;
        }
        else {
            $input =~ s/(\d{4})\:([A-Z][a-z]{2})/$2 $1/;
        }
    }

    # this case will work, but the prompt will always appear for the affected ID
    # subsequent runs would not be able to differentiate between cases which should concatenate and those which should not
    if (
        (
               $info{'concat'}->{'orig'}->{'concat'}
            || $info{'concat'}->{'new'}->{'concat'}
        )
        && (   $info{'concat'}->{'orig'}->{'nonconcat'}
            || $info{'concat'}->{'new'}->{'nonconcat'} )
      )
    {
        &crl_print_warning( $fh_ref->{'WARNING'},
                'ID: '
              . $ctrl_num
              . ', Cases identified within a single ID where concatenations and non-concatenations happen concurrently'
          )
    }
    elsif ($info{'concat'}->{'orig'}->{'concat'} == 0
        && $info{'concat'}->{'new'}->{'concat'} == 1 )
    {
       # update ignore concerns hash to denote that holdings are concatenateable
        $ignore_concerns_ref->{$ctrl_num} =
          &crl_append_string( $ignore_concerns_ref->{$ctrl_num},
            'Concatenateable' );

    }
    elsif ($info{'concat'}->{'orig'}->{'concat'} == 0
        && $info{'concat'}->{'new'}->{'nonconcat'} == 1 )
    {
    # update ignore concerns hash to denote that holdings are non-concatenateable, and include those specific holdings
        if ( $info{'concat'}->{'orig'}->{'nonconcat'} == 0 ) {

            # build concern string
            $concern_string          = 'Non-concatenateable';
            $concern_holdings_string = '';
            foreach ( @{ $info{'concat'}->{'new'}->{'nonconcat_holdings'} } ) {
                if ( $concern_holdings_string ne '' ) {
                    $concern_holdings_string .= ' && ' . $_;
                }
                else {
                    $concern_holdings_string = $_;
                }
            }
            $concern_string .= ' (' . $concern_holdings_string . ')'
              if ( $concern_holdings_string ne '' );

            $ignore_concerns_ref->{$ctrl_num} =
              &crl_append_string( $ignore_concerns_ref->{$ctrl_num},
                $concern_string );
        }

    }

    if (  !&has_concern( $info{'concerns'}, 'gaps' )
        && $info{'gaps'}->{'gaps_allowed'} == 1 )
    {
        # update ignore concerns hash to denote that gaps are acceptable
        $ignore_concerns_ref->{$ctrl_num} =
          &crl_append_string( $ignore_concerns_ref->{$ctrl_num},
            'Gaps acceptable' );

    }
    elsif ( !&has_concern( $info{'concerns'}, 'no_gaps' )
        && $info{'gaps'}->{'gaps_allowed'} == 0 )
    {
        # update ignore concerns hash to denote that gaps are not acceptable
        $ignore_concerns_ref->{$ctrl_num} =
          &crl_append_string( $ignore_concerns_ref->{$ctrl_num},
            'Gaps not acceptable' );

    }

    # remove space characters before commas
    $input =~ s/\s*,/,/g;

    return ( $err_flag, $err_msg, $input );
}

# validate volumes and numbers
sub validate_vols_and_nums {
    my ( $input_section, $err_msg, $err_flag ) = @_;

    my ( $begin_num, $end_num );

    # volume or number begins with a letter
    ( $err_msg, $err_flag ) =
      &crl_append_error_msg( $err_msg, 'Invalid volume/number identifier: ' . $1 )
      if ( $input_section =~ m/((?:v|no)\.[a-z][^\s\:]*)/i );

    # invalid number range
    if ( $input_section =~ /no\.(\d+)-(\d+)/ ) {
        ( $begin_num, $end_num ) = ( $1, $2 );
        ( $err_msg, $err_flag ) =
          &crl_append_error_msg( $err_msg,
            'Invalid number range: ' . $begin_num . '-' . $end_num )
          if ( $end_num <= $begin_num );
    }

    return ( $err_msg, $err_flag );
}

# check for a valid holdings format
sub is_valid_holdings_format {
    my ( $ctrl_num, $holdings, $freq_ref, $fh_ref, $opts_ref, $info_ref,
        $series_info_ref )
      = @_;

    # define constants
    my ( $MAX_VOL, $MAX_NUM, $MAX_PART ) = ( 9999, 99999, 99 );

    my (
        $orig_holdings,           $new_series_id,
        $alt_vol1,                $alt_num1,
        $vol1,                    $num1,
        $part1,                   $vol2,
        $num2,                    $part2,
        $date,                    $date1,
        $date2,                   $begin_date,
        $err_msg,                 $has_err,
        $is_valid_date,           $is_valid_date_err_msg,
        $is_valid,                $last_holdings,
        $last_vol,                $last_num,
        $last_part,               $last_date,
        $last_new_series,         $last_concat_vol,
        $last_concat_num,         $last_concat_part,
        $last_concat_date,        $last_concat_end_date,
        $compare_holdings_string, $freq,
        $max_freq,                $date_as_vol,
        $max_vol,                 $max_num,
        $max_part,                $num_nums,
        $num_parts,               $gap
    );

    # initialize vars
    $new_series_id = 0;
    $err_msg       = '';
    $has_err       = 0;
    $max_vol       = $MAX_VOL;
    $max_num       = $MAX_NUM;
    $max_part      = $MAX_PART;
    $freq          = $freq_ref->{'freq'};
    $max_freq      = $freq_ref->{'max_freq'};
    $date_as_vol   = 0;

    # set local vars to perform matches
    $last_holdings           = $info_ref->{'last_holdings'};
    $last_vol                = $info_ref->{'last_vol'};
    $last_num                = $info_ref->{'last_num'};
    $last_part               = $info_ref->{'last_part'};
    $last_date               = $info_ref->{'last_date'};
    $last_new_series         = $info_ref->{'last_new_series'};
    $last_concat_vol         = $info_ref->{'concat'}->{'last_vol'};
    $last_concat_num         = $info_ref->{'concat'}->{'last_num'};
    $last_concat_part        = $info_ref->{'concat'}->{'last_part'};
    $last_concat_date        = $info_ref->{'concat'}->{'last_date'};
    $compare_holdings_string = $last_holdings . ' and ' . $holdings;

    # remove 'n.s.' for the purposes of validating the normalized format
    $orig_holdings = $holdings;
    if ( $holdings =~ m/^(\d+)?n\.?s\.?\s*/ ) {
        $new_series_id = $1;
        $new_series_id = 1
          if ( !defined($new_series_id) || $new_series_id eq '' );
        $holdings =~ s/^(\d+)?n\.?s\.?\s*//;
    }
    $last_holdings =~ s/^(\d+)?n\.?s\.?\s*//;
    &crl_print_warning( $fh_ref->{'WARNING'},
            'ID: '
          . $ctrl_num
          . ', Improper series ordering: '
          . $compare_holdings_string )
      if ( $new_series_id < $last_new_series );

    if ( $holdings =~
m/^v\.(\d+[A-Za-z]?(?:\/\d+[A-Za-z]?)*)(?:\:no\.(\d+(?:\/\d+)*))?(?:\:pt\.(\d+))?\-v\.(\d+[A-Za-z]?(?:\/\d+[A-Za-z]?)*)(?:\:no\.(\d+(?:\/\d+)*))?(?:\:pt\.(\d+))?\s*(?:\(([^\)]+)\))?$/
      )
    {
        # cross-volume holdings
        ( $vol1, $num1, $part1, $vol2, $num2, $part2, $date ) =
          ( $1, $2, $3, $4, $5, $6, $7 );

        # ignore appended letters in volumes (for qc purposes)
        $vol1 =~ s/[a-z]//gi;
        $vol2 =~ s/[a-z]//gi;

        # handles cases where values are part of a set (i.e. 11/12)
        ( $err_msg, $has_err, $vol1, undef ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $vol1 );
        ( $err_msg, $has_err, undef, $vol2 ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $vol2 );
        ( $err_msg, $has_err, $num1, undef ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $num1 )
          if ( defined($num1) );
        ( $err_msg, $has_err, undef, $num2 ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $num2 )
          if ( defined($num2) );

        if ( !$has_err ) {

            # TODO: add check for part sequence
            if (
                $vol2 < $vol1
                || (   $vol1 == $vol2
                    && defined($num1)
                    && defined($num2)
                    && $num2 <= $num1 )
              )
            {
                ( $err_msg, $has_err ) =
                  &crl_append_error_msg( $err_msg, 'Improper vol/num ordering' );
            }

            # Set the max num based on the frequency, when possible
            $max_num = $freq if ( $freq != 0 );
            $max_num = $MAX_NUM
              if (
                &reset_max_num(
                    $fh_ref,   $info_ref, $ctrl_num, $holdings,
                    $freq_ref, $vol1,     $num1
                )
              );
            $max_num = $MAX_NUM
              if (
                &reset_max_num(
                    $fh_ref,   $info_ref, $ctrl_num, $holdings,
                    $freq_ref, $vol2,     $num2
                )
              );

            # set appropriate last values
            $info_ref->{'last_vol'}  = $vol2;
            $info_ref->{'last_num'}  = ( defined($num2) ) ? $num2 : $max_num;
            $info_ref->{'last_part'} = ( defined($part2) ) ? $part2 : $max_part;
            $info_ref->{'concat'}->{'last_vol'}  = $info_ref->{'last_vol'};
            $info_ref->{'concat'}->{'last_num'}  = $info_ref->{'last_num'};
            $info_ref->{'concat'}->{'last_part'} = $info_ref->{'last_part'};
        }
    }
    elsif ( $holdings =~
m/^v\.(\d+[A-Za-z]?(?:\/\d+[A-Za-z]?)*)(?:(?:\:no\.(\d+(?:\/\d+)*))?(?:\:pt\.(\d+))?(?:\-(?:(?:no\.)?(\d+(?:\/\d+)*))?(?:\:pt\.(\d+))?)?)?\s*(?:\(([^\)]+)\)?)?$/
      )
    {
        # single-volume holdings
        ( $vol1, $num1, $part1, $num2, $part2, $date ) =
          ( $1, $2, $3, $4, $5, $6 );

        # ignore appended letters in volumes (for qc purposes)
        $vol1 =~ s/[a-z]//gi;

        # handles cases where values are part of a set (i.e. 11/12)
        ( $err_msg, $has_err, $vol1, $alt_vol1 ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $vol1 );
        ( $err_msg, $has_err, $num1, $alt_num1 ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $num1 )
          if ( defined($num1) );
        ( $err_msg, $has_err, undef, $num2 ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $num2, 2 )
          if ( defined($num2) );

        if ( !$has_err ) {

            # TODO: add check for part sequence
            if ( defined($num1) && defined($num2) && $num2 <= $num1 ) {
                ( $err_msg, $has_err ) =
                  &crl_append_error_msg( $err_msg, 'Improper vol/num ordering' );
            }

            # Set the max num based on the frequency, when possible
            $max_num = $freq if ( $freq != 0 );
            $max_num = $MAX_NUM
              if (
                &reset_max_num(
                    $fh_ref,   $info_ref, $ctrl_num, $holdings,
                    $freq_ref, $vol1,     $num1
                )
              );
            $max_num = $MAX_NUM
              if (
                &reset_max_num(
                    $fh_ref,   $info_ref, $ctrl_num, $holdings,
                    $freq_ref, $vol1,     $num2
                )
              );

            # set appropriate last values
            $info_ref->{'last_vol'} = $alt_vol1;
            if ( defined($num2) || defined($part2) ) {
                $info_ref->{'last_num'} = ( defined($num2) ) ? $num2 : $max_num;
                $info_ref->{'last_part'} =
                  ( defined($part2) ) ? $part2 : $max_part;
            }
            elsif ( defined($num1) || defined($part1) ) {
                $info_ref->{'last_num'} =
                  ( defined($num1) ) ? $alt_num1 : $max_num;
                $info_ref->{'last_part'} =
                  ( defined($part1) ) ? $part1 : $max_part;
            }
            else {
                $info_ref->{'last_num'}  = $max_num;
                $info_ref->{'last_part'} = $max_part;
            }
            $info_ref->{'concat'}->{'last_vol'}  = $info_ref->{'last_vol'};
            $info_ref->{'concat'}->{'last_num'}  = $info_ref->{'last_num'};
            $info_ref->{'concat'}->{'last_part'} = $info_ref->{'last_part'};
        }
    }
    elsif ( $holdings =~
     m/^no\.(\d+(?:\/\d+)*)(?:(?:\:pt\.(\d+))?(?:\-(?:(?:no\.)?(\d+(?:\/\d+)*))?(?:\:pt\.(\d+))?)?)?\s*(?:\(([^\)]+)\)?)?$/
     )
    {
        # number holdings w/o volume
        ( $num1, $part1, $num2, $part2, $date ) = ( $1, $2, $3, $4, $5 );

        # handles cases where values are part of a set (i.e. 11/12)
        ( $err_msg, $has_err, $num1, $alt_num1 ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $num1 );
        ( $err_msg, $has_err, undef, $num2 ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $num2 )
          if ( defined($num2) );

        if ( !$has_err ) {

            # TODO: add check for part sequence
            if ( defined($num2) && $num2 <= $num1 ) {
                ( $err_msg, $has_err ) =
                  &crl_append_error_msg( $err_msg, 'Improper num ordering' );
            }

            # set appropriate last values
            if ( defined($num2) || defined($part2) ) {
                $info_ref->{'last_num'} = ( defined($num2) ) ? $num2 : $max_num;
                $info_ref->{'last_part'} =
                  ( defined($part2) ) ? $part2 : $max_part;
            }
            else {
                $info_ref->{'last_num'} = $alt_num1;
                $info_ref->{'last_part'} =
                  ( defined($part1) ) ? $part1 : $max_part;
            }
            $info_ref->{'concat'}->{'last_vol'}  = '';
            $info_ref->{'concat'}->{'last_num'}  = $info_ref->{'last_num'};
            $info_ref->{'concat'}->{'last_part'} = $info_ref->{'last_part'};
        }
    }
    elsif ( $holdings =~ m/^(\d{4}):(?:(?:no\.(\d+(?:\/\d+)*)(?:\-(\d+(?:\/\d+)*))?)|(?:pt\.(\d+)(?:\-(\d+))?))$/ )
    {
        # holdings where year is substituted for volume
        ( $date, $num1, $num2, $part1, $part2 ) = ( $1, $2, $3, $4, $5 );

        # handles cases where values are part of a set (i.e. 11/12)
        ( $err_msg, $has_err, $num1, $alt_num1 ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $num1 )
          if ( defined($num1) );
        ( $err_msg, $has_err, undef, $num2 ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $num2, 2 )
          if ( defined($num2) );

        if ( !$has_err ) {

            # TODO: add check for part sequence
            if ( defined($num1) && defined($num2) && $num2 <= $num1 ) {
                ( $err_msg, $has_err ) =
                  &crl_append_error_msg( $err_msg, 'Improper vol/num ordering' );
            }

            # Set the max num based on the frequency, when possible
            if ( defined($num1) || defined($num2) ) {
                $max_num = $freq if ( $freq != 0 );
                $max_num = $MAX_NUM
                  if (
                    &reset_max_num(
                        $fh_ref,   $info_ref, $ctrl_num, $holdings,
                        $freq_ref, $date,     $num1
                    )
                  );
                $max_num = $MAX_NUM
                  if (
                    &reset_max_num(
                        $fh_ref,   $info_ref, $ctrl_num, $holdings,
                        $freq_ref, $date,     $num2
                    )
                  );
            }

            # set appropriate last values
            $info_ref->{'last_vol'} = $date;
            if ( defined($num2) || defined($part2) ) {
                $info_ref->{'last_num'} = ( defined($num2) ) ? $num2 : $max_num;
                $info_ref->{'last_part'} =
                  ( defined($part2) ) ? $part2 : $max_part;
            }
            elsif ( defined($num1) || defined($part1) ) {
                $info_ref->{'last_num'} =
                  ( defined($num1) ) ? $alt_num1 : $max_num;
                $info_ref->{'last_part'} =
                  ( defined($part1) ) ? $part1 : $max_part;
            }
            else {
                $info_ref->{'last_num'}  = $max_num;
                $info_ref->{'last_part'} = $max_part;
            }
            $info_ref->{'concat'}->{'last_vol'}  = $info_ref->{'last_vol'};
            $info_ref->{'concat'}->{'last_num'}  = $info_ref->{'last_num'};
            $info_ref->{'concat'}->{'last_part'} = $info_ref->{'last_part'};
        }

        $date_as_vol = 1;
    }
    elsif ( $holdings =~ m/^pt\.(\d+)\s*$/ ) {

        # only part included
        $info_ref->{'last_part'}             = $1;
        $info_ref->{'concat'}->{'last_vol'}  = '';
        $info_ref->{'concat'}->{'last_num'}  = '';
        $info_ref->{'concat'}->{'last_part'} = $info_ref->{'last_part'};
    }
    elsif ( $holdings eq '' && defined($new_series_id) ) {

        # only series included
        $info_ref->{'concat'}->{'last_vol'}  = '';
        $info_ref->{'concat'}->{'last_num'}  = '';
        $info_ref->{'concat'}->{'last_part'} = '';
    }
    elsif ( $holdings =~ m/^\s*\(([^\)]+)\)?\s*$/ ) {

        # only date/year/range included (date validation occurs below)
        $date = $1;
        $info_ref->{'potential_standalone_date'} = 1
          if ( $info_ref->{'holdings_count'} > 0
            && $info_ref->{'concat'}->{'last_date'} eq '' );
        $info_ref->{'concat'}->{'last_vol'}  = '';
        $info_ref->{'concat'}->{'last_num'}  = '';
        $info_ref->{'concat'}->{'last_part'} = '';
    }
    else {
        ( $err_msg, $has_err ) =
          &crl_append_error_msg( $err_msg, 'Unknown error' );
        $info_ref->{'concat'}->{'last_vol'}  = '';
        $info_ref->{'concat'}->{'last_num'}  = '';
        $info_ref->{'concat'}->{'last_part'} = '';
    }

    if ( defined($date) ) {

        # validate date/range
        ( $is_valid_date, $is_valid_date_err_msg, $date1, $date2 ) =
          &crl_is_valid_date_or_range( $date, 0 );
        if ( !$is_valid_date ) {
            ( $err_msg, $has_err ) = &crl_append_error_msg( $err_msg,
                'Invalid date (' . $is_valid_date_err_msg . '): ' . $date );
            $info_ref->{'concat'}->{'last_date'} = '';
        }
        else {
            #validate date consistency between holdings
            if ( $last_date ne '' && $date1 ne '' ) {
                ( $is_valid_date, $is_valid_date_err_msg ) =
                  &crl_is_valid_date_or_range( $last_date . '-' . $date1, 0 );
                ( $err_msg, $has_err ) = &crl_append_error_msg( $err_msg,
                        'Unordered date between holdings ('
                      . $is_valid_date_err_msg . '): '
                      . $last_date . '-'
                      . $date1 )
                  if ( !$is_valid_date );
            }
            $begin_date = $date1;
            $info_ref->{'last_date'} =
              &set_last_date( $date1, $date2, $last_date );
            $info_ref->{'concat'}->{'last_date'} = $info_ref->{'last_date'};
        }
    }
    else {
        $info_ref->{'concat'}->{'last_date'} = '';
    }

# check for consistency, unless a new series is indicated or an error already occurred
    if (
        !$has_err
        && ( !$new_series_id
            || ( $new_series_id && $new_series_id == $last_new_series ) )
      )
    {
        if ( $last_vol ne '' && defined($vol1) ) {

            # check volumes
            if ( $vol1 < $last_vol ) {
                ( $err_msg, $has_err ) = &crl_append_error_msg( $err_msg,
                    'Improper vol ordering between holdings: '
                      . $compare_holdings_string );
            }
            elsif ( $vol1 == $last_vol ) {

                # check numbers
                $num_nums = &vals_exist( $last_num, $num1, $max_num );
                if ( $num_nums == 1 ) {
                    ( $err_msg, $has_err ) = &crl_append_error_msg( $err_msg,
                        'Improper vol/num/part ordering between holdings: '
                          . $compare_holdings_string );
                }
                elsif ( $num_nums == 0 || $num1 == $last_num ) {

                    # check parts
                    $num_parts = &vals_exist( $last_part, $part1, $max_part );
                    if ( $num_parts == 1
                        || ( $num_parts == 2 && $part1 < $last_part ) )
                    {
                        ( $err_msg, $has_err ) = &crl_append_error_msg( $err_msg,
                            'Improper vol/num/part ordering between holdings: '
                              . $compare_holdings_string );
                    }
                    elsif ( $num_parts == 0
                        || ( $num_parts == 2 && $part1 == $last_part ) )
                    {
                        &crl_print_warning( $fh_ref->{'WARNING'},
                                'ID: '
                              . $ctrl_num
                              . ', Simple overlap between holdings: '
                              . $compare_holdings_string );
                    }
                }
                elsif ( $num1 < $last_num ) {
                    ( $err_msg, $has_err ) = &crl_append_error_msg( $err_msg,
                        'Improper vol/num ordering between holdings: '
                          . $compare_holdings_string );
                }
            }
        }
        elsif ( $date_as_vol && $info_ref->{'last_date_as_vol'} ) {

            # check dates as volumes
            if ( $date < $last_vol ) {
                ( $err_msg, $has_err ) = &crl_append_error_msg( $err_msg,
                    'Improper vol ordering between holdings: '
                      . $compare_holdings_string );
            }
            elsif ( $date == $last_vol ) {
                $num_nums  = &vals_exist( $last_num,  $num1,  $max_num );
                $num_parts = &vals_exist( $last_part, $part1, $max_part );
                if ( $num_nums > 0 && $num_parts > 0 ) {
                    ( $err_msg, $has_err ) = &crl_append_error_msg( $err_msg,
                        'Improper vol/num/part ordering between holdings: '
                          . $compare_holdings_string );
                }
                elsif ( defined($num1) ) {

                    # check numbers
                    if ( $num_nums == 1 ) {
                        ( $err_msg, $has_err ) = &crl_append_error_msg( $err_msg,
                            'Improper vol/num/part ordering between holdings: '
                              . $compare_holdings_string );
                    }
                    elsif ( $num_nums == 0 || $num1 == $last_num ) {
                        &crl_print_warning( $fh_ref->{'WARNING'},
                                'ID: '
                              . $ctrl_num
                              . ', Simple overlap between holdings: '
                              . $compare_holdings_string );
                    }
                    elsif ( $num1 < $last_num ) {
                        ( $err_msg, $has_err ) = &crl_append_error_msg( $err_msg,
                            'Improper vol/num ordering between holdings: '
                              . $compare_holdings_string );
                    }
                }
                elsif ( defined($part1) ) {

                    # check parts
                    if ( $num_parts == 1
                        || ( $num_parts == 2 && $part1 < $last_part ) )
                    {
                        ( $err_msg, $has_err ) = &crl_append_error_msg( $err_msg,
                            'Improper vol/num/part ordering between holdings: '
                              . $compare_holdings_string );
                    }
                    elsif ( $num_parts == 0
                        || ( $num_parts == 2 && $part1 == $last_part ) )
                    {
                        &crl_print_warning( $fh_ref->{'WARNING'},
                                'ID: '
                              . $ctrl_num
                              . ', Simple overlap between holdings: '
                              . $compare_holdings_string );
                    }
                }
                else {
                    &crl_print_warning( $fh_ref->{'WARNING'},
                            'ID: '
                          . $ctrl_num
                          . ', Simple overlap between holdings: '
                          . $compare_holdings_string );
                }
            }
        }
        elsif ( $last_num ne '' && defined($num1) ) {

            # check numbers
            if ( $num1 < $last_num ) {
                ( $err_msg, $has_err ) = &crl_append_error_msg( $err_msg,
                    'Improper num ordering between holdings: '
                      . $compare_holdings_string );
            }
            elsif ( $num1 == $last_num ) {

                # check parts
                $num_parts = &vals_exist( $last_part, $part1, $max_part );
                if ( $num_parts == 1
                    || ( $num_parts == 2 && $part1 < $last_part ) )
                {
                    ( $err_msg, $has_err ) = &crl_append_error_msg( $err_msg,
                        'Improper vol/num/part ordering between holdings: '
                          . $compare_holdings_string );
                }
                elsif ( $num_parts == 0
                    || ( $num_parts == 2 && $part1 == $last_part ) )
                {
                    &crl_print_warning( $fh_ref->{'WARNING'},
                            'ID: '
                          . $ctrl_num
                          . ', Simple overlap between holdings: '
                          . $compare_holdings_string );
                }
            }
        }
        elsif ( $last_part ne '' && defined($part1) ) {

            # check parts
            if ( $part1 < $last_part ) {
                ( $err_msg, $has_err ) = &crl_append_error_msg( $err_msg,
                    'Improper vol/num/part ordering between holdings: '
                      . $compare_holdings_string );
            }
            elsif ( $part1 == $last_part ) {
                &crl_print_warning( $fh_ref->{'WARNING'},
                        'ID: '
                      . $ctrl_num
                      . ', Simple overlap between holdings: '
                      . $compare_holdings_string );
            }
        }
        elsif ( !defined($date) ) {

     # flag toggle
     #print warning for mis-matched holdings?  i.e. v.2; no.7 or v.2, pt.7; no.5
        }
    }

    # determine whether concatenation and/or gap processing should occur
    my ( $can_concat, $consider_concat, $process_gap, $concat_holdings );
    $can_concat  = 0;
    $process_gap = 0;
    $gap         = '';
    if ( $new_series_id == $last_new_series ) {
        if ( !&vals_exist( $last_concat_part, $part1, $max_part ) ) {

# check for case where volume goes up 1, number goes down and number is greater than 52
            &crl_print_warning( $fh_ref->{'WARNING'},
                    'ID: '
                  . $ctrl_num
                  . ', Possible typo between holdings: '
                  . $compare_holdings_string )
              if ( &vals_exist( $last_concat_vol, $vol1, $max_vol ) == 2
                && $vol1 == $last_concat_vol + 1
                && &vals_exist( $last_concat_num, $num1, $max_num ) == 2
                && $num1 < $last_concat_num
                && $num1 > 52 );

# track if neither or both dates exist; only consider concatenation in those cases
            $consider_concat = ( !&vals_exist( $last_concat_date, $date, '' )
                  || &vals_exist( $last_concat_date, $date, '' ) == 2 ) ? 1 : 0;

            if (
                (
                    &vals_exist( $last_concat_vol, $vol1, $max_vol ) == 2
                    && (   $vol1 == $last_concat_vol + 1
                        || $vol1 == $last_concat_vol )
                    && !&vals_exist( $last_concat_num, $num1, $max_num )
                )
                || (
                    &vals_exist( $last_concat_num, $num1, $max_num ) == 2
                    && (   $num1 == $last_concat_num + 1
                        || $num1 == $last_concat_num )
                    && !&vals_exist( $last_concat_vol, $vol1, $max_vol )
                )
                || (
                       &vals_exist( $last_concat_vol, $vol1, $max_vol ) == 2
                    && $vol1 == $last_concat_vol
                    && &vals_exist( $last_concat_num, $num1, $max_num ) == 2
                    && (   $num1 == $last_concat_num + 1
                        || $num1 == $last_concat_num )
                )
                || (
                       $date_as_vol
                    && $info_ref->{'last_date_as_vol'}
                    && $date == $last_concat_vol
                    && &vals_exist( $last_concat_num, $num1, $max_num ) == 2
                    && (   $num1 == $last_concat_num + 1
                        || $num1 == $last_concat_num )
                )
                || (
                       &vals_exist( $last_concat_vol, $vol1, $max_vol ) == 2
                    && $vol1 == $last_concat_vol + 1
                    && ( !defined($num1) || $num1 eq '1' )
                    && (
                        $last_concat_num eq ''
                        || (
                            $max_freq != 0
                            && (   $last_concat_num == $max_freq
                                || $last_concat_num == $max_freq + 1 )
                        )
                        || $last_concat_num == $MAX_NUM
                    )
                )
                || (
                       &vals_exist( $last_concat_vol, $vol1, $max_vol ) == 2
                    && $vol1 == $last_concat_vol + 1
                    && ( !defined($num1)
                        || $num1 == ( $last_concat_vol * $max_freq + 1 ) )
                    && (   $last_concat_num eq ''
                        || $last_concat_num == ( $last_concat_vol * $max_freq )
                        || $last_concat_num == $max_freq )
                )
                || (   $date_as_vol
                    && $info_ref->{'last_date_as_vol'}
                    && $date == $last_concat_vol + 1
                    && $num1 == 1
                    && $last_concat_num == $freq )
              )
            {
                # determine whether concatenation or gap processing should occur
                ( $can_concat, $process_gap ) =
                  &can_concat( 1, $consider_concat, $ctrl_num, $info_ref,
                    $fh_ref, $opts_ref, $compare_holdings_string );
            }
            elsif (&vals_exist( $last_concat_vol, $vol1, $max_vol ) == 2
                && $vol1 == $last_concat_vol + 1
                && &vals_exist( $last_concat_num, $num1, $max_num ) == 2
                && $num1 == $last_concat_num + 1 )
            {
                if ( $num1 > 52 ) {

     # allow concatenation when number is high enough to avoid improper grouping
     # determine whether concatenation or gap processing should occur
                    ( $can_concat, $process_gap ) =
                      &can_concat( 1, $consider_concat, $ctrl_num, $info_ref,
                        $fh_ref, $opts_ref, $compare_holdings_string );
                }
                else {
                # determine whether concatenation or gap processing should occur
                    ( $can_concat, $process_gap ) =
                      &can_concat( 0, $consider_concat, $ctrl_num, $info_ref,
                        $fh_ref, $opts_ref, $compare_holdings_string );
                }
            }
            elsif (!&vals_exist( $last_concat_vol, $vol1, $max_vol )
                && !&vals_exist( $last_concat_num, $num1, $max_num )
                && $last_concat_date ne ''
                && defined($begin_date) )
            {
                # TODO: Also account for Nov/Dec 2010?
                my ( $last_concat_end_date_month, $last_concat_end_date_year,
                    $begin_date_month, $begin_date_year );

                $last_concat_end_date = $last_concat_date;
                my $num_joined_sets = 0;
                my $new;
                if ( $last_concat_end_date =~ m/^\d{4}(\/\d{4})?$/ ) {
                    ( $err_msg, $has_err, undef, $new ) =
                      &process_joined_set( $fh_ref, $err_msg, $has_err,
                        $last_concat_end_date );
                    $num_joined_sets++ if ( $new ne $last_concat_end_date );
                    $last_concat_end_date = $new;
                }
                elsif ( $last_concat_end_date =~ m/^[A-Z][a-z]{2,3} \d{4}$/ ) {
                    ( $last_concat_end_date_month, $last_concat_end_date_year )
                      = split( /\s+/, $last_concat_end_date );
                }

                if ( $begin_date =~ m/^\d{4}(\/\d{4})?$/ ) {
                    ( $err_msg, $has_err, $new, undef ) =
                      &process_joined_set( $fh_ref, $err_msg, $has_err,
                        $begin_date );
                    $num_joined_sets++ if ( $new ne $begin_date );
                    $begin_date = $new;
                }
                elsif ( $begin_date =~ m/^[A-Z][a-z]{2,3} \d{4}$/ ) {
                    ( $begin_date_month, $begin_date_year ) =
                      split( /\s+/, $begin_date );
                }

                if ( $last_concat_end_date =~ m/^\d{4}$/ ) {
                    if (
                        $begin_date =~ m/^\d{4}$/
                        && (   ( $begin_date == $last_concat_end_date )
                            || ( $begin_date == $last_concat_end_date + 1 ) )
                      )
                    {
                # determine whether concatenation or gap processing should occur
                        if (   $num_joined_sets == 0
                            || $begin_date == $last_concat_end_date )
                        {
                            ( $can_concat, $process_gap ) =
                              &can_concat( 1, $consider_concat, $ctrl_num,
                                $info_ref, $fh_ref, $opts_ref,
                                $compare_holdings_string );
                        }
                        elsif ( $num_joined_sets == 2 ) {
                            ( $can_concat, $process_gap ) = ( 0, 1 );
                        }
                        else {
                            ( $can_concat, $process_gap ) = ( 0, 0 );
                        }
                    }
                    elsif (defined($begin_date_month)
                        && $begin_date_month eq 'Jan'
                        && $begin_date_year == $last_concat_end_date + 1 )
                    {
                # determine whether concatenation or gap processing should occur
                        if ( $num_joined_sets == 0 ) {
                            ( $can_concat, $process_gap ) =
                              &can_concat( 1, $consider_concat, $ctrl_num,
                                $info_ref, $fh_ref, $opts_ref,
                                $compare_holdings_string );
                        }
                        else {
                            ( $can_concat, $process_gap ) = ( 0, 0 );
                        }
                    }
                    elsif ( $last_holdings ne '' ) {

               # determine whether to process gaps
               # TODO: determine when necessary to process gaps in this scenario
                        $process_gap = 1;
                    }
                }
                elsif ( defined($last_concat_end_date_month) ) {
                    if (   $last_concat_end_date_month eq 'Dec'
                        && $begin_date =~ m/^\d{4}$/
                        && ( $begin_date == $last_concat_end_date_year + 1 ) )
                    {
                # determine whether concatenation or gap processing should occur
                        if ( $num_joined_sets == 0 ) {
                            ( $can_concat, $process_gap ) =
                              &can_concat( 1, $consider_concat, $ctrl_num,
                                $info_ref, $fh_ref, $opts_ref,
                                $compare_holdings_string );
                        }
                        else {
                            ( $can_concat, $process_gap ) = ( 0, 0 );
                        }
                    }
                    elsif ($last_concat_end_date_month eq 'Dec'
                        && defined($begin_date_month)
                        && $begin_date_month eq 'Jan'
                        && $begin_date_year == $last_concat_end_date_year + 1 )
                    {
                # determine whether concatenation or gap processing should occur
                        ( $can_concat, $process_gap ) =
                          &can_concat( 1, $consider_concat, $ctrl_num,
                            $info_ref, $fh_ref, $opts_ref,
                            $compare_holdings_string );
                    }
                    elsif ( defined($begin_date_month)
                        && &crl_get_month_num($begin_date_month) ==
                        &crl_get_month_num($last_concat_end_date_month) + 1
                        && $begin_date_year == $last_concat_end_date_year )
                    {
                # determine whether concatenation or gap processing should occur
                        ( $can_concat, $process_gap ) =
                          &can_concat( 1, $consider_concat, $ctrl_num,
                            $info_ref, $fh_ref, $opts_ref,
                            $compare_holdings_string );
                    }
                    elsif ( $last_holdings ne '' ) {

               # determine whether to process gaps
               # TODO: determine when necessary to process gaps in this scenario
                        $process_gap = 1;
                    }
                }
                else {
                    if ( $last_holdings ne '' ) {

               # determine whether to process gaps
               # TODO: determine when necessary to process gaps in this scenario
                        $process_gap = 1;
                    }
                }
            }
            elsif ( $last_holdings ne '' ) {

               # determine whether to process gaps
               # TODO: determine when necessary to process gaps in this scenario
                $process_gap = 1;
            }
        }
        elsif (&vals_exist( $last_concat_part, $part1, $max_part ) == 2
            && $part1 == $last_concat_part + 1 )
        {
# track if neither or both dates exist; only consider concatenation in those cases
            $consider_concat = ( !&vals_exist( $last_concat_date, $date, '' )
                  || &vals_exist( $last_concat_date, $date, '' ) == 2 ) ? 1 : 0;

            if (
                (
                       &vals_exist( $last_concat_vol, $vol1, $max_vol ) == 2
                    && $vol1 == $last_concat_vol
                    && !&vals_exist( $last_concat_num, $num1, $max_num )
                )
                || (   !&vals_exist( $last_concat_vol, $vol1, $max_vol )
                    && !&vals_exist( $last_concat_num, $num1, $max_num ) )
                || (   &vals_exist( $last_concat_vol, $vol1, $max_vol ) == 2
                    && $vol1 == $last_concat_vol
                    && &vals_exist( $last_concat_num, $num1, $max_num ) == 2
                    && $num1 == $last_concat_num )
                || (  !&vals_exist( $last_concat_vol, $vol1, $max_vol )
                    && &vals_exist( $last_concat_num, $num1, $max_num ) == 2
                    && $num1 == $last_concat_num )
                || (   $date_as_vol
                    && $info_ref->{'last_date_as_vol'}
                    && $date == $last_concat_vol
                    && !&vals_exist( $last_concat_num, $num1, $max_num ) )
              )
            {
                # determine whether concatenation or gap processing should occur
                ( $can_concat, $process_gap ) =
                  &can_concat( 1, $consider_concat, $ctrl_num, $info_ref,
                    $fh_ref, $opts_ref, $compare_holdings_string );
            }
            elsif ( $last_holdings ne '' ) {

               # determine whether to process gaps
               # TODO: determine when necessary to process gaps in this scenario
                $process_gap = 1;
            }
        }
        elsif (&vals_exist( $last_concat_part, $part1, $max_part ) == 1
            && defined($part1)
            && $part1 == 1 )
        {
# track if neither or both dates exist; only consider concatenation in those cases
            $consider_concat = ( !&vals_exist( $last_concat_date, $date, '' )
                  || &vals_exist( $last_concat_date, $date, '' ) == 2 ) ? 1 : 0;

            if (
                (
                       &vals_exist( $last_concat_vol, $vol1, $max_vol ) == 2
                    && $vol1 == $last_concat_vol + 1
                    && !&vals_exist( $last_concat_num, $num1, $max_num )
                )
                || (   &vals_exist( $last_concat_vol, $vol1, $max_vol ) == 2
                    && $vol1 == $last_concat_vol
                    && &vals_exist( $last_concat_num, $num1, $max_num ) == 2
                    && $num1 == $last_concat_num + 1 )
                || (  !&vals_exist( $last_concat_vol, $vol1, $max_vol )
                    && &vals_exist( $last_concat_num, $num1, $max_num ) == 2
                    && $num1 == $last_concat_num + 1 )
                || (   $date_as_vol
                    && $info_ref->{'last_date_as_vol'}
                    && $date == $last_concat_vol
                    && !&vals_exist( $last_concat_num, $num1, $max_num ) )
              )
            {
                # determine whether concatenation or gap processing should occur
                ( $can_concat, $process_gap ) =
                  &can_concat( 1, $consider_concat, $ctrl_num, $info_ref,
                    $fh_ref, $opts_ref, $compare_holdings_string );
            }
            elsif ( $last_holdings ne '' ) {

               # determine whether to process gaps
               # TODO: determine when necessary to process gaps in this scenario
                $process_gap = 1;
            }
        }
        elsif ( $last_holdings ne '' ) {

            # TODO: determine if necessary to process gaps in this scenario
            # TODO: parts included; manually check for potential gaps
            $process_gap = 1;
        }
    }

    # handle concatenation
    if ( $info_ref->{'concat'}->{'process'} && $can_concat ) {

        # add to current set
        push( @{ $info_ref->{'concat'}->{'current_set'} }, $orig_holdings );

        # add to skipped_ns (if appropriate)
        my $ns_count = $info_ref->{'ns_count'};
        $info_ref->{'concat'}->{'skipped_ns'}->{$ns_count}++
          if ( $new_series_id != 0
            && scalar( @{ $info_ref->{'concat'}->{'current_set'} } ) > 1 );
    }
    else {
        #move current_set to new_holdings
        ( $is_valid_date, $is_valid_date_err_msg, $concat_holdings ) =
          &concat_set( \@{ $info_ref->{'concat'}->{'current_set'} },
            $fh_ref, $max_freq, $info_ref );
        ( $err_msg, $has_err ) =
          &crl_append_error_msg( $err_msg,
            'Invalid concatenated format (' . $is_valid_date_err_msg . ')' )
          if ( !$is_valid_date );
        if ( $concat_holdings ne '' ) {
            if ( $info_ref->{'concat'}->{'new_holdings'} ne '' ) {
                $info_ref->{'concat'}->{'new_holdings'} = join( ', ',
                    $info_ref->{'concat'}->{'new_holdings'},
                    $concat_holdings );
            }
            else {
                $info_ref->{'concat'}->{'new_holdings'} = $concat_holdings;
            }
        }

        @{ $info_ref->{'concat'}->{'current_set'} } = ($orig_holdings);
    }

    # handle gaps
    if ( $info_ref->{'gaps'}->{'process'} && $process_gap ) {
        ( $is_valid_date, $is_valid_date_err_msg, $gap ) =
          &determine_gap( $last_holdings, $holdings, $freq_ref, $fh_ref,
            $info_ref, $opts_ref, $ctrl_num );
        ( $err_msg, $has_err ) =
          &crl_append_error_msg( $err_msg,
            'Invalid gap format (' . $is_valid_date_err_msg . ')' )
          if ( !$is_valid_date );
        if ( $gap ne '' ) {

            # add back new series info, if applicable
            $gap = @{$series_info_ref}[ $info_ref->{'ns_count'} ] . ' ' . $gap
              if ( $new_series_id != 0 );
            $info_ref->{'gaps'}->{'value'} =
              &crl_append_string( $info_ref->{'gaps'}->{'value'}, $gap, ', ' );
        }
    }

    # set new last values
    $info_ref->{'last_new_series'}  = $new_series_id;
    $info_ref->{'last_holdings'}    = $orig_holdings;
    $info_ref->{'last_date_as_vol'} = $date_as_vol;
    $info_ref->{'ns_count'}++ if ( $new_series_id != 0 );

    $is_valid = !$has_err;

    return ( $is_valid, $err_msg );
}

# processes sets of the form 11/12
sub process_joined_set {
    my ( $fh_ref, $err_msg, $has_err, $set ) = @_;

    my ( $tmp_val, $val, $alt_new_val, $new_val );
    my (@vals);

    $tmp_val     = 0;
    $alt_new_val = '';
    $new_val     = '';

    @vals = split( /\//, $set );
    if ( scalar(@vals) > 1 ) {
        if ( scalar(@vals) > 2 ) {
            ( $err_msg, $has_err ) = &crl_append_error_msg( $err_msg,
                'Set contains more than 2 values: ' . $set );
        }

        # verify that the sets are always increasing
        foreach $val (@vals) {
            if ( $val <= $tmp_val ) {
                ( $err_msg, $has_err ) =
                  &crl_append_error_msg( $err_msg, 'Invalid set: ' . $set );
                last;
            }
            $tmp_val = $val;
        }

        if ( !$has_err ) {
            $alt_new_val = $set;
            $alt_new_val =~ s/\/.*$//;
            $new_val = $set;
            $new_val =~ s/^.*\///;
        }
    }
    else {
        # only a single value present
        $alt_new_val = $set;
        $new_val     = $set;
    }

    return ( $err_msg, $has_err, $alt_new_val, $new_val );
}

## determines new value of last date based on current input
sub set_last_date {
    my ( $begin_range, $end_range, $last ) = @_;

    if ( defined($end_range) && $end_range ne '' ) {
        $last = $end_range;
    }
    elsif ( defined($begin_range) && $begin_range ne '' ) {
        $last = $begin_range;
    }
    else {
        #need to track last known instance; do not alter
    }

    return $last;
}

## returns number of defined and non-blank values; otherwise returns 0
sub vals_exist {
    my ( $last_val, $next_val, $max_val ) = @_;

    my $num_vals = 0;

    if (   defined($last_val)
        && $last_val ne ''
        && ( $max_val eq '' || $last_val != $max_val ) )
    {
        $num_vals++;
    }

    if (   defined($next_val)
        && $next_val ne ''
        && ( $max_val eq '' || $next_val <= $max_val ) )
    {
        $num_vals++;
    }

    return $num_vals;
}

## concatenates a consecutive set of holdings
sub concat_set {
    my ( $set_ref, $fh_ref, $freq, $info_ref ) = @_;

    my (
        $concat_set, $concat_range, $concat_date,     $new_series_id,
        $is_valid,   $has_err,      $err_msg,         $num_in_set,
        $begin,      $end,          $begin_range,     $end_range,
        $begin_vol,  $end_vol,      $begin_num,       $end_num,
        $begin_date, $end_date,     $begin_date_year, $end_date_year,
        $sub_date_a, $sub_date_b,   $process_range,   $process_date,
        $date_as_vol
    );

    $concat_set    = '';
    $concat_range  = '';
    $concat_date   = '';
    $new_series_id = '';
    $is_valid      = 1;
    $has_err       = 0;
    $err_msg       = '';
    $process_range = 0;
    $process_date  = 0;
    $date_as_vol   = $info_ref->{'last_date_as_vol'};

    $num_in_set = scalar( @{$set_ref} );

    if ( $num_in_set > 0 ) {
        $begin = @{$set_ref}[0];
        $end   = @{$set_ref}[ $num_in_set - 1 ];

        # the date is treated like the volume; temporarily add in the volume id
        if ($date_as_vol) {
            $begin = 'v.' . $begin;
            $end   = 'v.' . $end;
        }

        # handle single volume, cross number holdings
        $begin =~
s/((v\.\d+[A-Za-z]?(?:\/\d+[A-Za-z]?)*\:no\.)\d+(?:\/\d+)*)-(?:no\.)?(\d+(?:\/\d+)*)/$1-$2$3/g;
        $end =~
s/((v\.\d+[A-Za-z]?(?:\/\d+[A-Za-z]?)*\:no\.)\d+(?:\/\d+)*)-(?:no\.)?(\d+(?:\/\d+)*)/$1-$2$3/g;

        # determine ranges
        $begin_range = $begin;
        $begin_range =~ s/\s*\(.*$//;
        $begin_range =~ s/\s*\-.*$//;

        $end_range = $end;
        $end_range =~ s/\s*\(.*$//;
        $end_range =~ s/^.*\-\s*//;
        $end_range =~ s/^(\d+)?n\.s\.\s+//;

        if ( $num_in_set == 1 ) {
            if (   $begin_range ne ''
                && $end_range ne ''
                && $begin_range ne $end_range
                && $begin_range =~ m/^v\./
                && $end_range =~ m/^v\./ )
            {
                $process_range = 1;

                # date handled separately for single value
                $concat_date = $begin if ( $begin =~ m/\(/ );
                $concat_date =~ s/^.*\(//;
                $concat_date =~ s/\).*$//;
            }
            else {
                $concat_set = @{$set_ref}[0];
                $concat_set =~ s/^\s*//;
            }
        }
        elsif ( $num_in_set > 1 ) {
            $process_range = 1
              if ( $begin_range ne '' && $end_range ne '' );
            $process_date = 1;
        }

        if ($process_range) {

            # save off new series
            if ( $begin_range =~ m/^(\d+n\.s\.\s*)/ ) {
                $new_series_id = $1;
                $begin_range =~ s/^\d+n\.s\.\s*//;
            }

            # build concat range
            $concat_range = $begin_range . '-' . $end_range;

            $begin_range =~ m/^v\.([^:]+)/;
            $begin_vol = $1;
            $end_range =~ m/^v\.([^:]+)/;
            $end_vol = $1;

            if ( defined($begin_vol) && defined($end_vol) ) {

                # handle case where volume is same on both sides of range
                $concat_range =~ s/\-v\.$end_vol\:(?:no|pt)\./-/
                  if ( $begin_vol eq $end_vol );

                my ( $orig_begin_num, $orig_end_num );
                $begin_range =~ m/^v\.[^:]+:no\.([^:]+)/;
                if ( defined($1) ) {
                    $begin_num      = $1;
                    $orig_begin_num = $begin_num;
                    ( $err_msg, $has_err, $begin_num, undef ) =
                      &process_joined_set( $fh_ref, $err_msg, $has_err,
                        $begin_num );
                }

                $end_range =~ m/^v\.[^:]+:no\.([^:]+)/;
                if ( defined($1) ) {
                    $end_num      = $1;
                    $orig_end_num = $end_num;
                    ( $err_msg, $has_err, undef, $end_num ) =
                      &process_joined_set( $fh_ref, $err_msg, $has_err,
                        $end_num );
                }

                if ( $begin_vol ne $end_vol ) {

# handle case where volume is different and the begin num is either 1 or the bound dictated by the frequency
                    if (
                        defined($begin_num)
                        && (
                            $begin_num eq '1'
                            || (   $freq != 0
                                && $begin_vol !~ m/[^\d]/
                                && $begin_num !~ m/[^\d]/
                                && $begin_num > $freq
                                && $begin_num ==
                                $begin_vol * $freq - ( $freq - 1 ) )
                        )
                      )
                    {
                        $concat_range =~
s/^v\.$begin_vol\:no\.$orig_begin_num\-/v.${begin_vol}-/;
                    }

# handle case where volume is different and end num is either the frequency or the bound dictated by the frequency
                    if (
                        ( defined $end_num && defined $freq )
                        && (
                            $end_num eq $freq
                            || (   $freq != 0
                                && $end_vol !~ m/[^\d]/
                                && $end_num !~ m/[^\d]/
                                && $end_num > $freq
                                && $end_num == $end_vol * $freq )
                        )
                      )
                    {
                        $concat_range =~
                          s/\-v\.$end_vol\:no\.$orig_end_num/-v.$end_vol/;
                    }
                }

                if ( $begin_vol eq $end_vol ) {
                    ( $err_msg, $has_err, undef, $end_vol ) =
                      &process_joined_set( $fh_ref, $err_msg, $has_err,
                        $end_vol );

# handle case where volume is the same and the begin and end numbers are the bounds dictated by the frequency
                    if (
                           defined($begin_num)
                        && defined($end_num)
                        && (
                            $begin_num == 1
                            || (   $freq != 0
                                && $begin_vol !~ m/[^\d]/
                                && $begin_num !~ m/[^\d]/
                                && $begin_num > $freq
                                && $begin_num ==
                                $begin_vol * $freq - ( $freq - 1 ) )
                        )
                        && (
                            $end_num eq $freq
                            || (   $freq != 0
                                && $end_vol !~ m/[^\d]/
                                && $end_num !~ m/[^\d]/
                                && $end_num > $freq
                                && $end_num == $end_vol * $freq )
                        )
                      )
                    {
                        $concat_range =~
s/^v\.$begin_vol\:no\.$orig_begin_num\-$orig_end_num/v.$begin_vol/;
                    }
                }
            }
        }

        if ($process_date) {

            # determine date ranges
            $end_date = ( $end =~ m/\(/ ) ? $end : '';
            $end_date =~ s/^.*\(//;
            $end_date =~ s/\)$//;
            $end_date =~ s/^.*\-\s*//;
            $end_date_year = ( $end_date =~ m/(\d{4}(?:\/\d{4})?)/ ) ? $1 : '';

            $begin_date = ( $begin =~ m/\(/ ) ? $begin : '';
            $begin_date =~ s/^.*\(//;
            $begin_date =~ s/\)$//;
            if ( $begin_date ne '' ) {
                ( $sub_date_a, $sub_date_b ) = split( /\s*\-\s*/, $begin_date );
                if (   $sub_date_a !~ m/\d{4}(?:\/\d{4})?/
                    && $sub_date_b =~ m/(\d{4}(?:\/\d{4})?)/ )
                {
# handle case where year only exists on right portion of date range (i.e. Jan-Jun 1999))
                    if ( $1 ne $end_date_year ) {
                        $begin_date = $sub_date_a . ' ' . $1;
                    }
                    else {
                        $begin_date =~ s/\s*\-.*$//;
                    }
                    $begin_date_year = $1;
                }
                else {
                    $begin_date =~ s/\s*\-.*$//;
                    $begin_date_year =
                      ( $begin_date =~ m/(\d{4}(?:\/\d{4})?)/ ) ? $1 : '';
                }
            }

            # build concat date
            if ( !$has_err ) {
                if ( $begin_date ne '' ) {
                    if ( $begin_date eq $end_date ) {

     # handle case where begin and end dates are the same; no need to show range
                        $concat_date = $begin_date;
                    }
                    elsif ($begin_date_year ne ''
                        && $begin_date_year eq $end_date_year )
                    {
                        if (   $begin_date eq $begin_date_year
                            || $end_date eq $end_date_year )
                        {
# handle case where begin and end dates are in the same year and one side only contains the year
                            $concat_date = $begin_date_year;
                        }
                        elsif ($begin_date =~ m/^Jan( $begin_date_year)?$/
                            && $end_date =~ m/^Dec $end_date_year$/ )
                        {
                    # handle case where begin and end dates span the entire year
                            $concat_date = $begin_date_year;
                        }
                        else {
         # handle case where no date ranges are present and the year is the same
                            $begin_date =~ s/\s*$begin_date_year//;
                            $concat_date = $begin_date . '-' . $end_date;
                        }
                    }
                    else {
                        if ( $begin_date_year ne $end_date_year ) {

                 # handle cases where begin and/or end dates span an entire year
                            $begin_date =~ s/^Jan //
                              if ( $begin_date =~ m/^Jan $begin_date_year$/ );
                            $end_date =~ s/^Dec //
                              if ( $end_date =~ m/^Dec $end_date_year$/ );
                        }
                        $concat_date = $begin_date . '-' . $end_date;
                    }
                    if ( $end_date ne '' ) {
                        ( $is_valid, $err_msg ) =
                          &crl_is_valid_date_or_range( $concat_date, 0 );
                    }
                }
                elsif ( $end_date ne '' ) {
                    $is_valid = 0;
                    $err_msg =
                      'Invalid date range: ' . $begin_date . '-' . $end_date;
                }
            }
        }

        if ( $process_range || $process_date ) {

            # build concat set
            $concat_range =~ s/v\.//g if ($date_as_vol);
            $concat_range = $new_series_id . $concat_range
              if ( $new_series_id ne '' );
            $concat_set = $concat_range if ( $concat_range ne '' );
            if ( $concat_date ne '' ) {
                $concat_set .= ' ' if ( $concat_set ne '' );
                $concat_set .= '(' . $concat_date . ')';
            }
        }
    }

    return ( $is_valid, $err_msg, $concat_set );
}

sub determine_gap {
    my ( $begin, $end, $freq_ref, $fh_ref, $info_ref, $opts_ref, $ctrl_num ) =
      @_;

    my (
        $gap,              $gap_range,    $gap_date,
        $is_valid,         $err_msg,      $has_err,
        $date_as_vol,      $freq,         $max_freq,
        $second_freq,      $freq_defined, $begin_range,
        $end_range,        $begin_date,   $begin_date_year,
        $begin_date_month, $end_date,     $end_date_year,
        $end_date_month,   $sub_date_a,   $sub_date_b,
        $begin_vol,        $begin_num,    $end_vol,
        $end_num,          $allow_gap,    $print_warning
    );

    $gap         = '';
    $gap_range   = '';
    $gap_date    = '';
    $is_valid    = 1;
    $err_msg     = '';
    $has_err     = 0;
    $date_as_vol = $info_ref->{'last_date_as_vol'};

    # set local vars to handle frequencies
    $freq        = $freq_ref->{'freq'};
    $max_freq    = $freq_ref->{'max_freq'};
    $second_freq = $freq_ref->{'second_freq'};

    # the date is treated like the volume; temporarily add in the volume id
    if ($date_as_vol) {
        $begin = 'v.' . $begin;
        $end   = 'v.' . $end;
    }

    # handle single volume, cross number holdings
    $begin =~
s/((v\.\d+[A-Za-z]?(?:\/\d+[A-Za-z]?)*\:no\.)\d+(?:\/\d+)*)-(?:no\.)?(\d+(?:\/\d+)*)/$1-$2$3/g;
    $end =~
s/((v\.\d+[A-Za-z]?(?:\/\d+[A-Za-z]?)*\:no\.)\d+(?:\/\d+)*)-(?:no\.)?(\d+(?:\/\d+)*)/$1-$2$3/g;

    $begin_range = $begin;
    $begin_range =~ s/\s*\(.*$//;
    $begin_range =~ s/^.*\-\s*//;

    $end_range = $end;
    $end_range =~ s/\s*\(.*$//;
    $end_range =~ s/\s*\-.*$//;

    $begin_date = ( $begin =~ m/\(/ ) ? $begin : '';
    $begin_date =~ s/^.*\(//;
    $begin_date =~ s/\)$//;
    $begin_date =~ s/^.*\-\s*//;

    #$begin_date_year = ($begin_date =~ m/(\d{4}(?:\/\d{4})?)/) ? $1 : '';

    $end_date = ( $end =~ m/\(/ ) ? $end : '';
    $end_date =~ s/^.*\(//;
    $end_date =~ s/\)$//;
    if ( $end_date =~ m/\-/ ) {
        ( $sub_date_a, $sub_date_b ) = split( /\s*\-\s*/, $end_date );
        if (   $sub_date_a !~ m/\d{4}(?:\/\d{4})?/
            && $sub_date_b =~ m/(\d{4}(?:\/\d{4})?)/ )
        {
# handle case where year only exists on right portion of date range (i.e. Jan-Jun 1999))
#if ($1 ne $begin_date_year) {
            $end_date = $sub_date_a . ' ' . $1;

            #} else {
            #	$end_date =~ s/\s*\-.*$//;
            #}
            #$end_date_year = $1;
        }
        else {
            $end_date =~ s/\s*\-.*$//;

            #$end_date_year = ($end_date =~ m/(\d{4}(?:\/\d{4})?)/ ) ? $1 : '';
        }
    }
    else {
        #$end_date_year = ($end_date =~ m/(\d{4}(?:\/\d{4})?)/ ) ? $1 : '';
    }

    # TODO: process parts
    if ( $begin_range =~ m/^v\.(\d+(?:\/\d+)?)(?::no\.(\d+(?:\/\d+)?))?$/ ) {
        ( $begin_vol, $begin_num ) = ( $1, $2 );
        ( $err_msg, $has_err, undef, $begin_vol ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $begin_vol );
        ( $err_msg, $has_err, undef, $begin_num ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $begin_num )
          if ( defined($begin_num) );
    }
    elsif ( $begin_range =~ m/^no\.(\d+(?:\/\d+)?)$/ ) {
        $begin_num = $1;
        ( $err_msg, $has_err, undef, $begin_num ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $begin_num );
    }

    if ( $end_range =~ m/^v\.(\d+(?:\/\d+)?)(?::no\.(\d+(?:\/\d+)?))?$/ ) {
        ( $end_vol, $end_num ) = ( $1, $2 );
        ( $err_msg, $has_err, $end_vol, undef ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $end_vol );
        ( $err_msg, $has_err, $end_num, undef ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $end_num )
          if ( defined($end_num) );
    }
    elsif ( $end_range =~ m/^no\.(\d+(?:\/\d+)?)$/ ) {
        $end_num = $1;
        ( $err_msg, $has_err, $end_num, undef ) =
          &process_joined_set( $fh_ref, $err_msg, $has_err, $end_num );
    }

# build gap range
# TODO: handle freq when determining start/end numbers of gap
# TODO: determine when no gap should exist, i.e. monographic serials? (OCLC: 25987790)
# TODO: handle case where no vol/num info included (i.e. JSTOR OCLC: 01565060)
    if (   defined($begin_vol)
        && defined($end_vol)
        && !defined($begin_num)
        && !defined($end_num) )
    {
        # volumes only
        $begin_vol++;
        $end_vol--;
        if ( $begin_vol == $end_vol ) {
            $gap_range = 'v.' . $begin_vol;
        }
        elsif ( $end_vol > $begin_vol && $end_vol - $begin_vol < 500 ) {
            $gap_range = 'v.' . $begin_vol . '-v.' . $end_vol;
        }
        else {
            # TODO: print warning?
            # do not create gaps when volume switches to year-based volume
            $info_ref->{'gaps'}->{'display'} = 0;
        }
    }
    elsif (defined($begin_num)
        && defined($end_num)
        && !defined($begin_vol)
        && !defined($end_vol) )
    {
        # numbers only
        $begin_num++;
        $end_num--;
        if ( $begin_num == $end_num ) {
            $gap_range = 'no.' . $begin_num;
        }
        elsif ( $end_num > $begin_num ) {
            $gap_range = 'no.' . $begin_num . '-no.' . $end_num;
        }
        else {
            # do not create gaps when gap is nonsensical
            $info_ref->{'gaps'}->{'display'} = 0;
        }
    }
    elsif (defined($begin_vol)
        && defined($end_vol)
        && !defined($begin_num)
        && defined($end_num) )
    {
        # both volumes, but only the end number
        $begin_vol++;
        $end_num--;
        $end_vol-- if ( $end_num == 0 );
        if ( $begin_vol == $end_vol ) {
            if ( $end_num == 0 ) {
                $gap_range = 'v.' . $begin_vol;
            }
            elsif ( $end_num == 1 ) {
                $gap_range = 'v.' . $begin_vol . ':no.1';
            }
            else {
                $gap_range = 'v.' . $begin_vol . ':no.1-' . $end_num;
            }
        }
        elsif ( $end_vol > $begin_vol ) {
            $gap_range = 'v.' . $begin_vol . '-v.' . $end_vol;
            $gap_range .= ':no.' . $end_num if ( $end_num != 0 );
        }
        else {
            # do not create gaps when gap is nonsensical
            $info_ref->{'gaps'}->{'display'} = 0;
        }
    }
    elsif ( defined($begin_vol) && defined($end_vol) && defined($begin_num) ) {

        # TODO: process case where both vols and nums exist
        # use freq (and math) to get best output
        if ( $begin_vol == $end_vol && defined($end_num) ) {

            # volume is the same; number only gap
            $begin_num++;
            $end_num--;
            if ( $begin_num == $end_num ) {
                $gap_range = 'v.' . $begin_vol . ':no.' . $begin_num;
            }
            elsif ( $end_num > $begin_num ) {
                $gap_range =
                  'v.' . $begin_vol . ':no.' . $begin_num . '-' . $end_num;
            }
            else {
                # do not create gaps when gap is nonsensical
                $info_ref->{'gaps'}->{'display'} = 0;
            }
        }
        elsif ($freq != 0
            && $begin_num <= $freq
            && ( !defined($end_num) || $end_num <= $freq ) )
        {
            # TODO: attempt w/ min freq?
            # volume is different; numbers within frequency ranges
            $begin_num++;
            if ( $begin_num > $freq ) {
                $begin_num = 1;
                $begin_vol++;
            }
            $end_num = 1 if ( !defined($end_num) );
            $end_num--;
            if ( $end_num == 0 ) {
                $end_num = $freq;
                $end_vol--;
            }
            if ( $begin_vol eq $end_vol ) {
                if ( $begin_num == 1 && $end_num == $freq ) {
                    $gap_range = 'v.' . $begin_vol;
                }
                elsif ( $begin_num == $end_num ) {
                    $gap_range = 'v.' . $begin_vol . ':no.' . $begin_num;
                }
                elsif ( $end_num > $begin_num ) {
                    $gap_range =
                      'v.' . $begin_vol . ':no.' . $begin_num . '-' . $end_num;
                }
                else {
                    # do not create gaps when gap is nonsensical
                    $info_ref->{'gaps'}->{'display'} = 0;
                }
            }
            elsif ( $end_vol > $begin_vol ) {
                $gap_range = 'v.' . $begin_vol;
                $gap_range .= ':no.' . $begin_num if ( $begin_num != 1 );
                $gap_range .= '-v.' . $end_vol;
                $gap_range .= ':no.' . $end_num   if ( $end_num != $freq );
            }
            else {
                # do not create gaps when gap is nonsensical
                $info_ref->{'gaps'}->{'display'} = 0;
            }
        }
        elsif ($second_freq != 0
            && $begin_num > $second_freq
            && $begin_num <= $max_freq )
        {
          # volume is different; begin number higher than all freqencies but one
            $begin_num++;
            if ( $begin_num > $max_freq ) {
                $begin_num = 1;
                $begin_vol++;
            }

            if ( !defined($end_num) || $end_num == 1 ) {
                $end_num = $max_freq;
                $end_vol--;
            }
            else {
                $end_num--;
            }

            if ( $begin_vol eq $end_vol ) {
                if ( $begin_num == 1 && $end_num == $max_freq ) {
                    $gap_range = 'v.' . $begin_vol;
                }
                elsif ( $begin_num == $end_num ) {
                    $gap_range = 'v.' . $begin_vol . ':no.' . $begin_num;
                }
                elsif ( $end_num > $begin_num ) {
                    $gap_range =
                      'v.' . $begin_vol . ':no.' . $begin_num . '-' . $end_num;
                }
                else {
                    # do not create gaps when gap is nonsensical
                    $info_ref->{'gaps'}->{'display'} = 0;
                }
            }
            elsif ( $end_vol > $begin_vol ) {
                $gap_range = 'v.' . $begin_vol;
                $gap_range .= ':no.' . $begin_num if ( $begin_num != 1 );
                $gap_range .= '-v.' . $end_vol;
                $gap_range .= ':no.' . $end_num   if ( $end_num != $max_freq );
            }
            else {
                # do not create gaps when gap is nonsensical
                $info_ref->{'gaps'}->{'display'} = 0;
            }

            if ( $gap_range ne '' ) {
                if ( $info_ref->{'gaps'}->{'prompt'} ) {
                    ( $allow_gap, $print_warning ) =
                      &gap_prompt( $info_ref, $opts_ref, $ctrl_num, $gap_range )
                      if ( !$opts_ref->{'p'} );
                }
                else {
                    $allow_gap = $info_ref->{'gaps'}->{'display'};
                }

                &crl_print_warning( $fh_ref->{'WARNING'},
                        'ID: '
                      . $ctrl_num
                      . ', Potential holdings gap; please confirm: '
                      . $gap_range )
                  if ($print_warning);
                if ( !$allow_gap ) {
                    $gap_range = '';
                    $info_ref->{'gaps'}->{'display'} = 0;
                }
            }
        }
        else {
            $info_ref->{'gaps'}->{'display'} = 0;
        }
    }
    elsif ( $begin_range eq '' && $end_range eq '' && $freq_ref->{'defined'} ) {
        my (
            $join_begin_date,      $join_end_date,
            $begin_date_month_num, $end_date_month_num
        );

        if ( $begin_date =~ m/^\d{4}(\/\d{4})?$/ ) {
            ( $err_msg, $has_err, $join_begin_date, $begin_date ) =
              &process_joined_set( $fh_ref, $err_msg, $has_err, $begin_date );
            if ( $join_begin_date == $begin_date ) {
                undef $join_begin_date;
            }
            else {
                $join_begin_date++;
            }
            $begin_date++;
        }
        elsif ( $begin_date =~ m/^[A-Z][a-z]{2,3} \d{4}$/ ) {
            if ( $freq != $max_freq ) {
                $info_ref->{'gaps'}->{'display'} = 0;
            }
            elsif ( $freq != 0 && $freq != 12 ) {

                # can only create reliable gaps for annual and monthly holdings
                &crl_print_warning( $fh_ref->{'WARNING'},
                        'ID: '
                      . $ctrl_num
                      . ', Gaps must be created manually for frequencies other than annual and monthly'
                ) if ( $info_ref->{'gaps'}->{'process'} );
                $info_ref->{'gaps'}->{'display'} = 0;
                $info_ref->{'gaps'}->{'process'} = 0;
            }
            else {
                ( $begin_date_month, $begin_date_year ) =
                  split( /\s+/, $begin_date );
                $begin_date_month_num = &crl_get_month_num($begin_date_month);
                $begin_date_month_num++;
                if ( $begin_date_month_num == 13 ) {
                    $begin_date_year++;
                    $begin_date_month_num = 1;
                }
                $begin_date = &crl_get_month_name( $begin_date_month_num, 1 ) . ' '
                  . $begin_date_year;
            }
        }
        else {
            $info_ref->{'gaps'}->{'display'} = 0;
        }

        if ( $end_date =~ m/^\d{4}(\/\d{4})?$/ ) {
            ( $err_msg, $has_err, $end_date, $join_end_date ) =
              &process_joined_set( $fh_ref, $err_msg, $has_err, $end_date );
            if ( $join_end_date == $end_date ) {
                undef $join_end_date;
            }
            else {
                $join_end_date--;
            }
            $end_date--;
        }
        elsif ( $end_date =~ m/^[A-Z][a-z]{2,3} \d{4}$/ ) {
            if ( $freq != $max_freq ) {
                $info_ref->{'gaps'}->{'display'} = 0;
            }
            elsif ( $freq != 0 && $freq != 12 ) {

                # can only create reliable gaps for annual and monthly holdings
                &crl_print_warning( $fh_ref->{'WARNING'},
                        'ID: '
                      . $ctrl_num
                      . ', Gaps must be created manually for frequencies other than annual and monthly'
                ) if ( $info_ref->{'gaps'}->{'process'} );
                $info_ref->{'gaps'}->{'display'} = 0;
                $info_ref->{'gaps'}->{'process'} = 0;
            }
            else {
                ( $end_date_month, $end_date_year ) = split( /\s+/, $end_date );
                $end_date_month_num = &crl_get_month_num($end_date_month);
                $end_date_month_num--;
                if ( $end_date_month_num == 0 ) {
                    $end_date_year--;
                    $end_date_month_num = 12;
                }
                $end_date = &crl_get_month_name( $end_date_month_num, 1 ) . ' '
                  . $end_date_year;
            }
        }
        else {
            $info_ref->{'gaps'}->{'display'} = 0;
        }

        if ( $info_ref->{'gaps'}->{'display'} ) {
            if ( $begin_date eq $end_date ) {
                if ( defined($join_begin_date) || defined($join_end_date) ) {
                    $gap_date = '';
                    $gap_date .= $join_begin_date . '/'
                      if ( defined($join_begin_date) );
                    $gap_date .= $begin_date . '-' . $end_date;
                    $gap_date .= '/' . $join_end_date
                      if ( defined($join_end_date) );
                }
                else {
                    $gap_date = $begin_date;
                }
            }
            elsif ( defined($begin_date_year) && defined($end_date_year) ) {
                if ( $begin_date_year == $end_date_year ) {
                    $begin_date =~ s/ $begin_date_year//;
                }
                elsif ( $begin_date_month_num == 1 ) {
                    $begin_date =~ s/^Jan //;
                }
                $gap_date = $begin_date . '-' . $end_date;
            }
            elsif ( !defined($begin_date_year)
                && defined($end_date_year)
                && $begin_date == $end_date_year )
            {
                if ( $end_date_month_num == 1 ) {
                    $gap_date = $end_date;
                }
                else {
                    $gap_date = 'Jan' . '-' . $end_date;
                }
            }
            else {
                $gap_date = '';
                $gap_date .= $join_begin_date . '/'
                  if ( defined($join_begin_date) );
                $gap_date .= $begin_date;
                if (   defined($join_begin_date)
                    && defined($join_end_date)
                    && $join_end_date == $join_begin_date + 1 )
                {
                    #only one holding exists as gap; do not display duplicate
                }
                else {
                    $gap_date .= '-' . $end_date;
                    $gap_date .= '/' . $join_end_date
                      if ( defined($join_end_date) );
                }
            }
        }
    }
    else {
        $info_ref->{'gaps'}->{'display'} = 0;
    }

# build gap date
#if (!$has_err && $begin_date ne '' && $end_date ne '' && $gap_date eq '') {
#	if ($begin_date eq $end_date) {
#		# handle case where begin and end dates are the same; no need to show range
#		$gap_date = $begin_date;
#	} elsif ($begin_date_year ne '' && $begin_date_year eq $end_date_year) {
#		if ($begin_date eq $begin_date_year || $end_date eq $end_date_year) {
#			# handle case where begin and end dates are in the same year and one side only contains the year
#			$gap_date = $begin_date_year;
#		} elsif ($begin_date =~ m/^Jan( $begin_date_year)?$/ && $end_date =~ m/^Dec $end_date_year$/) {
#			# handle case where begin and end dates span the entire year
#			$gap_date = $begin_date_year;
#		} else {
#			# handle case where no date ranges are present and the year is the same
#			$begin_date =~ s/\s*$begin_date_year//;
#			$gap_date = $begin_date.'-'.$end_date;
#		}
#	} else {
#		if ($begin_date_year ne $end_date_year) {
#			# handle cases where begin and/or end dates span an entire year
#			$begin_date =~ s/^Jan //
#			  if ($begin_date =~ m/^Jan $begin_date_year$/);
#			$end_date =~ s/^Dec //
#			  if ($end_date =~ m/^Dec $end_date_year$/);
#		}
#		$gap_date = $begin_date.'-'.$end_date;
#	}
#	($is_valid, $err_msg) = &crl_is_valid_date_or_range($gap_date, 0);
#}

    # build gap
    $gap_range =~ s/v\.//g if ($date_as_vol);
    $gap = $gap_range if ( $gap_range ne '' );
    if ( $gap_date ne '' ) {
        $gap .= ' ' if ( $gap ne '' );
        $gap .= '(' . $gap_date . ')';
    }

    return ( $is_valid, $err_msg, $gap );
}

sub concat_prompt {
    my ( $can_concat, $info_ref, $opts_ref, $ctrl_num,
        $compare_holdings_string ) = @_;

    my ( $retry, $response, $print_warning );

    $print_warning = 1;
    do {
        $retry = 0;
        print STDOUT 'Should these holdings for ID '
          . $ctrl_num
          . ' be concatenated?'
          . &crl_get_EOL();
        print STDOUT $compare_holdings_string . &crl_get_EOL();
        print STDOUT '[Y]es, [N]o, [L]ater or [S]kip' . &crl_get_EOL();
        $response = <STDIN>;
        $response =~ s/\s*$//;
        if ( $response =~ m/^Y(es)?$/i ) {
            $can_concat                                = 1;
            $info_ref->{'concat'}->{'new'}->{'concat'} = 1;
            $print_warning                             = 0;
        }
        elsif ( $response =~ m/^N(o)?$/i ) {
            $can_concat = 0;
            $info_ref->{'concat'}->{'new'}->{'nonconcat'} = 1;
            push(
                @{$info_ref->{'concat'}->{'new'}->{'nonconcat_holdings'}},
                $compare_holdings_string
            );
            $print_warning = 0;
        }
        elsif ( $response =~ m/^L(ater)?$/i ) {

            # proceed as normal; no action taken
        }
        elsif ( $response =~ m/^S(kip)?$/i ) {

            # proceed as normal; set skip remainder flag to true
            $opts_ref->{'p'} = 1;
        }
        else {
            print STDOUT 'Unrecognized input: ' . $response . &crl_get_EOL();
            $retry = 1;
        }
    } while ($retry);

    return ( $can_concat, $print_warning );
}

# searches the concerns list for a specific type (uses abbreviated versions for ease of use)
sub has_concern {
    my ( $concerns, $concern_abbr ) = @_;

    my ( $has_concern, $concern );

  # update hasUserGenConcern sub in normalization script when new concerns added

    $has_concern = 0;
    if ( defined($concerns) && $concerns ne '' ) {
        foreach $concern ( split( /\;\s*/, $concerns ) ) {
            $has_concern = 1
              if (
                ( $concern_abbr eq 'concat' && $concern eq 'Concatenateable' )
                || (   $concern_abbr eq 'nonconcat'
                    && $concern =~ m/^Non\-concatenateable/ )
                || (   $concern_abbr eq 'enum'
                    && $concern eq 'Acceptable enumeration' )
                || ( $concern_abbr eq 'gaps' && $concern eq 'Gaps acceptable' )
                || (   $concern_abbr eq 'no_gaps'
                    && $concern eq 'Gaps not acceptable' )
              );
        }
    }

    return $has_concern;
}

sub can_concat {
    my ( $default_concat, $consider_concat, $ctrl_num, $info_ref, $fh_ref,
        $opts_ref, $compare_holdings_string )
      = @_;

    my (
        $num_concerns,  $inc_concat, $inc_nonconcat,
        $inc_enum,      $inc_gaps,   $inc_no_gaps,
        $print_warning, $can_concat, $process_gap
    );

    $num_concerns  = scalar( split( /;\s*/, $info_ref->{'concerns'} ) );
    $inc_concat    = $info_ref->{'concat'}->{'orig'}->{'concat'};
    $inc_nonconcat = $info_ref->{'concat'}->{'orig'}->{'nonconcat'};
    $inc_enum      = &has_concern( $info_ref->{'concerns'}, 'enum' );
    $inc_gaps      = &has_concern( $info_ref->{'concerns'}, 'gaps' );
    $inc_no_gaps   = &has_concern( $info_ref->{'concerns'}, 'no_gaps' );
    $print_warning = 1;
    $can_concat    = $default_concat;

    if ( $info_ref->{'concerns'} eq ''
        || ( $num_concerns == 1 && ( $inc_enum || $inc_gaps || $inc_no_gaps ) )
      )
    {
        ( $can_concat, $print_warning ) =
          &concat_prompt( $default_concat, $info_ref, $opts_ref, $ctrl_num,
            $compare_holdings_string )
          if ( !$opts_ref->{'p'} && !$default_concat );
    }
    elsif ( !$inc_concat && !$inc_nonconcat ) {
        ( $can_concat, $print_warning ) =
          &concat_prompt( $default_concat, $info_ref, $opts_ref, $ctrl_num,
            $compare_holdings_string )
          if ( !$opts_ref->{'p'} );
    }
    elsif ($inc_concat) {
        $can_concat = 1;
    }
    elsif ($inc_nonconcat) {
        my $nonconcat_holdings = $info_ref->{'concerns'};
        $nonconcat_holdings =~ s/^.*Non-concatenateable\s*//;
        $nonconcat_holdings =~ s/;.*$//;
        if ( $nonconcat_holdings ne '' ) {
            $nonconcat_holdings =~ s/^\(//;
            $nonconcat_holdings =~ s/\)$//;

            $can_concat = 1;
            foreach ( split( /\s*\&\&\s*/, $nonconcat_holdings ) ) {
                $can_concat = 0
                  if ( $_ eq $compare_holdings_string );
            }
        }
        else {
            $can_concat = 0;
        }
        $print_warning = 0;
    }

    $print_warning = 0 if ($can_concat);
    &crl_print_warning( $fh_ref->{'WARNING'},
            'ID: '
          . $ctrl_num
          . ', Manual concatenation may be necessary; please confirm: '
          . $compare_holdings_string )
      if ($print_warning);

    $process_gap = !$can_concat;
    $can_concat = 0 if ( !$consider_concat );

    return ( $can_concat, $process_gap );
}

# determines whether the current max num is appropriate, given the frequency and the current holdings
sub reset_max_num {
    my ( $fh_ref, $info_ref, $ctrl_num, $holdings, $freq_ref, $vol, $num ) = @_;

    my ( $reset_max_num, $has_enum, $freq, $max_freq, );

    $reset_max_num = 0;
    $has_enum      = &has_concern( $info_ref->{'concerns'}, 'enum' );
    $freq          = $freq_ref->{'freq'};
    $max_freq = ( $freq_ref->{'max_freq'} != 0 ) ? $freq_ref->{'max_freq'} : 12;

    if ( $freq != 0 && defined($num) && $num > $freq + 1 ) {
        if ( $num < ( $vol * $freq - $freq + 1 ) || $num > ( $vol * $freq ) ) {
            &crl_print_warning( $fh_ref->{'WARNING'},
                    'ID: '
                  . $ctrl_num
                  . ', Potentially nonstandard enumeration discovered in holdings: '
                  . $holdings )
              if ( !$has_enum );
        }
        $reset_max_num = 1;
    }

#&crl_print_debug($fh_ref->{'DEBUG'}, 'ID: '.$ctrl_num.', Number over by one discovered in holdings: '.$holdings)
#  if ($freq != 0 && defined($num) && $num == $freq + 1);
    if (  !$reset_max_num
        && $max_freq != 0
        && defined($num)
        && $num > $max_freq + 1 )
    {
        if (   $num < ( $vol * $max_freq - $max_freq + 1 )
            || $num > ( $vol * $max_freq ) )
        {
            &crl_print_warning( $fh_ref->{'WARNING'},
                    'ID: '
                  . $ctrl_num
                  . ', Potentially nonstandard enumeration discovered in holdings: '
                  . $holdings )
              if ( !$has_enum );
        }
    }

    return $reset_max_num;
}

sub gap_prompt {
    my ( $info_ref, $opts_ref, $ctrl_num, $gap_range ) = @_;

    my ( $retry, $response, $allow_gap, $print_warning );

    $allow_gap     = 0;
    $print_warning = 1;
    do {
        $retry = 0;
        print STDOUT 'Is this an acceptable gap for ID '
          . $ctrl_num . '?'
          . &crl_get_EOL();
        print STDOUT $gap_range . &crl_get_EOL();
        print STDOUT '[Y]es, [N]o, [L]ater or [S]kip' . &crl_get_EOL();
        $response = <STDIN>;
        $response =~ s/\s*$//;
        if ( $response =~ m/^Y(es)?$/i ) {
            $allow_gap                            = 1;
            $info_ref->{'gaps'}->{'gaps_allowed'} = 1;
            $print_warning                        = 0;
        }
        elsif ( $response =~ m/^N(o)?$/i ) {
            $allow_gap                            = 0;
            $info_ref->{'gaps'}->{'gaps_allowed'} = 0;
            $print_warning                        = 0;
        }
        elsif ( $response =~ m/^L(ater)?$/i ) {

            # proceed as normal; no action taken
        }
        elsif ( $response =~ m/^S(kip)?$/i ) {

            # proceed as normal; set skip remainder flag to true
            $opts_ref->{'p'} = 1;
        }
        else {
            print STDOUT 'Unrecognized input: ' . $response . &crl_get_EOL();
            $retry = 1;
        }
    } while ($retry);

    return ( $allow_gap, $print_warning );
}

1;
