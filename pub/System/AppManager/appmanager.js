(function(appDataObj) {
	jQuery(document).ready(function() {
		appManager.config();
		appManager.loadTemplates();
	});	

	/***** AppManager Main Object *****/
	var appManager = {

		/*********************************/
		/***** AppManager Attributes *****/
		/*********************************/
		_dataObj 			: {},
		topParentElem 		: {},

		/******************************/
		/***** AppManager Methods *****/
		/******************************/

		config: function() {
			this.setDataObj(window.appDataObj);
			this.topParentElem = jQuery('#mainContainer');
		},

		/***** Create a Container for a single App, displyed on the System Page *****/
		createSingleAppContainer : function(template, obj) {
			console.log(jQuery(template).find('[replaceVal="appname"]'))
			console.log(this.topParentElem);

			jQuery(this.topParentElem).append(template);
			jQuery('.singleAppContainer:last').find('[replaceVal="appname"]').text(obj.appname);
			jQuery('.singleAppContainer:last').find('[replaceVal="description"]').text(obj.description);
		},

		/***** Loads all necessary Templates for the AppManager *****/
		loadTemplates : function() {
			jQuery.get("AppManagerTemplates?contenttype=text/plain&skin=text&section=singleAppContainer", function(data, textStatus, XMLHttpRequest) {
				jQuery.each(appManager.getDataObj(), function(key, value) {
					appManager.createSingleAppContainer(data, value);
				});
			});
		},

		/***** Set Value for Attribute _dataObj *****/
		setDataObj : function(obj) {
			this._dataObj = obj;
		},

		/***** Get Value for Attribute _dataObj *****/
		getDataObj : function() {
			return this._dataObj;
		}
	};
})();