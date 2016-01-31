#!/usr/bin/perl

use strict;
use CGI qw/:standard/;
use HTML::Table;
use File::Path qw(make_path remove_tree);
use File::Basename;
use Capture::Tiny qw(tee_stdout); 
use Encode;
use File::Find qw(find);
use Redis;
use Digest::SHA qw(sha256_hex);

#Require config 
require 'config.pl';
require 'functions.pl';

#Generate Archive table
my $table = new HTML::Table(-rows=>0,
                            -cols=>6,
                            -class=>'itg'
                            );

$table->addSectionRow ( 'thead', 0, "",'<a>Title</a>','<a>Artist/Group</a>','<a>Series</a>',"<a>Language</a>","<a>Tags</a>");
$table->setSectionRowHead('thead', -1, -1, 1);

#Add IDs to the table headers to hide them with media queries on small screens.
$table->setSectionCellAttr('thead', 0, 1, 2, 'id="titleheader"');
$table->setSectionCellAttr('thead', 0, 1, 3, 'id="artistheader"');
$table->setSectionCellAttr('thead', 0, 1, 4, 'id="seriesheader"');
$table->setSectionCellAttr('thead', 0, 1, 5, 'id="langheader"');
$table->setSectionCellAttr('thead', 0, 1, 6, 'id="tagsheader"');

#define variables
my $file = "";
my $path = "";
my $suffix = "";
my $name = "";
my $thumbname = "";
my ($event,$artist,$title,$series,$language,$tags,$id) = (" "," "," "," "," "," ");
my $fullfile="";
my $isnew = "none";
my $count;
my @dircontents;
my $dirname = &get_dirname;

#Default redis server location is localhost:6379. 
#Auto-reconnect on, one attempt every 100ms up to 2 seconds. Die after that.
my $redis = Redis->new(server => &get_redisad, 
						reconnect => 100,
						every     => 3000);

remove_tree($dirname.'/temp'); #Remove temp dir.

#print("Opening and reading files in content directory.. (".(time() - $^T)." seconds)\n");

#This should be enough supported file extensions, right? The old lsar method was hacky and took too long.
my @filez = glob("$dirname/*.zip $dirname/*.rar $dirname/*.7z $dirname/*.tar $dirname/*.tar.gz $dirname/*.lzma $dirname/*.xz $dirname/*.cbz $dirname/*.cbr");

foreach $file (@filez) 
	{	
	push(@dircontents, $file);
	}
closedir(DIR);

foreach $file (@dircontents)
{
	#ID of the archive, used for storing data in Redis.
	$id = sha256_hex($file);

	#Let's check out the Redis cache first! It might already have the info we need.
	if ($redis->hexists($id,"title"))
		{
			#bingo, no need for expensive file parsing operations.
			my %hash = $redis->hgetall($id);

			#It's not a new archive, though. But it might have never been clicked on yet, so we'll grab the value for $isnew stored in redis.

			#Hash Slice! I have no idea how this works.
			($name,$event,$artist,$title,$series,$language,$tags,$isnew) = @hash{qw(name event artist title series language tags isnew)};
		}
	else	#can't be helped. Do it the old way, and add the results to redis afterwards.
		{
			#This means it's a new archive, though! We can notify the user about that later on, and specify it in the hash.
			$isnew="block";
			
			($name,$path,$suffix) = fileparse($file, qr/\.[^.]*/);
			
			#parseName function is in config.pl
			($event,$artist,$title,$series,$language,$tags,$id) = &parseName($name.$suffix,$id);
			
			#jam this shit in redis
			#prepare the hash which'll be inserted.
			my %hash = (
				name => encode_utf8($name),
				event => encode_utf8($event),
				artist => encode_utf8($artist),
				title => encode_utf8($title),
				series => encode_utf8($series),
				language => encode_utf8($language),
				tags => encode_utf8($tags),
				file => encode_utf8($file),
				isnew => encode_utf8($isnew),
				);
				
			#for all keys of the hash, add them to the redis hash $id with the matching keys.
			$redis->hset($id, $_, $hash{$_}, sub {}) for keys %hash; 
			$redis->wait_all_responses;
		}
		
	#Parameters have been obtained, let's decode them.
	($_ = decode_utf8($_)) for ($name, $event, $artist, $title, $series, $language, $tags, $file);
	
	my $icons = qq(<div style="font-size:14px"><a href="$dirname/$name$suffix" title="Download this archive."><i class="fa fa-save"></i><a/> 
					<a href="./edit.pl?id=$id" title="Edit this archive's tags and data."><i class="fa fa-pencil"></i><a/></div>);
			#<a href="./tags.pl?id=$id" title="E-Hentai Tag Import (Unfinished)."><i class="fa fa-server"></i><a/>
			
	#When generating the line that'll be added to the table, user-defined options have to be taken into account.
	#Truncated tag display. Works with some hella disgusting CSS shit.
	my $printedtags = $event." ".$tags;
	if (length $printedtags > 50)
	{
		$printedtags = qq(<a class="tags" style="text-overflow:ellipsis;">$printedtags</a><div class="caption" style="position:absolute;">$printedtags</div>); 
	}
	
	#version with hover thumbnails 
	if (&enable_thumbs)
	{
		#ajaxThumbnail makes the thumbnail for that album if it doesn't already exist. 
		#(If it fails for some reason, it won't return an image path, triggering the "no thumbnail" image on the JS side.)
		my $thumbname = $dirname."/thumb/".$id.".jpg";

		my $row = qq(<span style="display: none;">$title</span>
								<a href="./reader.pl?id=$id" );

		if (-e $thumbname)
		{
			$row.=qq(onmouseover="thumbTimeout = setTimeout(showtrail, 200,'$thumbname')" );
		}
		else
		{
			$row.=qq(onmouseover="thumbTimeout = setTimeout(ajaxThumbnail, 200,'$id')" );
		}
									
		$row.=qq(onmouseout="hidetrail(); clearTimeout(thumbTimeout);">
								$title
								</a>
								<img src="img/n.gif" style="float: right; margin-top: -15px; z-index: -1; display: $isnew">); #user is notified here if archive is new (ie if it hasn't been clicked on yet)

		#add row for this archive to table
		$table->addRow($icons.qq(<input type="text" style="display:none;" id="$id" value="$id"/>),$row,$artist,$series,$language,$printedtags);
	}
	else #version without, ezpz
	{
		#add row to table
		$table->addRow($icons,qq(<span style="display: none;">$title</span><a href="./reader.pl?id=$id" title="$title">$title</a>),$artist,$series,$language,$printedtags);
	}
		
	$table->setSectionClass ('tbody', -1, 'list' );
	
}


$table->setColClass(1,'itdc');
$table->setColClass(2,'title itd');
$table->setColClass(3,'artist itd');
$table->setColClass(4,'series itd');
$table->setColClass(5,'language itd');
$table->setColClass(6,'tags itu');
$table->setColWidth(1,30);

	#print("Printing HTML...(".(time() - $^T)." seconds)");
	my $cgi = new CGI;

	# BIG PRINTS		   
	sub printPage {

		my $html = start_html
			(
			-title=>&get_htmltitle,
			-author=>'lanraragi-san',
			-style=>[{'src'=>'./styles/lrr.css'},
					{'src'=>'./bower_components/font-awesome/css/font-awesome.min.css'}],
			-script=>[
						{-type=>'JAVASCRIPT',
							-src=>'./bower_components/jquery/dist/jquery.min.js'},
						{-type=>'JAVASCRIPT',
							-src=>'./bower_components/datatables/media/js/jquery.dataTables.min.js'},
						{-type=>'JAVASCRIPT',
							-src=>'./bower_components/dropit/dropit.js'},
						{-type=>'JAVASCRIPT',
							-src=>'./js/ajax.js'},	
						{-type=>'JAVASCRIPT',
							-src=>'./js/thumb.js'},
						{-type=>'JAVASCRIPT',
							-src=>'./js/css.js'}],	
			-head=>[Link({-rel=>'icon',-type=>'image/png',-href=>'favicon.ico'}),
					meta({-name=>'viewport', -content=>'width=device-width'})],
			-encoding => "UTF-8",
			#on Load, initialize datatables and some other shit
			-onLoad => "var thumbTimeout = null;
									
						\$.fn.dataTableExt.oStdClasses.sStripeOdd = 'gtr0';
						\$.fn.dataTableExt.oStdClasses.sStripeEven = 'gtr1';

						//datatables configuration
						var arcTable= \$('.itg').DataTable( { 
							'lengthChange': false,
							'pageLength': ".&get_pagesize().",
							'order': [[ 1, 'asc' ]],
							'dom': '<\"top\"ip>rt<\"bottom\"p><\"clear\">',
							'language': {
									'info':           'Showing _START_ to _END_ of _TOTAL_ ancient chinese lithographies.',
    								'infoEmpty':      'No archives to show you !',
    							}
						});

					    //Initialize CSS dropdown with dropit
						\$('.menu').dropit({
					       action: 'click', // The open action for the trigger
					        submenuEl: 'div', // The submenu element
					        triggerEl: 'a', // The trigger element
					        triggerParentEl: 'span', // The trigger parent element
					        afterLoad: function(){}, // Triggers when plugin has loaded
					        beforeShow: function(){}, // Triggers before submenu is shown
					        afterShow: function(){}, // Triggers after submenu is shown
					        beforeHide: function(){}, // Triggers before submenu is hidden
					        afterHide: function(){} // Triggers before submenu is hidden
					    });

						//Set the correct CSS from the user's localStorage again, in case the version in <script> tags didn't load.
						//(That happens on mobiles for some reason.)
						set_style_from_storage();

						//add datatable search event to the local searchbox and clear search to the clear filter button
						\$('#srch').keyup(function(){
						      arcTable.search(\$(this).val()).draw() ;
						});

						\$('#clrsrch').click(function(){
							arcTable.search('').draw(); 
							\$('#srch').val('');
							});

						//clear searchbar cache
						\$('#srch').val('');

						"
			);

		$html = $html.'<p id="nb">
			<i class="fa fa-caret-right"></i>
			<a href="./upload.pl">Upload Archive</a>
			<span style="margin-left:5px"></span>
			<i class="fa fa-caret-right"></i>
			<a href="./stats.pl">Statistics</a>
			<span style="margin-left:5px"></span>
			<i class="fa fa-caret-right"></i>
			<a href="./tags.pl">Import Tags</a>
		</p>';
			
		$html = $html."<div class='ido'>
		<div id='toppane'>
		<h1 class='ih'>".&get_motd."</h1> 
		<div class='idi'>";
			
		#Search field (stdinput class in panda css)
		$html = $html."<input type='text' id='srch' class='search stdinput' size='90' placeholder='Search Title, Artist, Series, Language or Tags' /> <input id='clrsrch' class='stdbtn' type='button' value='Clear Filter'/></div>";

		#Dropdown list for changing CSSes on the fly.
		my $CSSsel = &printCssDropdown(1);

		#Random button + CSS dropdown with dropit. These can't be generated in JS, the styles need to be loaded asap.
		$html = $html."<p id='cssbutton' style='display:inline'><input class='stdbtn' type='button' onclick=\"var win=window.open('random.pl','_blank'); win.focus();\" value='Give me a random archive'/>".$CSSsel."</p>";

		$html=$html."<script>
			//Set the correct CSS from the user's localStorage.
			set_style_from_storage();
			</script>";

		$html = $html.($table->getTable); #print our finished table

		$html = $html."</div></div>"; #close errything

		$html = $html.'		<p class="ip">
					<a href="https://github.com/Difegue/LANraragi">
						Sorry, I stuttered.
					</a>
				</p>';
				
		$html = $html.end_html; #close html
		return $html;
	}
	
	$redis->quit();

	#We print the html we generated.
	print $cgi->header(-type    => 'text/html',
                   -charset => 'utf-8');
	print &printPage;
