use strict;
use warnings;
use Benchmark qw(:all);
use POSIX qw(strftime);
use FileHandle;
use Sys::Hostname;

use application 'polytope';

###############################################################################
###############################################################################
# 
# Computing the rays of the secondary cones
#
# This script computes the rays of the secondary cones associated to a set of
# triangulations. The triangulations are assumed to come in the output format
# of either TOPCOM or mptopcom. The resulting rays are stored in polymake
# format in a Set<Vector>. The rays are computed up to symmetry, in case there
# is a group present.
# 
# Prerequisites:
# - polymake needs to be installed
# - xz for (de)compression
#
# The input consists of two file names:
# 1. *.dat file, the original input of TOPCOM or mptopcom
# 2. *.xz file, the file containing the output of TOPCM or mptopcom, compressed
#    by xz.
#
# The procedure is as follows:
# 1. Read the dat file and parse it into polymake format.
# 2. Loop over the triangulations, for every triangulation t:
# 3.   Compute the secondary cone of t and its rays, for every ray r:
# 4.     Compute the fill orbit of r
# 5.     Store the lex minimal element of this orbit
# 6. Save the collected rays
#
# A sample call would be:
# polymake --script rays_of_sec_cones.pl hypersimplex_2_7.dat hypersimplex_2_7.result.00.xz
# The output is then a file
# hypersimplex_2_7.00.xz.rays_of_sec_cones.dat
#
# Note that for large output that is split into separate files it is possible
# to run this script separately on every output file and then postprocess the
# resulting files.
###############################################################################
###############################################################################

my $codename="rays_of_sec_cones";

die "usage: $codename DAT_FILE XZ_FILE\n" unless scalar(@ARGV)==2;
my ($dat_file, $xz_file) = @ARGV;

# Read original mptopcom input so we are sure that we work with the same (order
# of) vertices.
my $entire = `cat $dat_file`;
my ($points, $group) = $entire =~ m/(\[\D*\[.*\]\D*\])\D*(\[\D*\[.*\]\D*\])/;
$points = new Matrix(eval $points);
$group = new Array<Array<Int>>(eval $group);

my $tdata = $xz_file;

my $dir=".";
my $stub="$xz_file";
my $output="$stub.$codename";
my $log_file="$dir/$output.log";

# mark start
my $host = hostname();
my $now = strftime "%a %b %e %H:%M:%S %Y", localtime();
my $LOG = FileHandle->new("> $log_file");
die "cannot write $log_file\n" unless defined($LOG);
$LOG->autoflush(1);
print $LOG "started $codename $xz_file @ $host on $now\n";
print $LOG "reading $tdata\n";
open my $TDATA,  "xzcat $tdata|" or die "cannot read $tdata";
print $LOG "writing $dir/$output.dat\n";

# the ordering of the vertices fits the vertex labels of the triangulations
my $vertices = $points;

my $ActingGroup = new group::PermutationAction(GENERATORS=>$group);

# Collect rays into the following set. This datatype will automatically
# identify multiple occurences of the same vector.
my $rayset = new Set<Vector<Int>>;
my $id = 0;
my $lin_found = 0;

# global lineality space; compute only once
my $L = undef; 

prefer("libnormaliz");
print $LOG "using libnormaliz\n";

# start the clock
my $t0=Benchmark->new();

foreach my $line (<$TDATA>) {
    ++$id;
    
    chomp $line;
    $line =~ s/^.*(\{\{.*\}\}).*/$1/;
    $line =~ s/\{/\[/g; $line =~ s/\}/\]/g;
    
    my $T = new Array<Set>(eval($line));
    my $P = new fan::SubdivisionOfPoints(POINTS=>$vertices, MAXIMAL_CELLS=>$T);

    # Compute secondary cone
    my $S = undef;
    if (defined($L)) {
      $S = $P->secondary_cone(lift_face_to_zero => 0); # kill lineality space; necessary for libnormaliz
    } else {
      $S = $P->secondary_cone();
      $L = $S->LINEALITY_SPACE;
    }
    my $R = new Matrix($S->RAYS);
    project_to_orthogonal_complement($R, $L);
      
    # Loop over all rays
    foreach my $ray (@$R) {
      my $one_ray = new Vector<Int>(primitive($ray));
      # Get lex minimal representative from orbit of $one_ray
      my $rep = $ActingGroup->lex_minimal($one_ray)->first;
      $rayset += $rep;
    }
    my $nrays = $rayset->size();
    print $LOG "$id($nrays) " if $id % 100 == 0;
}

# stop the clock
my $t1=Benchmark->new();
my $td1=timediff($t1,$t0);

# Store the rays that were computed:
save_data($rayset, "$dir/$output.dat");

# extra time for saving
my $t2=Benchmark->new();
my $td2=timediff($t2,$t1);

print $LOG "\nprocessed lines from $xz_file\n", "elapsed time for computation (plus saving):\n", timestr($td1), "\n", timestr($td2), "\n";
close $LOG or die "cannot close $log_file\n";
