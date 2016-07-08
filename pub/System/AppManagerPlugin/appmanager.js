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

  var output = function(msg, err) {
    var $output = $('#appConfigActionsOutput').empty();
    var callout = [
      '<div class="callout ',
      err ? 'alert' : 'success',
      '">',
      '<p>',
      msg,
      '</p>',
      '</div>'
    ].join('');

    $(callout).appendTo($output);
  };

  var savedMessage = null;
  var onManagedAppClicked = function() {
    var id = $(this).attr('id');

    if (!savedMessage) $.blockUI();

    $.get(restUrl('appdetail'), {name: id}, function(data, status, xhr) {
      var $output = $('#appConfigActionsOutput').empty();
      var $actions = $('#appConfigActionsContent').empty();

      var details = $.parseJSON(data);
      $('#appConfigDescriptionContent').empty().append(details.description).data('appdetails', details);

      var $selectDiv = $('<div class="actionSelectContainer"></div>').appendTo($actions);
      var $extrasDiv = $('<div class="actionExtrasContainer"></div>').appendTo($actions);
      var $submitDiv = $('<div class="actionSubmitContainer"></div>').appendTo($actions);
      $('<div class="clear"></div>').appendTo($actions);

      var $set = $('<fieldset></fieldset>').appendTo($selectDiv);
      $set.data('action-id', id);
      $('<a class="btn-go" href="#">Go</a>').appendTo($submitDiv);

      var actions = details.actions;
      var keys = _.sortBy(_.keys(actions), function(a) {return a;});

      keys.forEach(function(key) {
        if (typeof actions[key] === "object") {
          // actions other than install rely on a proper installation first...
          var disabled = '';
          var disable = key !== 'install' && !actions[key].installed;
          if (disable) {
            disabled = 'disabled="disabled"';
          }

          var radio = [
            '<input type="radio" ',
            disabled,
            ' name="actions" id="radio',
            key,
            '" value="',
            key,
            '"><label for="radio',
            key,
            ' style="vertical-align:middle;"> ',
            disable ? '<strike>' : '',
            key,
            disable ? '</strike>' : '',
            '</label><br>',
            key
          ].join('');

          $(radio).appendTo($set);
        }
      });

      if (savedMessage) {
        output(savedMessage, 0);
        savedMessage = null;
      }
    }).always($.unblockUI);
  };

  var onActionClicked = function() {
    var $output = $('#appConfigActionsOutput').empty();
    var $set = $(this).closest('#appConfigActionsContent').find('fieldset');
    var action = $set.children('input:checked').val();
    if (!action) {
      output('You have to select an action first!', 1);
      return false;
    }

    var type = $('input[name="type"]:checked').val();
    var paramTo = ($('#paramTo').val() || '').trim();
    var paramFrom = ($('#paramFrom').val() || '').trim();
    if (/^$/.test(paramTo)) {
      output('You have to specify a target web!', 1);
      return false;
    }

    var links = [];
    var copies = [];
    if (type === 'linkpartial') {
      if (/^$/.test(paramFrom)) {
        output('You have to specify a source web!', 1);
        return false;
      }

      var $toCopy = $('#topicContainer').find('input[type="radio"][value="copy"]:checked');
      var $toLink = $('#topicContainer').find('input[type="radio"][value="link"]:checked');
      var $selectedTopics = $('#topicContainer').find('input[type="checkbox"]:checked');
      if ($toCopy.length === 0 && $toLink.length === 0) {
        output('You have to select at least one source topic!', 1);
        return false;
      } else {
        $toCopy.each(function() {copies.push($(this).attr('name'));});
        $toLink.each(function() {links.push($(this).attr('name'));});
      }
    }

    $.blockUI();
    $.ajax({
      method: 'POST',
      url: restUrl('appaction'),
      data: {
        name: $set.data('action-id'),
        action: action,
        from: paramFrom || null,
        to: paramTo || null,
        type: type || null,
        linklist: JSON.stringify(links),
        copylist: JSON.stringify(copies),
      }
    }).done(function(data) {
      var action = $.parseJSON(data);
      if (action.result === 'error') {
        output(action.data, 1);
        $.unblockUI();
      } else {
        savedMessage = action.data;
        $('#'+$set.data('action-id')).trigger('click');
      }
    });

    return false;
  };

  var onActionChanged = function() {
    var $self = $(this);
    var $container = $self.closest('.actionSelectContainer').parent();
    var $extras = $container.find('.actionExtrasContainer').empty();
    $('#appConfigActionsOutput').empty();
    $('#topicContainer').remove();

    var action = $self.val();
    if (action === 'linkpartial') {
      var $source = $('<label for="paramFrom"><strong>Source web</strong>: </label><input type="text" id="paramFrom"> <a href="#" id="listtopics">Fetch topics</a><br>');
      $source.insertBefore($('#paramTo').prev());
      $('.actionExtrasContainer').append($('<div id="topicContainer"></div>'));
    } else {
      $('#paramFrom').prev().remove(); // label
      $('#paramFrom').next().next().remove(); // br
      $('#paramFrom').next().remove(); // a
      $('#paramFrom').remove(); // input
    }

    if (action !== 'install') return;
    var details = $('#appConfigDescriptionContent').data('appdetails');
    var opts = details.actions[action];

    if (!opts) {
      var msg = [
        'Invalid configuration for action "',
        action,
        '". Check your "appconfig.json" file!',
      ].join('');

      output(msg, 1);
      $self.prop('checked', false);
      return;
    }

    $extras.append('<hr>');
    var $target = $('<label for="paramTo"><strong>Target web</strong>: </label><input type="text" id="paramTo" value="'+opts.defaultDestination+'">');
    var $set = $('<fieldset></fieldset>');
    if (opts.allowsCopy) {
      $('<input type="radio" name="type" id="radioCopy" value="copy"><label for="radioCopy">Copy</label>').appendTo($set);
      $('<input type="radio" name="type" id="radioMove" value="move" checked="checked"><label for="radioMove">Move</label>').appendTo($set);
    }
    if (opts.allowsLink) {
      $('<input type="radio" name="type" id="radioLink" value="link"><label for="radioLink">Link (entire web)</label>').appendTo($set);
      $('<input type="radio" name="type" id="radioLinkPartial" value="linkpartial"><label for="radioLinkPartial">Link (select topics)</label>').appendTo($set);
    }

    $extras.append($target);
    if (opts.allowsCopy || opts.allowsLink) {
      $set.prepend('<br>').appendTo($extras);
    }
  };

  var onFetchTopics = function() {
    var web = ($('#paramFrom').val() || '').trim();
    if (/^$/.test(web)) return false;

    var url = restUrl('topiclist');
    var $output = $('#appConfigActionsOutput');
    $output.empty();

    $.blockUI();
    $.ajax({
      url: url,
      data: {
        webname: web
      }
    }).done(function(response) {
      var json = $.parseJSON(response);
      if (!(json.topics && json.topics.length > 0)) {
        output('The given source web contains no topics.', 1);
        return;
      }

        var $container = $('#topicContainer').append('<br>');
        var $table = $('<table><thead><tr><th>Copy</th><th>Link</th><th>Ignore</th><th>Topic</th></tr></thead><tbody></tbody></table>');
        var $tbody = $table.find('tbody');
        json.topics.forEach(function(topic) {
          var tr = [
            '<tr><td><input type="radio" name="',
            topic,
            '" value="copy"></td><td><input type="radio" name="',
            topic,
            '" value="link"></td><td><input type="radio" name="',
            topic,
            '" value="ignore" checked="checked"></td><td>',
            topic,
            '</td></tr>'
          ].join('');
          var $tr = $(tr);
          $tr.appendTo($tbody);
        });

        $table.appendTo($container);
    }).fail(function(err) {
      var json = $.parseJSON(err.responseText);
      output(json.data, 1);
    }).always($.unblockUI);

    return false;
  };

  var wikifyValue = function() {
    var $self = $(this);
    var text =$.wikiword.wikify($self.val(), {transliterate: true, allow: 'a-zA-Z'});
    $self.val(text);
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
      $('#appConfigActionsContent').on('click', 'a.btn-go', onActionClicked);
      $('#appConfigActionsContent').on('change', 'fieldset > input[type="radio"]:checked', onActionChanged);
      $('#appConfigActionsContent').on('click', '#listtopics', onFetchTopics);
      $('#mainContainer').on('change', '#paramTo', wikifyValue);
    }).always($.unblockUI);
  });
})(jQuery);
