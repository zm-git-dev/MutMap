#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  blast2gff.pl
#
#        USAGE:  ./blast2gff.pl  
#
#  DESCRIPTION:  Script to convert a blast output file to gff.
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Dr. Scott A. Givan (sag), givans@missouri.edu
#      COMPANY:  University of Missouri, USA
#      VERSION:  1.0
#      CREATED:  01/12/16 14:43:02
#     REVISION:  ---
#===============================================================================

use 5.010;      # Require at least Perl version 5.10
use autodie;
use Getopt::Long; # use GetOptions function to for CL args
use warnings;
use strict;
use Bio::FeatureIO;
use Bio::SeqFeature::Annotated;
#use Bio::Seq::SeqFactory;
use Bio::Annotation::SimpleValue;
use Bio::Annotation::OntologyTerm;
use Bio::Annotation::AnnotationFactory;
use Bio::Annotation::StructuredValue;

# this script expects the blast output file to be in the format generated by
# using the -outfmt 7 option
#
# see blast documentation for a description
#

my ($debug,$verbose,$help,$infile,$gffversion);

my $result = GetOptions(
    "debug"     =>  \$debug,
    "verbose"   =>  \$verbose,
    "infile:s"  =>  \$infile,
    "gffversion:f"  =>  \$gffversion,
    "help"      =>  \$help,
);

$gffversion = 3 unless ($gffversion);

if ($help) {
    help();
    exit(0);
}

open(my $infh, "<", $infile);

my ($cnt) = (0);
my @features = ();
while (<$infh>) {
    next if (substr($_,0,1) eq '#'); # fast way to skip comments
    ++$cnt;
    chomp($_);
    my @vals = split /\t/, $_;
    if (scalar(@vals) != 12) {
        say "'$_' has unexpected structure";
        exit(1);
    }

    # expect this structure
    # Fields: query id, subject id, % identity, alignment length, mismatches, gap opens, q. start, q. end, s. start, s. end, evalue, bit score
    #           0           1           2           3               4           5           6       7       8           9       10      11

    my ($queryID,$subjID,$perc_identity,$subj_start,$subj_end,$bitscore) = ($vals[0],$vals[1],$vals[2],$vals[8],$vals[9],$vals[11]);

    $bitscore =~ s/ //g;

    my $feature = Bio::SeqFeature::Annotated->new();
    $feature->seq_id($subjID);
    $feature->name($cnt);
    $feature->primary_tag();
    $feature->type(Bio::Annotation::OntologyTerm->new(-label => 'match', -tagname => 'region'));
    $feature->source(Bio::Annotation::SimpleValue->new(-value => 'blastn'));
    $feature->score($bitscore);
    if ($subj_start < $subj_end) {
        $feature->start($subj_start);
        $feature->end($subj_end);
        $feature->strand(1);
    } else {
        $feature->start($subj_end);
        $feature->end($subj_start);
        $feature->strand(-1);
    }

    my $sv = Bio::Annotation::StructuredValue->new(-value => $cnt);
    $sv->tagname('ID');
    $feature->add_Annotation($sv);
    my $sv2 = Bio::Annotation::StructuredValue->new( -value => $queryID);
    $sv2->tagname('Name');
    $feature->add_Annotation($sv2);


    last if ($debug && $cnt >= 20);

    push(@features,$feature);
}

my $featureout = Bio::FeatureIO->new(
    -format     =>  'gff',
    -version    =>  $gffversion,
    -fh         =>  \*STDOUT,
#    -validate_terms =>  1,
);
for my $feature (@features) {
    $featureout->write_feature($feature);
}

sub help {

say <<HELP;

    "debug"     =>  \$debug,
    "verbose"   =>  \$verbose,
    "infile:s"  =>  \$infile,
    "help"      =>  \$help,

HELP

}


