use strict;
use warnings;
use Benchmark qw(:all);
use POSIX qw(strftime);
use FileHandle;
use Sys::Hostname;


###############################################################################
###############################################################################
# Process the rays of the secondary fan of a point configuration
#
# This script processes the output of the script rays_of_sec_cones.pl. Since
# rays_of_sec_cones.pl might have run on multiple files, the results need to be
# joined and duplicates need to be eliminated. All rays are equipped with an ID
# for later use and a histogram is produced, more information on that below
#
# Prerequisites are the same as for rays_of_sec_cones.pl
#
# Input:
# 1. *.dat file, the input file for TOPCOM or mptopcom
# 2. folder, the folder contaning the output of rays_of_sec_cones.pl
#     It is assumed that the output is compressed with xz.
#     It is assumed that the output files follow the following naming scheme:
#        name*.dat.xz
#     where the input file of TOPCOM or mptopcom is called name.dat
#
# Procedure:
# 1. Read all output files into a Set<Vector<Int>>, this automatically
#    eliminates duplicates.
# 2. For every ray r:
# 3.   Associate an ID to r
# 4.   Compute the subdivision induced by r
# 5.   Add the ID of r to the entry with index m, where m is the number of
#      maximal cells of the subdivision.
#
# Histogram:
# The histogram is of type Map<Int, Set<Int>>. It maps an Int m to the set of
# IDs of all rays inducing a subdivision with exactly m maximal cells.
#
# Sample usage:
# polymake --script process_rays.pl hypersimplex_2_7.dat splits/
#
# This run then produces two files:
# 1. hypersimplex_2_7_idmap.dat containing a Map<Int, Vector<Int>>, mapping IDs
#    to rays of the secondary cone.
# 2. hypersimplex_2_7_histogram.dat the histogram described above.
###############################################################################
###############################################################################


use application 'polytope';
my $codename="process_all_rays";

# die "usage: $codename\n" unless scalar(@ARGV)==0;
my ($dat_file, $folder) = @ARGV;
my ($name) = $dat_file =~ m/(.*)\.dat/;


my $entire = `cat $dat_file`;
my ($points, $group) = $entire =~ m/(\[\D*\[.*\]\D*\])\D*(\[\D*\[.*\]\D*\])/;
$points = new Matrix(eval $points);
$group = new Array<Array<Int>>(eval $group);

my $output_file="$name.$codename";
my $log_file="$output_file.log";
my $host = hostname();
my $now = strftime "%a %b %e %H:%M:%S %Y", localtime();
my $LOG = FileHandle->new("> $log_file");
die "cannot write $log_file\n" unless defined($LOG);
$LOG->autoflush(1);
print $LOG "started $codename @ $host on $now\n";
print $LOG "writing $output_file\n";
my $OUT = FileHandle->new("> $output_file");
die "cannot write $output_file\n" unless defined($OUT);

print $LOG "check\n";


my $rays=new Set<Vector<Int>>(); 
my @dat=glob("$folder/$name*.dat.xz"); 
foreach my $dat(@dat) {
   print $dat,"\n";
   `cp $dat /tmp/bla.xz`;
   `unxz /tmp/bla.xz`;
   my $these_rays=load("/tmp/bla"); 
   `rm /tmp/bla`;
   print "$dat: ", $these_rays->size(), "\n"; 
   $rays+=$these_rays;
};
save_data($rays, $name."_all_rays.dat");

my $size = $rays->size();
print $LOG "Number of rays to process: $size \n";
my @maxcells = ();

my $two_splits = 0;
my $two_splits_ids = new Set<Vector<Int>>(); 
my $three_splits = 0;
my $three_splits_ids = new Set<Vector<Int>>();


my $raynumber=0;
my $idmap = new Map<Int, Vector<Int>>();
my $histogram = new Map<Int, Set<Int>>();
my $maxcells = 0;
for (my $i=0; $i<$size; ++$i) {
    my $one_ray = $rays->[$i];
    my $P0 = new fan::SubdivisionOfPoints(POINTS=>$points, WEIGHTS=>$one_ray);
    my $N = $P0->N_MAXIMAL_CELLS;
    $idmap->{$i} = $one_ray;
    $histogram->{$N} += $i;
    push(@maxcells, "$N");
    ++$raynumber;
    if ($N == 3) {
        ++$three_splits;
        $three_splits_ids += $one_ray;
    }
    elsif ($N == 2) {
        ++$two_splits;
        $two_splits_ids += $one_ray;
    }
    print $LOG "Processed: $i rays\n" if $i % 100 == 0;
    $maxcells = $N < $maxcells ? $maxcells : $N;
}

save_data($histogram, $name."_histogram.dat");
save_data($idmap, $name."_idmap.dat");

#print $OUT "@maxcells\n";
print $OUT "The 2-splits are: $two_splits_ids\n";
print $OUT "Number of 2-splits: $two_splits\n";
print $OUT "The 3-splits are: $three_splits_ids\n";
print $OUT "Number of 3-splits: $three_splits\n";

print $OUT "Histogram:\n";
for(my $i=2; $i<=$maxcells; $i++){
   print $OUT "$i: ";
   if(defined($histogram->{$i})){
         print $OUT $histogram->{$i};
   } else {
         print $OUT "0";
   }
   print $OUT "\n";
}

close $OUT or die "cannot close $output_file\n";
close $LOG or die "cannot close $log_file\n";

##############################################
