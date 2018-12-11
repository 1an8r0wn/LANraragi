package LANraragi;

use local::lib;

use open ':std', ':encoding(UTF-8)';

use Mojo::Base 'Mojolicious';

use Mojo::IOLoop::ProcBackground;

use LANraragi::Utils::Generic;
use LANraragi::Utils::Routing;

use LANraragi::Model::Config;
use LANraragi::Model::Plugins;

# This method will run once at server start
sub startup {
    my $self = shift;

    # Load configuration from hash returned by "lrr.conf"
    my $config = $self->plugin( 'Config', { file => 'lrr.conf' } );
    my $version = $config->{version};

    say "";
    say "";
    say "ｷﾀ━━━━━━(ﾟ∀ﾟ)━━━━━━!!!!!";

    $self->secrets( $config->{secrets} );
    $self->plugin('RenderFile');

    # Set Template::Toolkit as default renderer so we can use the LRR templates
    $self->plugin('TemplateToolkit');
    $self->renderer->default_handler('tt2');

    #Remove upload limit
    $self->max_request_size(0);

    #Helper so controllers can reach the app's Redis DB quickly
    #(they still need to declare use Model::Config)
    $self->helper( LRR_CONF => sub { LANraragi::Model::Config:: } );

    #Second helper to build logger objects quickly
    $self->helper(
        LRR_LOGGER => sub {
            return LANraragi::Utils::Generic::get_logger( "LANraragi",
                "lanraragi" );
        }
    );

    my $devmode = $self->LRR_CONF->enable_devmode;

    if ($devmode) {
        $self->mode('development');
        $self->LRR_LOGGER->info(
            "LANraragi $version (re-)started. (Debug Mode)");

        #Tell the mojo logger to print to stdout as well
        $self->log->on(
            message => sub {
                my ( $time, $level, @lines ) = @_;

                print "[Mojolicious] ";
                print $lines[0];
                print "\n";
            }
        );

    }
    else {
        $self->mode('production');
        $self->LRR_LOGGER->info(
            "LANraragi $version started. (Production Mode)");
    }

    #Plugin listing
    my @plugins = LANraragi::Model::Plugins::plugins;
    foreach my $plugin (@plugins) {

        my %pluginfo = $plugin->plugin_info();
        my $name     = $pluginfo{name};
        $self->LRR_LOGGER->info( "Plugin Detected: " . $name );
    }

    #Check if a Redis server is running on the provided address/port
    $self->LRR_CONF->get_redis;

    #Start Background worker
    if ( -e "./shinobu-pid" ) {

        #Read PID from file
        open( my $pidfile, '<', "shinobu-pid" )
          || die( "cannot open file: " . $! );
        my $pid = <$pidfile>;
        close($pidfile);

        $self->LRR_LOGGER->info(
            "Terminating previous Shinobu Worker if it exists... (PID is $pid)"
        );

#TASKKILL seems superflous on Windows as sub-PIDs are always cleanly killed when the main process dies
#But you can never be safe enough
        if ( $^O eq "MSWin32" ) {
            `TASKKILL /F /T /PID $pid`;
        }
        else {
            `kill -9 $pid`;
        }

    }

    my $proc = $self->stash->{shinobu} = Mojo::IOLoop::ProcBackground->new;

    # When the process terminates, we get this event
    $proc->on(
        dead => sub {
            my ($proc) = @_;
            my $pid = $proc->proc->pid;
            $self->LRR_LOGGER->info(
                "Shinobu Background Worker terminated. (PID was $pid)");

            #Delete pidfile
            unlink("./shinobu-pid");
        }
    );

    $proc->run( [ $^X, "./lib/Shinobu.pm" ] );

    #Create file to store the process' PID
    open( my $pidfile, '>', "shinobu-pid" ) || die( "cannot open file: " . $! );
    my $newpid = $proc->proc->pid;
    print $pidfile $newpid;
    close($pidfile);

    $self->LRR_LOGGER->debug("Shinobu Worker new PID is $newpid");

    LANraragi::Utils::Routing::apply_routes($self);

    $self->LRR_LOGGER->debug("Routing done! Ready to receive requests.");

}

1;
