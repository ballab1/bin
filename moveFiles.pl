#!/usr/bin/perl -w

use strict;
use warnings;
our $VERSION     = 1.00;

use POSIX qw(strftime);
use IO::Dir qw(DIR_UNLINK);
use XML::LibXML;
use File::stat qw(:FIELDS);
use Cwd qw(abs_path);
use Getopt::Long;


########################################################
# USAGE
#
my $USAGE =<<USAGE;

Usage:
    This script used to clean up WDMyCloud folders.

    where:
    -------------------------------------------------------------------------------
    -help   -> for help
    -p      -> path to examine

    Ex:
        $0 -p <path>

USAGE
#
######################################################

my (%dir, $path, $help, $scannedFiles, $movedFiles, $deletedFiles, $existingFiles);

$scannedFiles = 0;
$movedFiles = 0;
$deletedFiles = 0;
$existingFiles = 0;

GetOptions(
    'path|p=s'       => \$path,
    'help|?'         => \$help,
) or die "Incorrect usage!\n $USAGE";

if( $help || !defined $path )
{
    print $USAGE;
    exit();
}

print "Scanning folder: $path\n";
$path = $path.'/' unless ( $path =~ /.*\/$/ );

tie %dir, 'IO::Dir', $path, DIR_UNLINK;
foreach my $file (keys %dir)  {

    next if ( $file eq '.' || $file eq '..' );
    $scannedFiles++;

    my $st = $dir{$file};
    next if ( ($st->mode & 020000) != 0 );
    next if ( ($st->mode & 040000) != 0 );

    if ( $st->size eq 0 ) {
        delete $dir{$file};
        $deletedFiles++;
        next;
    }

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime( $st->mtime );
    $year += 1900;
    $mon++;
    my $targetDir = $path . sprintf('%04d-%02d/', $year, $mon);

    mkdir($targetDir) if ( not -d $targetDir );

    my $targetFile = $targetDir . $file;
    if ( -e $targetFile ) {
        delete $dir{$file};
        $existingFiles++;
        $deletedFiles++;
        next;
    }
    rename $path . $file, $targetFile;
    $movedFiles++;
}
untie %dir;

print "Number of files scanned: $scannedFiles\n";
print "Files moved:             $movedFiles\n";
print "Files deleted:           $deletedFiles\n";
print "Duplicate files:         $existingFiles\n";
print "Scan complete\n";