package LANraragi::Utils::Archive;

use strict;
use warnings;
use utf8;

use Time::HiRes qw(gettimeofday);
use File::Basename;
use File::Path qw(remove_tree);
use Encode;
use Redis;
use Image::Scale;
use IPC::Cmd qw[can_run run];

use LANraragi::Model::Config;

#Utilitary functions for handling Archives.
#Relies a lot on unar/lsar.

#generate_thumbnail(original_image, thumbnail_location)
#use Image::Scale to make a thumbnail, width = 200px
sub generate_thumbnail {

    my ( $orig_path, $thumb_path ) = @_;

    my $img = Image::Scale->new($orig_path) || die "Invalid image file";
    $img->resize_gd( { width => 200 } );
    $img->save_jpeg($thumb_path);

}

#extract_archive(path, archive_to_extract)
#Extract the given archive to the given path.
sub extract_archive {

    my ($path, $zipfile) = @_;

    #Extraction using unar without creating extra folders.
    my $unarcmd = "unar -D -o $path \"$zipfile\" ";

    my ( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) =
        run( command => $unarcmd, verbose => 0 );

    #Has the archive been extracted ? 
    #If not, stop here and print an error page.
    unless ( -e $path ) {
        my $errlog = join "<br/>", @$full_buf;
        $errlog = decode_utf8($errlog);
        die $errlog;
    }
}

#extract_thumbnail(dirname, id)
#Finds the first image for the specified archive ID and makes it the thumbnail.
sub extract_thumbnail {

    my ( $dirname, $id ) = @_;
    my $thumbname = $dirname . "/thumb/" . $id . ".jpg";

    mkdir $dirname . "/thumb";
    my $redis = LANraragi::Model::Config::get_redis();

    my $file = $redis->hget( $id, "file" );
    $file = LANraragi::Utils::Database::redis_decode($file);

    my $path = "./public/temp/thumb";

    #Clean thumb temp to prevent file mismatch errors.
    remove_tree( $path, { error => \my $err } );

    #Get lsar's output, jam it in an array, and use it as @extracted.
    my $vals = `lsar "$file"`;
    my @lsarout = split /\n/, $vals;
    my @extracted;

    #The -i 0 option on unar doesn't always return the first image.
    #We use the lsar output to find the first image.
    foreach my $lsarfile (@lsarout) {

        #is it an image? lsar can give us folder names.
        if (
            $lsarfile =~ /^(.*\/)*.+\.(png|jpg|gif|bmp|jpeg|PNG|JPG|GIF|BMP)$/ )
        {
            push @extracted, $lsarfile;
        }
    }

    @extracted = sort { lc($a) cmp lc($b) } @extracted;

    #unar sometimes crashes on certain folder names inside archives.
    #To solve that, we replace folder names with the wildcard * through regex.
    my $unarfix = $extracted[0];
    $unarfix =~ s/[^\/]+\//*\//g;

    #let's extract now.
    my $res = `unar -D -o $path "$file" "$unarfix"`;

    if ($?) {
        return "Error extracting thumbnail: $res";
    }

    #Path to the first image of the archive
    my $arcimg = $path . '/' . $extracted[0];

    #While we have the image, grab its SHA-1 hash for tag research.
    #That way, no need to repeat the costly extraction later.
    my $shasum = LANraragi::Utils::Generic::shasum( $arcimg, 1 );
    $redis->hset( $id, "thumbhash", encode_utf8($shasum) );

    #Thumbnail generation
    generate_thumbnail( $arcimg, $thumbname );

    #Delete the previously extracted file.
    unlink $arcimg;
    return $thumbname;
}

#is_file_in_archive($archive, $file)
#Uses lsar to figure out if $archive contains $file.
#Returns 1 if it does exist, 0 otherwise.
sub is_file_in_archive {

    my ( $archive, $filename ) = @_;

    #Get lsar's output, jam it in an array, and use it as @extracted.
    my $vals = `lsar "$archive"`;
    my @lsarout = split /\n/, $vals;
    my @extracted;

    #Sort on the lsar output to find the file
    foreach my $lsarfile (@lsarout) {
        if ( $lsarfile eq $filename ) {
            return 1;
        }
    }

    #Found nothing
    return 0;
}

#extract_file_from_archive($archive, $file)
#Extract $file from $archive and returns the filesystem path it's extracted to.
sub extract_file_from_archive {

    my ( $archive, $filename ) = @_;
    #Timestamp extractions in microseconds
    my ($seconds, $microseconds) = gettimeofday;
    my $stamp = "$seconds-$microseconds";
    my $path = "./public/temp/plugin/$stamp";

    `unar -D -o $path "$archive" "$filename"`;
    return $path."/".$filename;
}

1;
