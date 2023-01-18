// Support component names relative to this directory:
var componentRequireContext = require.context('./components', true)
import ReactRailsUJS from 'react_ujs'
ReactRailsUJS.useContext(componentRequireContext)

ReactRailsUJS.handleEvent('turbo:load', ReactRailsUJS.handleMount)
ReactRailsUJS.handleEvent('turbo:before-render', ReactRailsUJS.handleUnmount)

ReactRailsUJS.handleEvent('turbo:frame-load', ReactRailsUJS.handleMount)
ReactRailsUJS.handleEvent('turbo:frame-render', ReactRailsUJS.handleUnmount)

// Remove modals triggered by <turbo-frames> when the frame is unloaded.
// Bad stuff happens if you don't do this. Trust me. ~ @cjdenio
document.addEventListener('turbo:frame-render', () => {
  window.$('.jquery-modal [data-behavior~=modal].turbo-frame-modal').remove()
})

import './controllers'

import { Turbo } from '@hotwired/turbo-rails'

Turbo.setProgressBarDelay(0)
Turbo.session.drive = false
