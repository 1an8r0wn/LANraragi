/*
////// REGULAR INDEX PAGE FUNCTIONS
*/

//Switch view on index and saves the value in the user's localStorage. The DataTables callbacks adapt automatically.
//0 = List view
//1 = Thumbnail view
function switch_index_view() {

  if (localStorage.indexViewMode == 1)
  {
    localStorage.indexViewMode = 0;
    $("#viewbtn").val("Switch to Thumbnail View");
  }
  else
  {
    localStorage.indexViewMode = 1;
    $("#viewbtn").val("Switch to List View");
  }

  //Redraw the table yo
  arcTable.draw();

}

function checkVersion(currentVersion,debugMode) {
	//Check the github API to see if an update was released. If so, flash another friendly notification inviting the user to check it out
	var githubAPI = "https://api.github.com/repos/difegue/lanraragi/releases/latest";
	var latestVersion;

	$.getJSON( githubAPI).done(function( data ) {
			latestVersion = data.tag_name;
			//update nag is disabled if the current version contains the DEV string 
			if (latestVersion != currentVersion && debugMode === 0) {

				$.toast({
				heading: 'A new version of LANraragi ('+ latestVersion +') is available !',
			    text: '<a href="'+data.html_url+'">Hit it !</a> It\'s probably good. 👌',
			    hideAfter: false,
			    position: 'top-left', 
			    icon: 'info'
				});

			}
	});
}
