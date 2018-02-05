package LANraragi::Controller::Tags;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;

use LANraragi::Model::Utils;
use LANraragi::Model::Config;
use LANraragi::Model::Plugins;

# This action will render a template
sub index {

	my $self = shift;
	my $redis = $self->LRR_CONF->get_redis;

	#Build plugin listing 
	my @plugins = LANraragi::Model::Plugins::plugins;
	my $pluginlist = "";

	foreach my $plugin (@plugins) {

	    my %pluginfo = $plugin->plugin_info();

	    my $namespace = $pluginfo{namespace};
        my $namerds = "LRR_PLUGIN_".uc($namespace);

        my $checked = "";
        if ($redis->hget($namerds,"enabled") == 1) {$checked = "checked";}

		$pluginlist .= "<li><input type='checkbox' name='plugin' id='$namerds' $checked>".
						"<label for='$namerds'> $pluginfo{name} by $pluginfo{author} <br/> $pluginfo{description} </label>".
					"</li>";

	}



	#Build archive list for batch taggins
	#Fill the list with archives by looking up in redis
	my @keys = $redis->keys( '????????????????????????????????????????????????????????????????' ); #64-character long keys only => Archive IDs 
	my $arclist = "";

	#Parse the archive list and add <li> elements accordingly.
	foreach my $id (@keys)
	{
		if ($redis->hexists($id,"title")) #TODO: Check if file still exists on filesystem as well!
			{
				my $title = $redis->hget($id,"title");
				$title = LANraragi::Model::Utils::redis_decode($title);
				
				#If the archive has no tags, pre-check it in the list.
				if ($redis->hget($id,"tags") eq "")
					{ $arclist .= "<li><input type='checkbox' name='archive' id='$id' checked><label for='$id'> $title</label></li>"; }
				else
					{ $arclist .= "<li><input type='checkbox' name='archive' id='$id' ><label for='$id'> $title</label></li>"; }
			}
	}

	$redis->quit();

	$self->render(template => "tags",
		            title => $self->LRR_CONF->get_htmltitle,
		            arclist => $pluginlist,
		            cssdrop => LANraragi::Model::Utils::generate_themes
		            );

}

1;