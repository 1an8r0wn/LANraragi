package LANraragi::Utils::Minion;

use strict;
use warnings;
use utf8;

use Mojo::UserAgent;

use LANraragi::Utils::Logging qw(get_logger);
use LANraragi::Utils::Archive qw(extract_thumbnail);
use LANraragi::Utils::Plugins qw(get_downloader_for_url get_plugin get_plugin_parameters);

use LANraragi::Model::Upload;

# Add Tasks to the Minion instance.
sub add_tasks {
    my $minion = shift;

    $minion->add_task(
        thumbnail_task => sub {
            my ( $job,     @args ) = @_;
            my ( $dirname, $id )   = @args;

            my $thumbname = extract_thumbnail( $dirname, $id );
            $job->finish($thumbname);
        }
    );

    $minion->add_task(
        warm_cache => sub {
            my ( $job, @args ) = @_;
            my $logger = get_logger( "Minion", "minion" );

            $logger->info("Warming up search cache...");

            # Cache warm performs a search for the base index (no search)
            LANraragi::Model::Search::do_search( "", "", 0, "title", "asc", 0, 0 );

            # And for every category defined by the user.
            my @categories = LANraragi::Model::Category->get_category_list;
            for my $category (@categories) {
                my $cat_id = %{$category}{"id"};
                $logger->debug("Warming category $cat_id");
                LANraragi::Model::Search::do_search( "", $cat_id, 0, "title", "asc", 0, 0 );
            }

            $logger->info("Done!");
            $job->finish;
        }
    );

    $minion->add_task(
        handle_upload => sub {
            my ( $job, @args ) = @_;
            my ($file) = @args;

            my $logger = get_logger( "Minion", "minion" );
            $logger->info("Processing uploaded file $file...");

            # Since we already have a file, this goes straight to handle_incoming_file.
            my ( $status, $id, $title, $message ) = LANraragi::Model::Upload::handle_incoming_file($file);

            $job->finish(
                {   success => $status,
                    id      => $id,
                    title   => $title,
                    message => $message
                }
            );
        }
    );

    $minion->add_task(
        download_url => sub {
            my ( $job, @args ) = @_;
            my ($url) = @args;

            my $ua     = Mojo::UserAgent->new;
            my $logger = get_logger( "Minion", "minion" );
            $logger->info("Downloading url $url...");

            # Check downloader plugins for one matching the given URL
            my $downloader = get_downloader_for_url($url);

            if ($downloader) {

                $logger->info( "Found downloader" . $downloader->{namespace} );

                # Use the downloader to transform the URL
                my $plugname = $downloader->{namespace};
                my $plugin   = get_plugin($plugname);
                my @settings = get_plugin_parameters($plugname);

                my $plugin_result = LANraragi::Model::Plugins::exec_download_plugin( $plugin, $url, @settings );

                if ( exists $plugin_result->{error} ) {
                    $job->finish(
                        {   success => 0,
                            url     => $url,
                            message => $plugin_result->{error}
                        }
                    );
                }

                $ua  = $plugin_result->{user_agent};
                $url = $plugin_result->{download_url};
                $logger->info("URL transformed by plugin to $url");
            } else {
                $logger->debug("No downloader found, trying direct URL.");
            }

            # Download the URL
            eval {
                my $tempfile = LANraragi::Model::Upload::download_url( $url, $ua );
                $logger->info("URL downloaded to $tempfile");

                # Hand off the result to handle_incoming_file
                my ( $status, $id, $title, $message ) = LANraragi::Model::Upload::handle_incoming_file($tempfile);

                $job->finish(
                    {   success => $status,
                        url     => $url,
                        id      => $id,
                        title   => $title,
                        message => $message
                    }
                );
            };

            if ($@) {

                # Downloading failed...
                $job->finish(
                    {   success => 0,
                        url     => $url,
                        message => $@
                    }
                );
            }
        }
    );

    $minion->add_task(
        run_script => sub {
            my ( $job,    @args )      = @_;
            my ( $plugin, $arguments ) = @args;

            my $logger = get_logger( "Minion", "minion" );

            # TODO?

        }
    );

}

1;
