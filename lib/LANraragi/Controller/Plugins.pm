package LANraragi::Controller::Plugins;
use Mojo::Base 'Mojolicious::Controller';

use Redis;
use Encode;
use Mojo::JSON;
no warnings 'experimental';
use Cwd;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Archive;
use LANraragi::Utils::Database;

use LANraragi::Model::Config;
use LANraragi::Model::Plugins;

# This action will render a template
sub index {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis;

    #Build plugin listing
    my @plugins = LANraragi::Model::Plugins::plugins;

    #Plugin list is an array of hashes
    my @pluginlist = ();

    foreach my $plugin (@plugins) {

        my %pluginfo = $plugin->plugin_info();

        my $namespace = $pluginfo{namespace};
        my $namerds   = "LRR_PLUGIN_" . uc($namespace);

        my $checked = 0;
        my @globalargnames = $pluginfo{global_args};

        if ($redis->hexists($namerds)) {
            $checked     = $redis->hget( $namerds, "enabled" );
            my $argsjson = $redis->hget( $namerds, "customargs" );

            ( $_ = LANraragi::Utils::Database::redis_decode($_) )
              for ( $checked, $argsjson );

            my @globalargvalues = decode_json ($argsjson);
        }
        
        #Build array of pairs with the global arg names and values
        my @globalargs = [];

        for(my $i = 0, $i < scalar @globalargnames, $i++) {
            my %arghash = (
                name  => @globalargnames[$i],
                value => @globalargvalues[$i]
            );
            push @globalargs, \%arghash;
        }

 
        $pluginfo{enabled}   = $checked;
        $pluginfo{custom_args} = \@globalargs;

        push @pluginlist, \%pluginfo;

    }

    $redis->quit();

    $self->render(
        template => "plugins",
        title    => $self->LRR_CONF->get_htmltitle,
        plugins  => \@pluginlist,
        cssdrop  => LANraragi::Utils::Generic::generate_themes
    );

}

sub save_config {

    my $self  = shift;
    my $redis = $self->LRR_CONF->get_redis;

#For every existing plugin, check if we received a matching parameter, and update its settings.
    my @plugins = LANraragi::Model::Plugins::plugins;

    #Plugin list is an array of hashes
    my @pluginlist = ();
    my $success    = 1;
    my $errormess  = "";

    eval {
        foreach my $plugin (@plugins) {

            my %pluginfo  = $plugin->plugin_info();
            my $namespace = $pluginfo{namespace};
            my $namerds   = "LRR_PLUGIN_" . uc($namespace);

            my $enabled = ( scalar $self->req->param($namespace) ? '1' : '0' );
            
            #Get expected number of custom arguments from the plugin itself
            my $argnumbers = scalar $pluginfo{custom_args}
            my @customargs = [];
            #Loop through the namespaced request parameters
            for (my $i = 0, $i < scalar ) {
                push @customargs, ($self->req->param( $namespace . "_CFG_" . $i ) || "");
            }

            my $encodedargs = encode_json(@customargs);

            $redis->hset( $namerds, "enabled", $enabled );
            $redis->hset( $namerds, "customarg", $encodedargs );

        }
    };

    if ($@) {
        $success   = 0;
        $errormess = $@;
    }

    $self->render(
        json => {
            operation => "plugins",
            success   => $success,
            message   => $errormess
        }
    );
}

sub process_upload {
    my $self = shift;

    #Plugin upload is only allowed in Debug Mode.
    if ($self->app->mode ne "development") {
        $self->render(
                json => {
                    operation => "upload_plugin",
                    success   => 0,
                    error     => "Plugin upload is only allowed in Debug Mode."
                }
            );

            return;
    }

    #Receive uploaded file.
    my $file     = $self->req->upload('file');
    my $filename = $file->filename;

    my $logger =
      LANraragi::Utils::Generic::get_logger( "Plugin Upload", "lanraragi" );

    #Check if this is a Perl package ("xx.pm")
    if ( $filename =~ /^.+\.(?:pm)$/ ) {

        my $dir = getcwd() . ("/lib/LANraragi/Plugin/");
        my $output_file = $dir . $filename;

        $logger->info("Uploading new plugin $filename to $output_file ...");

        #Delete module if it already exists
        unlink($output_file);

        $file->move_to($output_file);

        #Load the plugin dynamically.
        my $pluginclass = "LANraragi::Plugin::" . substr( $filename, 0, -3 );

        #Per Module::Pluggable rules, the plugin class matches the filename
        eval {
            #@INC is not refreshed mid-execution, so we use the full filepath
            require $output_file;
            $pluginclass->plugin_info();
        };

        if ($@) {
            $logger->error(
                "Could not instantiate plugin at namespace $pluginclass!");
            $logger->error($@);

            unlink($output_file);

            $self->render(
                json => {
                    operation => "upload_plugin",
                    name      => $file->filename,
                    success   => 0,
                    error     => "Could not load namespace $pluginclass! "
                      . "Your Plugin might not be compiling properly. <br/>"
                      . "Here's an error log: $@"
                }
            );

            return;
        }

        #We can now try to query it for metadata.
        my %pluginfo = $pluginclass->plugin_info();

        $self->render(
            json => {
                operation => "upload_plugin",
                name      => $pluginfo{name},
                success   => 1
            }
        );

    }
    else {

        $self->render(
            json => {
                operation => "upload_plugin",
                name      => $file->filename,
                success   => 0,
                error     => "This file isn't a plugin - "
                  . "Please upload a Perl Module (.pm) file."
            }
        );
    }
}

1;
