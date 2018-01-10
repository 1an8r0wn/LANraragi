package LANraragi::Controller::API;
use Mojo::Base 'Mojolicious::Controller';

use CGI qw(:standard);
use Image::Magick;
use Redis; 

use LANraragi::Controller::Config;
use LANraragi::Model::Utils;

sub generate_thumbnail {
	my $self = shift;

	my $id = $self->param('id');
	my $dirname = &get_dirname;

	my $thumbname = "./img/thumb/".$id.".jpg";
		
	unless (-e $thumbname)
	{
		my $redis = &getRedisConnection();
								
		my $file = $redis->hget($id,"file");
		$file = decode_utf8($file);
		
		#TODO - move thumbnails to content folder.
		my $path = "./img/thumb/temp";	
		#delete everything in tmp to prevent file mismatch errors.
		unlink glob $path."/*.*";

		#Get lsar's output, jam it in an array, and use it as @extracted.
		my $vals = `lsar "$file"`; 
		#print $vals;
		my @lsarout = split /\n/, $vals;
		my @extracted; 
					
		#The -i 0 option on unar doesn't always return the first image, so we gotta rely on that lsar thing.
		#Sort on the lsar output to find the first image.					
		foreach $_ (@lsarout) 
			{
			if ($_ =~ /^(.*\/)*.+\.(png|jpg|gif|bmp|jpeg|PNG|JPG|GIF|BMP)$/ ) #is it an image? lsar can give us folder names.
				{push @extracted, $_ }
			}
						
		@extracted = sort { lc($a) cmp lc($b) } @extracted;
					
		#unar sometimes crashes on certain folder names inside archives. To solve that, we replace folder names with the wildcard * through regex.
		my $unarfix = @extracted[0];
		$unarfix =~ s/[^\/]+\//*\//g;
					
		#let's extract now.
		#print("ZIPFILE-----"+$file+"bb--------");	
		`unar -D -o $path "$file" "$unarfix"`;
			
		my $path2 = $path.'/'.@extracted[0];
					
		#While we have the image, grab its SHA-1 hash for potential tag research later. 
		#That way, no need to repeat the costly extraction later.
			
		$redis->hset($id,"thumbhash", encode_utf8(shasum($path2)));
			
		#use ImageMagick to make the thumbnail. width = 200px
		my $img = Image::Magick->new;
        
        $img->Read($path2);
        $img->Thumbnail(geometry => '200x');
        $img->Write($thumbname);
			
		$redis.close();
		#Delete the previously extracted file.
		unlink $path2;
	}

	$self->render(  json => {
					id => $id,
					operation => "thumbnail", 
					thumbnail => $thumbname
				  });

}

#TODO - Fix clientside js to use new json syntax
sub add_archive {
	my $self = shift;

	my $id = $self->param('id');
	my $file = $self->param('file');
 	my $redis = &getRedisConnection();

 	if ($redis->hexists($id,"title"))
 	{ 
		$self->render(  json => {
						operation => "add_archive",
						status => 0, 
						error => "id already exists."
					  });
	}

 	#check if the file is in the content directory first
 	if (index($file, &get_dirname) == 0)
 	{ 
 		#utf8 decode the filename
 		eval { $file = decode_utf8($file) }

 		#reusing function from functions_generic, woop
 		&addArchiveToRedis($id,$file,$redis);

 		$self->render(  json => {
 						operation => "add_archive",
						status => 1
					  });
 	}
 	else
 	{
 		$self->render(  json => {
 						operation => "add_archive",
						status => 0,
						error => "file not in the configured content directory."
					  });
 	}

}

#TODO - Fix clientside js to use new json syntax instead of plaintext
sub fetch_tags {
	my $self = shift;

	my $call = $self->param('function');
	my $id = $self->param('id');
	my $method = $self->param('method');
	my $file = $self->param('file');
	my $urlOverride = $self->param('url');
	my $blacklist = &get_tagblacklist;

	#with or without instasave

}

1;
