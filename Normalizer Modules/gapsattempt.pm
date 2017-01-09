package Normalizer::gapsattempt;

# TODO:
#use strict;
#use warnings;

our (@ISA, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        gapsattempt
    );
    %EXPORT_TAGS = ('all' => \@EXPORT_OK);
}
binmode(STDOUT, ":encoding(utf8)");     #treat as if it is UTF-8
binmode(STDIN, ":encoding(utf8)");      #actually check if it is UTF-8W
binmode(STDERR, ":encoding(utf8)");

use open ':std', ':encoding(UTF-8)';

use utf8;
#use v5.14;

#	Takes as input the normalized holdings string + the frequency

sub gapsattempt{
	$tocompress = shift;
	$tocompress =~ s/,+/,/g;
	$tocompress =~ s/, /,/g;
	$tocompress =~ s/;/,/g;
	@compressed= ();
	@tocompress = split(/,/, $tocompress);
	if (@tocompress <= 1) {
		$totalmissing = "";
		return ($totalmissing);
	} else {
		$againflag = 0;
		$frequency = shift;
		$totalmissing = "";
		$missingyears = "";
		for($a = 0; $a < @tocompress; $a++)	{
			##	for($c=0; $c<30000000; $c++)	{
			##	}
			$b = $a + 1;
			##	for($c=0; $c<30000000; $c++)	{
			##	}
			##	take the last number from all the first expression
			$myno = "";
			if($tocompress[$a] =~ m/no\.([0-9]{1,3})/)	{
				@myno = ($tocompress[$a] =~ m/no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3}/g);
				$myno = pop(@myno);
				if ($myno =~ m/([0-9]{1,3})$/)	{
					$myno = $1;
				}

			} 
			$myfirstvol = "";
			##	take the last volume number from the first expression
			if($tocompress[$a] =~ m/v\.([0-9]{1,3})/)	{
				@myvol = ($tocompress[$a] =~ m/v\.[0-9]{1,3}\/*[0-9]{0,3}-*v*\.*[0-9]{0,3}\/*[0-9]{0,3}/g);
				$myfirstvol = pop(@myvol);
				if ($myfirstvol =~ m/([0-9]{1,3})$/)	{
					$myfirstvol = $1;
				}
			} 
			##	take the first vol number of the next expression
			$mynextvol = ""; 
			if($tocompress[$b] =~ m/v\.([0-9]{1,3})/)	{
				@mynextvol = ($tocompress[$b] =~ m/v\.[0-9]{1,3}\/*[0-9]{0,3}-*v*\.*[0-9]{0,3}\/*[0-9]{0,3}/g);
				$mynextvol = shift(@mynextvol);
				if ($mynextvol =~ m/^v\.([0-9]{1,3})/)	{
					$mynextvol = $1 ;
				}
			}
			##	take the first no. number of the next expression or set it to null
			$mynextno = "";
			if($tocompress[$b] =~ m/no\.([0-9]{1,3})/)	{
				@mynextno = ($tocompress[$b] =~ m/no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3}/g);
				$mynextno = shift(@mynextno);
				if ($mynextno =~ m/^no\.([0-9]{1,3})/)	{
					$mynextno = $1;
				}
			} 
			if($tocompress[$b] =~ m/-.*no\.([0-9]{1,3})/)	{
				if($mynextno eq $1)	{
					if( @mynextno == 0)	{
						$mynextno = 1;
					}
				}
			}
			##	take the last year from the first entry
			$myyear = "";
			if($tocompress[$a] =~ m/[0-9]{4}/)	{
				@myyear = ($tocompress[$a] =~ m/[0-9]{4}/g);
				$myyear = pop(@myyear);
			}
			##	take the first year from the second entry
			$mynextyear = "";
			if($tocompress[$b] =~ m/[0-9]{4}/)	{
				@mynextyear = ($tocompress[$b] =~ m/[0-9]{4}/g);
				$mynextyear = shift(@mynextyear);
			}
			##	use the collected years to create a missing year range
			if($myyear != "")	{
				$myyear += 1;
				$mynextyear -= 1;
				if ($mynextyear > $myyear)	{
					$missingyears = " (" . $myyear . "-" . $mynextyear . ")";
				} elsif($mynextyear == $myyear) {
					$missingyears = " (" . $myyear . ")";
				} else {
					$missingyears = "";
				}
			} else{
				$missingyears = "";
			}
			##	take the last year from the second entry
			$mylastyear = "";
			if($tocompress[$b] =~ m/[0-9]{4}/)	{
				@mylastyear = ($tocompress[$b] =~ m/[0-9]{4}/g);
				$mylastyear = pop(@mylastyear);
			}
			##	take the first year from the first entry
			$myfirstyear = "";
			if($tocompress[$a] =~ m/[0-9]{4}/)	{
				@myfirstyear = ($tocompress[$a] =~ m/[0-9]{4}/g);
				$myfirstyear = shift(@myfirstyear);
			}
			##	take the first no and vol expression froms the first entry
			$initialno = "";
			if($tocompress[$a] =~ m/no\.([0-9]{1,3})/)	{
				@$initialno = ($tocompress[$a] =~ m/no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3}/g);
				$initialno = shift(@$initialno);
				if ($initialno =~ m/^no\.([0-9]{1,3})(\/*[0-9]{0,3})/)	{
					$initialno = $1;
				}
			}
			$initialvol = "";
			if($tocompress[$a] =~ m/v\.([0-9]{1,3})/)	{
				@initialvol = ($tocompress[$a] =~ m/v\.[0-9]{1,3}\/*[0-9]{0,3}-*v*\.*[0-9]{0,3}\/*[0-9]{0,3}/g);
				$initialvol = shift(@initialvol);
				if ($initialvol =~ m/^v\.([0-9]{1,3})(\/*[0-9]{0,3})/)	{
					$initialvol = $1;
				}
			}
			$myendingvol = "";
			if($tocompress[$b] =~ m/v\.([0-9]{1,3})/)	{
				@myendingvol = ($tocompress[$b] =~ m/v\.[0-9]{1,3}\/*[0-9]{0,3}-*v*\.*[0-9]{0,3}\/*[0-9]{0,3}/g);
				$myendingvol = pop(@myendingvol);
				if ($myendingvol =~ m/([0-9]{0,3}\/*)([0-9]{1,3})$/)	{
					$myendingvol = $2;
				}
			} 
			##	take the last no. expression from the second entry
			$myendingno = "";
			if($tocompress[$b] =~ m/no\.([0-9]{1,3})/)	{
				@$myendingno = ($tocompress[$b] =~ m/no\.[0-9]{1,3}\/*[0-9]{0,3}-*[0-9]{0,3}\/*[0-9]{0,3}/g);
				$myendingno = pop(@$myendingno);
				if ($myendingno =~ m/([0-9]{0,3}\/*)([0-9]{1,3})$/)	{
					$myendingno = $2;
				}
			}
			if ($myno eq "")	{
				if ($myfirstvol != "")	{
					if ($mynextvol != "")	{
						if ($mynextno != "")	{
							$myfirstvol += 1;
							$mynextno -= 1;
							if($mynextno == 1)	{
								$mymissing = "v." . $myfirstvol . "-v." . $mynextvol . ":no.1" ;
							} elsif ($mynextno == 0)	{
								if($mynextvol > $myfirstvol)	{
									$mynextvol -= 1;
									$mymissing = "v." . $myfirstvol . "-v." . $mynextvol;
								}
							} else {
								$mymissing = "v." . $myfirstvol . "-v." . $mynextvol . ":no." . $mynextno;
							}
							if($myfirstvol == $mynextvol)	{
								$mymissing =~ s/-v\.[0-9]{1,3}//g;
								if($mymissing !~ m/no\.1( |$)/)	{
									$mymissing =~ s/no\./no\.1-/g;
								}
							}
						} else {
							$mynextvol -= 1;
							$myfirstvol += 1;
							if($mynextvol > $myfirstvol)	{
								$mymissing = "v." . $myfirstvol . "-v." . $mynextvol . $missingyears;
								if($tocompress[$a] =~ m/\)-/)	{
									$mymissing = "v." . $myfirstvol . "-v." . $mynextvol;
								}
							} elsif ($mynextvol == $myfirstvol) {
								if($missingyears =~ m/-/ || $tocompress[$a] =~ m/\)-/)	{
									$mymissing = "v." . $myfirstvol;
								} else {
									$mymissing = "v." . $myfirstvol . $missingyears;
								}
							} else	{
								if($tocompress[$b] =~ /pt.(\d+)/)	{
									$ptnum = $1;
									$ptnum -= 1;
									if($ptnum > 0)	{
										$mynextvol +=1;
										$mymissing = "v." . $mynextvol . ":pt." . $ptnum;
									} else {
										$mymissing = $missingyears;
									}
								} else {
									$mymissing = $missingyears;
								}
							}
						}
					} else {
						$mymissing = $missingyears;
					}
				} else {
					if($mynextno > 1 && $tocompress[$b] =~ m/:no/ && $tocompress[$b] !~ m/v\./)	{
						if($myyear > $mynextyear)	{
							$mynextno -=1;
							$mymissing =  $mylastyear. ":no.1-" . $mynextno;
							$mymissing =~ s/no\.1-1$/no\.1/g;
						} else {
							$mymissing = $missingyears;
						}
					} else {
						$mymissing = $missingyears;
					}
				}
			} else {
				if ($myfirstvol != "")	{
					if ($mynextvol != "")	{
						if ($mynextno != "")	{
							$mynextno -= 1;
							$myno += 1;
							if($myno > $frequency && $frequency != "")	{
								if($frequency > 1)	{
									$myfirstvol += 1;
									if($mynextno == 1)	{
										$mymissing = "v." . $myfirstvol . "-v." . $mynextvol . ":no.1";
									} elsif($mynextno == 0) {
										$mynextvol -= 1;
										$mymissing = "v." . $myfirstvol . "-v." . $mynextvol;
									}
					#		Nate added check to avoid this: "v.76-v.75:no.299"				
									elsif ($myfirstvol > $mynextvol)	{
										$mymissing = "v." . $mynextvol . ":no." . $mynextno;
									}
									else {
										$mymissing = "v." . $myfirstvol . "-v." . $mynextvol . ":no." . $mynextno;
					#		Nate added check against $frequency and else statement in order to guard against something like "v.20:no.158: becoming "v.20:no.1-158" 
										if($myfirstvol == $mynextvol && $mynextno <= $frequency)	{	#	todo here
											$mymissing = "v." . $mynextvol . ":no.1-" . $mynextno;
											$mymissing =~ s/1-1/1/g;
										}
										elsif($myfirstvol == $mynextvol && $mynextno > $frequency)	{
											$mymissing = "v." . $mynextvol . ":no." . $mynextno;
											$mymissing =~ s/1-1/1/g;
										}
									}
									if($myfirstvol == $mynextvol)	{
										$mymissing =~ s/-v\.[0-9]{1,3}//g;
									}
									$mymissing =~ s/:no\.0//g;
								}
							} else {
								if($mynextno == 0)	{
									if($frequency > 1)	{
										if($mynextvol == $myfirstvol +1)	{
											if($myno != $frequency)	{
												$mymissing = "v." . $myfirstvol . ":no." . $myno . "-" . $frequency;
											} else {
												$mymissing = "v." . $myfirstvol . ":no." . $myno;
											}
										} else {
											$mynextvol -= 1;
											if($myfirstvol < $mynextvol)	{
												$mymissing = "v." . $myfirstvol . ":no." . $myno . "-v." . $mynextvol;
											} else {
												$mymissing = "v." . $myfirstvol . ":no." . $myno;
											}
										}
									} else {
										if($mynextvol > $myfirstvol +1)	{
											$mynextvol -= 1;
											$myfirstvol += 1;
											if($myfirstvol == $mynextvol)	{
												$mymissing = "v." . $myfirstvol;
											} else {
												$mymissing = "v." . $myfirstvol . "-v." . $mynextvol;
											}
										}
									}
								} else {
									if($mynextvol == $myfirstvol)	{
										if($myno != $mynextno)	{
											$mymissing = "v." . $myfirstvol . ":no." . $myno . "-" . $mynextno;
										} else {
											$mymissing = "v." . $myfirstvol . ":no." . $myno;
										}
									} else {
										$mymissing = "v." . $myfirstvol . ":no." . $myno . "-v." . $mynextvol . ":no." . $mynextno;
										if($tocompress[$a] !~ m/-v\.\d+:no\./ && $tocompress[$a] =~ m/-v\./)	{
											$myfirstvol += 1;
											$mymissing = "v." . $myfirstvol . "-" . $mynextvol . ":no." . $mynextno;
											if($mynextvol == $myfirstvol)	{
												$mymissing = "v." . $mynextvol . ":no.1-" . $mynextno;
												$mymissing =~ s/1-1$/1/g;
											}
										}
										if($frequency < 1)	{
											if($mynextvol == $myfirstvol + 1)	{
												if($mynextno < 1)	{
													$mymissing = "";
						#	Nate added check against frequency to avoid things like "v.10:no.39" becoming "v.10:no.1-39"
												} elsif ($mynextno > $frequency) {
													$mymissing = "v." . $mynextvol . ":no." . $mynextno;
													$mymissing =~ s/1-1$/1/g;
												}
												else	{
													$mymissing = "v." . $mynextvol . ":no.1-" . $mynextno;
													$mymissing =~ s/1-1$/1/g;
												}
											}
											else{
												$myfirstvol +=1;
												if($mynextvol == $myfirstvol)	{
													$mymissing = "v." . $myfirstvol . ":no.1-" . $mynextno;
													$mymissing =~ s/1-1$/1/g;
												} else {
													$mymissing = "v." . $myfirstvol . "-v." . $mynextvol . ":no." . $mynextno;
													$mymissing =~ s/1-1$/1/g;
												}
											}
										}
									}
								}
							}
						} else {
							if($frequency > 1)	{
								$mynextvol -= 1;
								$myno += 1;
								if ($myfirstvol eq $mynextvol)	{
									if($myno < $frequency)	{
										$mymissing = "v." . $myfirstvol . ":no." . $myno . "-" . $frequency;
									} else {
										$mymissing = "v." . $myfirstvol . ":no." . $myno;
									}
								} else {
									if($myno > $frequency)	{
										$myfirstvol += 1;
										$mymissing = "v." . $myfirstvol . "-v." . $mynextvol . $missingyears;
										if($mynextvol == $myfirstvol)	{
											$mymissing = "v." . $myfirstvol . $missingyears;
										}
									} else {
										$mymissing = "v." . $myfirstvol . ":no." . $myno .  "-v." . $mynextvol;
										if($tocompress[$a] !~ m/-v\.\d+:no\./ && $tocompress[$a] =~ m/-v\./)	{
											$myfirstvol += 1;
											$mymissing = "v." . $myfirstvol . "-v." . $mynextvol . $missingyears;
											if($myfirstvol == $mynextvol)	{
												$mymissing = "v." . $myfirstvol . $missingyears;
											}
										}
									}
								}
							} else {
								$myfirstvol +=1;
								$mynextvol -= 1;
								if ($myfirstvol eq $mynextvol)	{
									$mymissing = "v." . $myfirstvol . $missingyears;
								} 
								elsif ($myfirstvol < $mynextvol)	{
									$mymissing = "v." . $myfirstvol . "-v." . $mynextvol . $missingyears;		
								}
							}
						} 
					} else {
						$mymissing = $missingyears;
					}
				} else {
					if ($mynextvol == "")	{
						if ($mynextno != "")	{
							$mynextno -= 1;
							$myno += 1;
							$myyear -= 1;
							$mynextyear += 1;
							if($mynextno > $myno)	{
								$mymissing = "no." . $myno . "-no." . $mynextno;
								if ($tocompress[$a] =~ m/:no/)	{
									$mymissing = $myyear . ":no." . $myno . "-" . $mynextyear . ":no." . $mynextno;
									if($myyear == $mynextyear)	{	
										$mymissing = $myyear . ":no." . $myno . "-" . $mynextno;
									}
								}
							} elsif ($mynextno == $myno)	{
								$mymissing = "no." . $myno;
								if ($tocompress[$a] =~ m/:no/)	{
									$mymissing = $myyear . ":no." . $myno . "-" . $mynextyear . ":no." . $mynextno;
									if($myyear == $mynextyear)	{
										$mymissing = $myyear . ":no." . $myno;
									}
								}
							} else {
								if($frequency > 1)	{
									if($mynextno == 0)	{
										if ($myyear + 1 == $mynextyear) {
											if ($myno < $frequency) {
												$mymissing = $myyear . ":no." . $myno . "-" . $frequency;
											} else {
												$mymissing = $myyear . ":no." . $myno;
											}
										} else {
											$mynextyear -= 1;
											if ($myno <= $frequency) {
												$mymissing = $myyear . ":no." . $myno . "-" . $mynextyear;
											} else {
												$mymissing = $missingyears;
											}						
										}						
									} else {
										$mymissing = $myyear . ":no." . $myno . "-" . $mynextyear . ":no." . $mynextno;
										if($myno-1 == $frequency)	{
											if($myyear+1 == $mynextyear)	{
												$mymissing = $mynextyear . ":no." . $mynextno;
												if($mymissing !~ m/no\.1/)	{
													$mymissing =~ s/no\./no\.1-/g;
												}								
											} else {
												$myyear += 1;
												$mymissing = $myyear . "-" . $mynextyear . ":no." . $mynextno;
											}
										}
									}
								} else {
									if($tocompress[$b] =~ m/:no/)	{
										$myyear += 1;
										if($mynextno > 0)	{
											$mymissing = $myyear . "-" . $mynextyear . ":no." . $mynextno;
											if($myyear == $mynextyear)	{
												$mymissing = $mynextyear . ":no.1-" . $mynextno;
												if($mynextno == 1)	{
													$mymissing = $mynextyear . ":no.1"
												}
											}
										}
									}
								}
							}
						} else {
							if($tocompress[$b] =~ m/\d/)	{
								if($frequency > 1)	{
									if($myno<$frequency)	{
										if($myyear > $mynextyear)	{
											$myyear -= 1;
											$myno +=1;
											$mymissing =  $myyear . ":no." . $myno . "-" . $frequency;
											if($myno eq $frequency)	{
												$mymissing =  $myyear . ":no." . $myno;
											}
										} else {
											$myyear -= 1;
											$myno +=1;
											$mymissing =  $myyear . ":no." . $myno . "-" . $mynextyear;
										}
									} else {
										$mymissing = $missingyears;
									}
								} else {
									$mymissing = $missingyears;
								}
							} else {
								$mymissing = $missingyears;
							}
						}
					} else {
						$mymissing = $missingyears;
					}
				}
			}
			if($tocompress[$a] !~ m/n\.s\./ && $tocompress[$b] =~ m/n\.s\./)	{
				$mymissing = $missingyears;
			}
			$totalmissing .= ", " . $mymissing;
			$mymissing = "";			
		}
		$totalmissing =~ s/^,//g;
		$totalmissing =~ s/, $//g;
		$totalmissing =~ s/(, )+/, /g;
		$totalmissing =~ s/  / /g;
		return ($totalmissing);
	}
}

1;
