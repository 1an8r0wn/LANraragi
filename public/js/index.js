/*
* 	REGULAR INDEX PAGE FUNCTIONS
*/

// Toggles a category filter. Sets the internal selectedCategory variable and changes the button's class.
function toggleCategory(button) {
    // Add/remove class to button depending on the state
    categoryId = button.id;
    if (selectedCategory === categoryId) {
        button.classList.remove("toggled");
        selectedCategory = "";
    } else {
        selectedCategory = categoryId;
        button.classList.add("toggled");
    }

    // Trigger search
    performSearch();
}

function toggleFilter(button) {
    // jquerify
    button = $(button);

    // invert input's checked value
    inboxState = !(button.prop("checked"));
    button.prop("checked", inboxState);

    updateToggleClass(button);

    // Redraw the table
    performSearch();
}

function updateToggleClass(button) {
    if (button.prop("checked")) button.addClass("toggled");
    else button.removeClass("toggled");
}

function initSettings(version) {
    // Default to thumbnail mode
    if (localStorage.getItem("indexViewMode") === null) {
        localStorage.indexViewMode = 1;
    }

    // Default to crop landscape
    if (localStorage.getItem("cropthumbs") === null) {
        localStorage.cropthumbs = true;
    }

    // Default custom columns
    if (localStorage.getItem("customColumn1") === null) {
        localStorage.customColumn1 = "artist";
        localStorage.customColumn2 = "series";
    }

    // Tell user about the context menu
    if (localStorage.getItem("sawContextMenuToast") === null) {
        localStorage.sawContextMenuToast = true;

        $.toast({
            heading: `Welcome to LANraragi ${version}!`,
            text: "If you want to perform advanced operations on an archive, remember to just right-click its name. Happy reading!",
            hideAfter: false,
            position: "top-left",
            icon: "info",
        });
    }

    // 0 = List view
    // 1 = Thumbnail view
    // List view is at 0 but became the non-default state later so here's some legacy weirdness
    if (localStorage.indexViewMode == 0) $("#compactmode").prop("checked", true);

    if (localStorage.cropthumbs === "true") $("#cropthumbs").prop("checked", true);

    updateTableHeaders();
}

function isNullOrWhitespace(input) {
    return !input || !input.trim();
}

function saveSettings() {
    localStorage.indexViewMode = $("#compactmode").prop("checked") ? 0 : 1;
    localStorage.cropthumbs = $("#cropthumbs").prop("checked");

    if (!isNullOrWhitespace($("#customcol1").val())) localStorage.customColumn1 = $("#customcol1").val().trim();

    if (!isNullOrWhitespace($("#customcol2").val())) localStorage.customColumn2 = $("#customcol2").val().trim();

    // Absolutely disgusting
    arcTable.settings()[0].aoColumns[1].sName = localStorage.customColumn1;
    arcTable.settings()[0].aoColumns[2].sName = localStorage.customColumn2;

    updateTableHeaders();
    LRR.closeOverlay();

    // Redraw the table yo
    arcTable.draw();
}

function updateTableHeaders() {
    const cc1 = localStorage.customColumn1;
    const cc2 = localStorage.customColumn2;

    $("#customcol1").val(cc1);
    $("#customcol2").val(cc2);
    $("#customheader1").children()[0].innerHTML = cc1.charAt(0).toUpperCase() + cc1.slice(1);
    $("#customheader2").children()[0].innerHTML = cc2.charAt(0).toUpperCase() + cc2.slice(1);
}

function checkVersion(currentVersionConf) {
    // Check the github API to see if an update was released. If so, flash another friendly notification inviting the user to check it out
    const githubAPI = "https://api.github.com/repos/difegue/lanraragi/releases/latest";
    let latestVersion;

    $.getJSON(githubAPI).done((data) => {
        const expr = /(\d+)/g;
        const latestVersionArr = Array.from(data.tag_name.match(expr));
        let latestVersion = "";
        const currentVersionArr = Array.from(currentVersionConf.match(expr));
        let currentVersion = "";

        latestVersionArr.forEach((element, index) => {
            if (index + 1 < latestVersionArr.length) {
                latestVersion = `${latestVersion}${element}`;
            } else {
                latestVersion = `${latestVersion}.${element}`;
            }
        });
        currentVersionArr.forEach((element, index) => {
            if (index + 1 < currentVersionArr.length) {
                currentVersion = `${currentVersion}${element}`;
            } else {
                currentVersion = `${currentVersion}.${element}`;
            }
        });

        if (latestVersion > currentVersion) {
            $.toast({
                heading: `A new version of LANraragi (${data.tag_name}) is available !`,
                text: `<a href="${data.html_url}">Click here to check it out.</a>`,
                hideAfter: false,
                position: "top-left",
                icon: "info",
            });
        }
    });
}

function fetchChangelog(version) {
    if (localStorage.lrrVersion !== version) {
        localStorage.lrrVersion = version;

        fetch("https://api.github.com/repos/difegue/lanraragi/releases/latest", { method: "GET" })
            .then((response) => (response.ok ? response.json() : { error: "Response was not OK" }))
            .then((data) => {
                if (data.error) throw new Error(data.error);

                if (data.state === "failed") {
                    throw new Error(data.result);
                }

                marked(data.body, {
                    gfm: true,
                    breaks: true,
                    sanitize: true,
                }, (err, html) => {
                    document.getElementById("changelog").innerHTML = html;
                    $("#updateOverlay").scrollTop(0);
                });

                $("#overlay-shade").fadeTo(150, 0.6, () => {
                    $("#updateOverlay").css("display", "block");
                });
            })
            .catch((error) => { LRR.showErrorToast("Error getting changelog for new version", error); failureCallback(error); });
    }
}

function loadContextMenuCategories(id) {
    return Server.callAPI(`/api/archives/${id}/categories`, "GET", null, `Error finding categories for ${id}!`,
        (data) => {
            items = {};

            for (let i = 0; i < data.categories.length; i++) {
                cat = data.categories[i];
                items[`delcat-${cat.id}`] = { name: cat.name, icon: "fas fa-stream" };
            }

            if (Object.keys(items).length === 0) {
                items.noop = { name: "This archive isn't in any category.", icon: "far fa-sad-cry" };
            }

            return items;
        });
}

function handleContextMenu(option, id) {
    if (option.startsWith("category-")) {
        var catId = option.replace("category-", "");
        Server.addArchiveToCategory(id, catId);
        return;
    }

    if (option.startsWith("delcat-")) {
        var catId = option.replace("delcat-", "");
        Server.removeArchiveFromCategory(id, catId);
        return;
    }

    switch (option) {
    case "edit":
        LRR.openInNewTab(`./edit?id=${id}`);
        break;
    case "delete":
        if (confirm("Are you sure you want to delete this archive?")) Server.deleteArchive(id, () => { document.location.reload(true); });
        break;
    case "read":
        LRR.openInNewTab(`./reader?id=${id}`);
        break;
    case "download":
        LRR.openInNewTab(`./api/archives/${id}/download`);
        break;
    default:
        break;
    }
}

function loadTagSuggestions() {
    // Query the tag cloud API to get the most used tags.
    Server.callAPI("/api/database/stats?minweight=2", "GET", null, "Couldn't load tag suggestions",
        (data) => {
            new Awesomplete("#srch", {
                list: data,
                data(tag, input) {
                    // Format tag objects from the API into a format awesomplete likes.
                    label = tag.text;
                    if (tag.namespace !== "") label = `${tag.namespace}:${tag.text}`;

                    return { label, value: tag.weight };
                },
                // Sort by weight
                sort(a, b) { return b.value - a.value; },
                filter(text, input) {
                    return Awesomplete.FILTER_CONTAINS(text, input.match(/[^, -]*$/)[0]);
                },
                item(text, input) {
                    return Awesomplete.ITEM(text, input.match(/[^, -]*$/)[0]);
                },
                replace(text) {
                    const before = this.input.value.match(/^.*(,|-)\s*-*|/)[0];
                    this.input.value = `${before + text}, `;
                },
            });
        });
}

function loadCategories() {
    // Query the category API to get the most used tags.
    $.get("/api/categories")
        .done((data) => {
            // Sort by LastUsed + pinned
            // Pinned categories are shown at the beginning
            data.sort((a, b) => parseFloat(b.last_used) - parseFloat(a.last_used));
            data.sort((a, b) => parseFloat(b.pinned) - parseFloat(a.pinned));
            let html = "";

            const iteration = (data.length > 10 ? 10 : data.length);

            for (var i = 0; i < iteration; i++) {
                category = data[i];
                const pinned = category.pinned === "1";

                catName = (pinned ? "📌" : "") + category.name;
                catName = LRR.encodeHTML(catName);

                div = `<div style='display:inline-block'>
						<input class='favtag-btn ${((category.id == selectedCategory) ? "toggled" : "")}' 
							   type='button' id='${category.id}' value='${catName}' 
							   onclick='toggleCategory(this)' title='Click here to display the archives contained in this category.'/>
					   </div>`;

                html += div;
            }

            // If more than 10 categories, the rest goes into a dropdown
            if (data.length > 10) {
                html += `<select id="catdropdown" class="favtag-btn">
							<option selected disabled>...</option>`;

                for (var i = 10; i < data.length; i++) {
                    category = data[i];
                    catName = LRR.encodeHTML(category.name);

                    html += `<option id='${category.id}'>
								${catName}
							 </option>`;
                }
                html += "</select>";
            }

            $("#category-container").html(html);

            // Add a listener on dropdown selection
            $("#catdropdown").on("change", () => toggleCategory($("#catdropdown")[0].selectedOptions[0]));
        }).fail((data) => LRR.showErrorToast("Couldn't load categories", data.error));
}

function migrateProgress() {
    localProgressKeys = Object.keys(localStorage).filter((x) => x.endsWith("-reader")).map((x) => x.slice(0, -7));

    if (localProgressKeys.length > 0) {
        $.toast({
            heading: "Your Reading Progression is now saved on the server!",
            text: "You seem to have some local progression hanging around -- Please wait warmly while we migrate it to the server for you. ☕",
            hideAfter: false,
            position: "top-left",
            icon: "info",
        });

        const promises = [];
        localProgressKeys.forEach((id) => {
            const progress = localStorage.getItem(`${id}-reader`);

            promises.push(fetch(`api/archives/${id}/metadata`, { method: "GET" })
                .then((response) => response.json())
                .then((data) => {
                    // Don't migrate if the server progress is already further
                    if (progress !== null && data !== undefined && data !== null && progress > data.progress) {
                        Server.callAPI(`api/archives/${id}/progress/${progress}?force=1`, "PUT", null, "Error updating reading progress!", null);
                    }

                    // Clear out localStorage'd progress
                    localStorage.removeItem(`${id}-reader`);
                    localStorage.removeItem(`${id}-totalPages`);
                }));
        });

        Promise.all(promises).then(() => $.toast({
            heading: "Reading Progression has been fully migrated! 🎉",
            text: "You'll have to reopen archives in the Reader to see the migrated progression values.",
            hideAfter: false,
            position: "top-left",
            icon: "success",
        }));
    } else {
        console.log("No local reading progression to migrate");
    }
}
