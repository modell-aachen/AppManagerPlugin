(function($) {
  $('document').ready(function() {
    var p = foswiki.preferences;
    $.get(p.SCRIPTURL + "/rest/" + p.SCRIPTSUFFIX + "/AppManagerPlugin/applist", function(data, textStatus, XMLHttpRequest) {
      var apps = $.parseJSON(data);
      for (var key in apps) {
        var value = apps[key];
        if (value === 'managed') {
          $('#managedAppsContainer').append('<div class="managedAppContainer" id="' + key + '">' + key + '</div>'); 
        } else {
          $('#unmanagedAppsContainer').append('<div class="unmanagedAppContainer" id="' + key + '">' + key + '</div>'); 
        }
      };
    }).done(function() {
      $('#managedAppsContainer, #unmanagedAppsContainer').append('<div class="clear"></div>');

      $('.managedAppContainer').unbind('click').bind('click', function() {
        var $container = $(this);
        $.get(p.SCRIPTURL + "/rest/" + p.SCRIPTSUFFIX + "AppManagerPlugin/appdetail", {name: $(this).attr('id')}, function(data, textStatus, XMLHttpRequest) {
          var appInformation = $.parseJSON(data);
          $('#appConfigDescriptionContent').empty().append(appInformation.description);
          console.log(appInformation)
          var $select = $('<select></select>');
          for (var action in appInformation.actions) {
            if (typeof appInformation.actions[action] === "object") {
              $('<option value="' + action + '">' + action  + '</option>').appendTo($select);
            }
          }
          $('#appConfigActionsContent').empty().append($select);
          $('<a href="#"').appendTo("#appConfigActionsContent").on('click', function() {
            var $this = $(this);
            $.ajax({
              method: 'POST',
              url: p.SCRIPTURL + "/rest/" + p.SCRIPTSUFFIX + "/AppManagerPlugin/appaction",
              data: {
                name: $container.attr('id'),
                action: $select.val()
              }
            }).done(function(res) {
              var a = $.parseJSON(res);
              $("#appConfigActionsOutput").empty().append(a.info.data);
            });
            return false;
          });
        });
      });
    });
  });
})(jQuery);
