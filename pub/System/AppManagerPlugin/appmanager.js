(function(appDataObj) {
	jQuery(document).ready(function() {
		appManager.config();
		appManager.loadTemplates();

		var allTemplatesLoaded = setInterval(function() { 
			if (
					appManager.templates.singleAppContainerTmpl != '' &&
					appManager.templates.singleAppActionsTmpl != ''
				) {
				clearInterval(allTemplatesLoaded);
				jQuery.each(appManager.getDataObj(), function(key, value) {
					appManager.createSingleAppContainer(appManager.templates.singleAppContainerTmpl, value);
				});
			}
		}, 30);
	});

	/***** AppManager main object *****/
	var appManager = {
		/*********************************/
		/***** AppManager attributes *****/
		/*********************************/
		_dataObj 					: {},
		topParentElem 				: {},
		templates 					: {
			singleAppContainerTmpl 	: '',
			singleAppActionsTmpl	: ''
		},

		/******************************/
		/***** AppManager methods *****/
		/******************************/

		config: function() {
			this.setDataObj(window.appDataObj);
			this.topParentElem = jQuery('#mainContainer');
		},

		/***** Create a container for a single application, displayed on the system topic *****/
		createSingleAppContainer : function(template, obj) {
			jQuery(this.topParentElem).append(template);
			jQuery('.singleAppContainer:last').find('[replaceVal="appname"]').text(obj.appname);
			jQuery('.singleAppContainer:last').find('[replaceVal="description"]').text(obj.description);

			if (obj.actions.length > 0) {
				jQuery('.singleAppContainer:last').find('.singleAppActionsNoContent').remove();
				jQuery('.singleAppContainer:last').find('[replaceVal="actionsSelect"]').html(appManager.templates.singleAppActionsTmpl);

				jQuery.each(obj.actions, function(key, value) {
					jQuery('.singleAppContainer:last').find('.singleAppActionSelect').append('<option>' + value.name + '</option>');
					jQuery('.singleAppContainer:last').find('.singleAppActionSelect option:last').data("meta", {desc : value.description});
				});
				jQuery('.singleAppContainer:last').find('.singleAppActionSelect').unbind().bind('change', function() {
					var currentDesc = jQuery(this).find('option:selected').data("meta").desc;
					jQuery(this).parent().parent().next().text(currentDesc);
				});
			} else {
				jQuery('.singleAppContainer:last').find('.singleAppActionsContent').remove();
			}
		},

		/***** Loads all necessary templates *****/
		loadTemplates : function() {
			jQuery.get("AppManagerPluginTemplates?contenttype=text/plain&skin=text&section=singleAppContainer", function(data, textStatus, XMLHttpRequest) {
				appManager.templates.singleAppContainerTmpl = data;
			});
			jQuery.get("AppManagerPluginTemplates?contenttype=text/plain&skin=text&section=singleAppActions", function(data, textStatus, XMLHttpRequest) {
				appManager.templates.singleAppActionsTmpl = data;
			});
		},

		/***** Set value for attribute _dataObj *****/
		setDataObj : function(obj) {
			this._dataObj = obj;
		},

		/***** Get value for attribute _dataObj *****/
		getDataObj : function() {
			return this._dataObj;
		}
	};
})();
