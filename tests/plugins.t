use Mojo::Base 'Mojolicious';

use Test::More tests => 8;
use Test::Mojo;

use LANraragi::Plugin::EHentai;
use LANraragi::Plugin::nHentai;
use LANraragi::Plugin::Chaika;

#EHentai Tests
my $eH_gID    = "618395";
my $eH_gToken = "0439fa3666";

my ( $test_eH_gID, $test_eH_gToken ) =
  LANraragi::Plugin::EHentai::lookup_by_title( "TOUHOU GUNMANIA", "", "", "" );

is( $test_eH_gID,    $eH_gID,    'eHentai search test 1/2' );
is( $test_eH_gToken, $eH_gToken, 'eHentai search test 2/2' );

my $eH_tags =
"parody:touhou project, character:hong meiling, character:marisa kirisame, character:reimu hakurei, character:sanae kochiya, character:youmu konpaku, group:handful happiness, artist:nanahara fuyuki, artbook, full color";
my $test_eH_tags =
  LANraragi::Plugin::EHentai::get_tags_from_EH( $eH_gID, $eH_gToken );

is( $test_eH_tags, $eH_tags, 'eHentai API Tag retrieval test' );

#NHentai Tests
my $nH_gID = "52249";
my $test_nH_gID =
  LANraragi::Plugin::nHentai::get_gallery_id_from_title("\"Pieces 1\" shirow");

is( $test_nH_gID, $nH_gID, 'nHentai search test' );

my $nH_tags =
"language:japanese, artist:masamune shirow, full color, non-h, artbook, category:manga";
my $test_nH_tags = LANraragi::Plugin::nHentai::get_tags_from_NH($nH_gID);

is( $test_nH_tags, $nH_tags, 'nHentai API Tag retrieval test' );

#Chaika Tests
my $mwee_ID = "27240";
my $mwee_tags = "female:sole female, male:sole male, artist:kemuri haku, full censorship, male:shotacon, female:defloration, female:nakadashi, female:big breasts, language:translated, language:english";

my $test_jsearch_text = LANraragi::Plugin::Chaika::search_for_archive( "Zettai Seikou Keikaku", "artist:kemuri haku" );
is( $test_jsearch_text, $mwee_tags, 'chaika.moe search test' );

my $test_jsearch_id = LANraragi::Plugin::Chaika::tags_from_chaika_id( "archive", $mwee_ID );
is( $test_jsearch_id, $mwee_tags, 'chaika.moe API Tag retrieval test' );

my $mwee_tags_sha1 = "magazine:comic shitsurakuten 2016-04, publisher:fakku, blowjob, creampie, eyebrows, subscription, muscles, swimsuit, tanlines, ahegao, oppai, hentai, artist:ao banana, uncensored, language:english";
my $test_jsearch_sha1 = LANraragi::Plugin::Chaika::tags_from_sha1("276601a0e5dae9427940ed17ac470c9945b47073");
is( $test_jsearch_sha1, $mwee_tags_sha1, 'chaika.moe SHA-1 reverse search test' );

done_testing();
