(function($) {
  var restUrl = function(endPoint) {
    return [
      foswiki.getPreference('SCRIPTURL'),
      '/rest',
      foswiki.getPreference('SCRIPTSUFFIX'),
      '/AppManagerPlugin/',
      endPoint
    ].join('');
  };

  var onManagedAppClicked = function() {
    var id = $(this).attr('id');
    var $actions = $('#appConfigActionsContent').empty();

    $.blockUI();
    $.get(restUrl('appdetail'), {name: id}, function(data, status, xhr) {
      var details = $.parseJSON(data);
      $('#appConfigDescriptionContent').empty().append(details.description);

      var $selectDiv = $('<div class="actionSelectContainer"></div>').appendTo($actions);
      var $submitDiv = $('<div class="actionSubmitContainer"></div>').appendTo($actions);
      $('<div class="clear"></div>').appendTo($actions);

      var $select = $('<select></select>').appendTo($selectDiv);
      $select.data('action-id', id);
      $('<a class="action" href="#">Go</a>').appendTo($submitDiv);

      for (var action in details.actions) {
        if (typeof details.actions[action] === "object") {
          $('<option value="' + action + '">' + action  + '</option>').appendTo($select);
        }
      }
    }).always($.unblockUI);
  };

  var onActionClicked = function() {
    var $select = $(this).closest('#appConfigActionsContent').find('select');

    $.blockUI();
    $.ajax({
      method: 'POST',
      url: restUrl('appaction'),
      data: {
        name: $select.data('action-id'),
        action: $select.val()
      }
    }).done(function(data) {
      var action = $.parseJSON(data);
      // Show appaction results
      if (action.type === "text") {
        $("#appConfigActionsOutput").empty().text(action.data);
      } else if (action.type == "html"){
        $("#appConfigActionsOutput").empty().append(action.data);
      }
    }).always($.unblockUI);

    return false;
  };

  $(document).ready( function() {
    $.blockUI();
    $.get(restUrl('applist'), function(data, status, xhr) {
      var apps = $.parseJSON(data);
      var keys = Object.keys(apps).sort();
      for (var i in keys ) {
        var key = keys[i];
        var type = apps[key];
        var $div = $('<div class="' + type + 'AppContainer"></div>').attr('id', key).text(key);
        $div.insertBefore($('#' + type + 'AppsContainer > .clear'));
      };

      $('#managedAppsContainer').on('click', '.managedAppContainer', onManagedAppClicked);
      $('#appConfigActionsContent').on('click', 'a.action', onActionClicked)
    }).always($.unblockUI);
  });
})(jQuery);
