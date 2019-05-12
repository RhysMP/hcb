$(document).on 'turbolinks:load', ->
  if BK.thereIs 'application_form'

    # Form validation
    $('form').submit (e) ->
      if $('[data-behavior~="member_attributes"]').length == 1
        e.preventDefault()
        BK.s('loading_message').html 'You need to add a team member'
        BK.s('add_member').effect 'highlight', color: '#000'
        return
      
      $('[type="submit"]').addClass 'disabled'
      messageList = {
        0: 'Submitting your application',
        500: 'Submitting your application.',
        1000: 'Submitting your application..',
        1500: 'Submitting your application...',
        2000: 'Submitting your application',
        2500: 'Submitting your application.',
        3000: 'Submitting your application..',
        3500: 'Submitting your application...',
        4500: 'Submitting your application.',
        5000: 'Submitting your application.',
        5500: 'Submitting your application..',
        6000: 'Submitting your application...',
        6500: 'So',
        7500: 'So.',
        8500: 'So..',
        9500: 'So...',
        11000: 'Ya like jazz?',
        15000: 'Ok, truth be told I think there’s something wrong with this page or your internet',
        20000: 'Send a screenshot to max@hackclub.com & we’ll get your application submitted',
      }
      for timestamp in Object.keys(messageList)
        do (timestamp) ->
            setTimeout (() -> BK.s('loading_message').html messageList[timestamp]), timestamp
      
        
    # For filling in fields from URL params
    $('[name="application[event_name]"]').val(BK.getQueryParams().name)
    $('[name="application[website]"]').val(BK.getQueryParams().url)
    $('[name="application[about_event]"]').val(BK.getQueryParams().about_event)
    $('[name="application[expected_attendees]"]').val(BK.getQueryParams().expected_attendees)

    # For fields with length requirements
    $(document).on 'keyup', '[data-behavior~=character_limit]', (e) ->
      field = $(e.target)
      indicator = field.siblings('[data-behavior~=character_limit_indicator]')
      length = field.val().length
      if length > 0
        indicator.html "#{length} characters (aim for 250 to 600)"
      else
        indicator.html "(Between 250 and 600 characters)"

    # Method for adding a hide/show for parent info
    parentToggle = (index) ->
      birthdate = new Date($("#application_team_members_#{index}_birthdate").val())
      minorThreshold = new Date().setFullYear(new Date().getFullYear() - 18)
      isMinor = birthdate > minorThreshold
      parentInfo = $("[data-index='#{index}']>.parent-info")
      parentInfo.toggle(isMinor)
      parentInfo.find(':input').prop('required', isMinor)
      parentInfo.find(':input').prop('disabled', !isMinor)

    # Handle change of birthday selector
    $(document).on 'change', '[data-behavior~=birthdate]', (e) ->
      index = $(e.target).parent().parent().data('index') + 1
      parentToggle index

    # Remove team-member on application form
    $(document).on 'click', '[data-behavior~=remove_member]', (e) ->
      $(e.target).closest('[data-behavior~=member_attributes]').slideUp 'fast'
      setTimeout (-> $(e.target).closest('[data-behavior~=member_attributes]').remove()), 1000

    # Add team-member on application form
    $(document).on 'click', '[data-behavior~=add_member]', ->
      newDiv = $('[data-behavior~=member_attributes]:last').clone()
      newID = Number(newDiv.data('index')) + 1
      newDiv.attr 'data-index', newID
      newDiv.fadeIn 'fast'

      incrementAttr = (div, attr) ->
        oldValue = $(div).attr attr
        newValue = oldValue.replace /\d+/, newID
        $(div).attr attr, newValue

      $.each newDiv.find('.field > *'), ->
        if this.tagName is 'INPUT' || this.tagName is 'SELECT'
          incrementAttr this, 'name'
          incrementAttr this, 'id'
          $(this).val ''
          $(this).prop 'required', true
        if this.tagName is 'LABEL'
          incrementAttr this, 'for'

      BK.s('members_list').append newDiv
      parentToggle newID
