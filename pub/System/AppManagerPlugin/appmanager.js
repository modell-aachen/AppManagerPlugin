(function() {
	jQuery('document').ready(function() {
		jQuery.get("/bin/rest/AppManagerPlugin/applist", function(data, textStatus, XMLHttpRequest) {
			var apps = jQuery.parseJSON(data);

			jQuery.each(apps, function(key, value) {
				if (value === 'managed') {
					jQuery('#managedAppsContainer').append('<div class="managedAppContainer" id="' + key + '">' + key + '</div>'); 
				} else {
					jQuery('#unmanagedAppsContainer').append('<div class="unmanagedAppContainer" id="' + key + '">' + key + '</div>'); 
				}
			});
		}).done(function() {
			jQuery('#managedAppsContainer, #unmanagedAppsContainer').append('<div class="clear"></div>');

			jQuery('.managedAppContainer').unbind('click').bind('click', function() {
				jQuery.get("/bin/rest/AppManagerPlugin/appdetail", {name: jQuery(this).attr('id')}, function(data, textStatus, XMLHttpRequest) {
					var appInformation = jQuery.parseJSON(data);

					jQuery('#appConfigDescriptionContent').empty().append(appInformation.description);
				});
			});
		});
	});
})();
