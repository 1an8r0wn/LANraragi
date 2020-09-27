// Scripting for the Upload page.

var processingArchives = 0;
var completedArchives = 0;
var failedArchives = 0;
var totalUploads = 0;

// Handle updating the upload counters.
function updateUploadCounters() {

    $("#progressCount").html(`🤔 Processing: ${processingArchives} 🙌 Completed: ${completedArchives} 👹 Failed: ${failedArchives}`);

    var icon = (completedArchives == totalUploads) ? "fas fa-check-circle" :
        failedArchives > 0 ? "fas fa-exclamation-circle" :
            "fa fa-spinner fa-spin";

    $("#progressTotal").html(`<i class="${icon}"></i> Total:${completedArchives + failedArchives}/${totalUploads}`);
}

// Handle a completed job from minion. Update the line in upload results with the title, ID, message.
function handleCompletedUpload(jobID, d) {
    $(`#${jobID}-name`).attr("href", `reader?id=${d.result.id}`);
    $(`#${jobID}-name`).html(d.result.title);
    $(`#${jobID}-link`).html("Click here to edit metadata.(" + d.result.message + ")");
    $(`#${jobID}-link`).attr("href", `edit?id=${d.result.id}`);

    if (d.result.success) {
        $(`#${jobID}-icon`).attr("class", "fa fa-check-circle");
        completedArchives++;
    } else {
        $(`#${jobID}-icon`).attr("class", "fa fa-exclamation-circle");
        failedArchives++;
    }

    processingArchives--;
    updateUploadCounters();

    const categoryID = document.getElementById("category").value;
    if (categoryID !== "") {
        console.log(`Adding ${d.result.id} to category ${categoryID}`)
        addArchiveToCategory(d.result.id, categoryID);
    }
}

function handleFailedUpload(jobID, d) {

    $(`#${jobID}-link`).html("Error while processing file.(" + d + ")");
    $(`#${jobID}-icon`).attr("class", "fa fa-exclamation-circle");

    failedArchives++;
    processingArchives--;
    updateUploadCounters();
}

// Send an URL to the Download API and add a checkJobStatus to track its progress.
function downloadUrl() {

    fetch("/api/download_url", {
        method: "POST",
        body: new FormData($("#urlForm")[0])
    })
        .then(response => response.json())
        .then((data) => {
            if (data.success) {
                result = `<tr><td><a href="#" id="${data.job}-name">${data.url}</a></td>
                            <td><i id="${data.job}-icon" class='fa fa-spinner fa-spin' style='margin-left:20px; margin-right: 10px;'></i>
                            <a href="#" id="${data.job}-link">Downloading file... (Job #${data.job})</a>
                            </td>
                        </tr>`;

                $('#files').append(result);

                totalUploads++;
                processingArchives++;
                updateUploadCounters();

                // Check minion job state periodically to update the result 
                checkJobStatus(data.job,
                    (d) => handleCompletedUpload(data.job, d),
                    (error) => handleFailedUpload(data.job, error));
            } else {
                throw new Error(data.message);
            }
        })
        .catch(error => showErrorToast("Error while adding download job", error));

}

// Set up jqueryfileupload.
function initUpload() {

    $('#fileupload').fileupload({
        dataType: 'json',
        done: function (e, data) {

            const categoryID = document.getElementById("category").value;

            if (data.result.success == 0)
                result = `<tr><td>${data.result.name}</td>
                              <td><i class='fa fa-exclamation-circle' style='margin-left:20px; margin-right: 10px; color: red'></i>${data.result.error}</td>
                          </tr>`;
            else
                result = `<tr><td><a href="#" id="${data.result.job}-name">${data.result.name}</a></td>
                              <td><i id="${data.result.job}-icon" class='fa fa-spinner fa-spin' style='margin-left:20px; margin-right: 10px;'></i>
                                <a href="#" id="${data.result.job}-link">Processing file... (Job #${data.result.job})</a>
                              </td>
                          </tr>`;

            $('#progress .bar').css('width', '0%');
            $('#files').append(result);

            totalUploads++;
            processingArchives++;
            updateUploadCounters();

            // Check minion job state periodically to update the result 
            checkJobStatus(data.result.job,
                (d) => handleCompletedUpload(data.result.job, d),
                (error) => handleFailedUpload(data.result.job, error));
        },

        fail: function (e, data) {
            result = `<tr><td>${data.result.name}</td>
                              <td><i class='fa fa-exclamation-circle' style='margin-left:20px; margin-right: 10px; color: red'></i>${data.errorThrown}</td>
                          </tr>`;
            $('#progress .bar').css('width', '0%');
            $('#files').append(result);

            totalUploads++;
            failedArchives++;
            updateUploadCounters();
        },

        progressall: function (e, data) {
            var progress = parseInt(data.loaded / data.total * 100, 10);
            $('#progress .bar').css('width', progress + '%');
        }

    });

}