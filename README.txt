The scripts in the "Normalizer Modules" folder should be installed in a directory called "Normalizer" that is visible to Perl.

The "project" folder contains two additional scripts, one for extraction and one to run normalization. In addition, before running the scripts an extraction file must be created at .../project/extract/input/input.mrk, with holdings listed in one or more 590 fields.

In general, the Normalizer is to be run with this series of commands:

cat project/extract/input/input.mrk | perl -w project/extract/scripts/marc_extract.pl > project/extract/output/output.txt 
cp project/extract/output/series_info.txt project/normalize/input/series_info.txt 
cp project/extract/output/output.txt project/normalize/input/output.txt 
./project/normalize/scripts/marc_normalization.pl -P project -I output.txt -O normalized_output.txt -pcg
