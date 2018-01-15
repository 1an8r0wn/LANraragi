package LANraragi::Controller::Reader;
use Mojo::Base 'Mojolicious::Controller';

use Encode;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;
use LANraragi::Model::Reader;

# This action will render a template
sub index {
	my $self = shift;

	if ($self->req->param('id')) {
		    # We got a file name, let's get crackin'.
			my $id = $self->req->param('id');

			#Quick Redis check to see if the ID exists:
			my $redis = $self->LRR_CONF->get_redis();

			unless ($redis->hexists($id,"title"))
				{ $self->redirect_to('index'); }

			#Get a computed archive name if the archive exists
			my $artist = $redis->hget($id,"artist");
			my $arcname = $redis->hget($id,"title");

			unless ($artist =~ /^\s*$/)
				{$arcname = $arcname." by ".$artist; }
				
			$arcname = decode_utf8($arcname);
		
			my $force = $self->req->param('force_reload');
			my $thumbreload = $self->req->param('reload_thumbnail');
			my $imgpaths = "";

			#Load a json matching pages to paths
			$imgpaths = LANraragi::Model::Reader::build_reader_JSON($id,$force,$thumbreload);

			my $userlogged = 0;

			if ($self->session('is_logged')) 
				{ $userlogged = 1;}

			$self->render(template => "reader",
	  				      	arcname => $arcname,
				            id => $id,
				            imgpaths => $imgpaths,
				            readorder => $self->LRR_CONF->get_readorder(),
				            cssdrop => LANraragi::Model::Utils::generate_themes(0),
				            userlogged => $self->session('is_logged')
			  	            );
		} 
		else {
		    # No parameters back the fuck off
			$self->redirect_to('index');
		}
}

1;
